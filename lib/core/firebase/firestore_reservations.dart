import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/clinic/data/firebase_clinic_mapper.dart';
import '../../features/clinic/data/firestore_schedule.dart';
import '../../features/clinic/domain/app_enums.dart';
import '../../features/clinic/domain/appointment_lifecycle.dart';
import '../../features/clinic/domain/appointment_policy.dart';
import '../../features/clinic/domain/clinic_failure.dart';
import '../../features/clinic/domain/clinic_snapshot.dart';
import 'clinic_clock.dart';

class FirestoreReservations {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final ClinicClock clock;
  const FirestoreReservations(this.db, this.auth, this.clock);

  void guard(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Your clinic session changed.',
      );
    }
  }

  Never reject(String message, [FailureCode code = FailureCode.conflict]) =>
      throw ClinicFailure(code, message);

  Map<String, dynamic> requiredData(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      doc.data() ??
      reject('This clinic record is unavailable.', FailureCode.notFound);

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
    String uid,
  ) async {
    guard(uid);
    if (name == 'availableSlots') return availability(data, uid);
    if (name == 'bookAppointment') return book(data, uid);
    return changeStatus(data, uid);
  }

  Future<Map<String, dynamic>> availability(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final doctorId = input['doctorId'] as String;
    final dateText = input['date'] as String;
    final parsed = DateTime.tryParse(dateText);
    if (parsed == null || clock.dateKey(parsed) != dateText) {
      reject('Select a valid clinic date.', FailureCode.invalidInput);
    }
    final day = tz.TZDateTime(
      clock.location,
      parsed.year,
      parsed.month,
      parsed.day,
    );
    final end = tz.TZDateTime(
      clock.location,
      parsed.year,
      parsed.month,
      parsed.day + 1,
    );
    final reads = await Future.wait([
      db.doc('doctors/$doctorId').get(const GetOptions(source: Source.server)),
      db.doc('users/$uid').get(const GetOptions(source: Source.server)),
      db
          .doc('clinicTimezones/${day.toUtc().year}')
          .get(const GetOptions(source: Source.server)),
    ]);
    guard(uid);
    final profile = requiredData(reads[0]);
    final actor = requiredData(reads[1]);
    if (actor['role'] != 'patient' || actor['isActive'] != true) {
      reject('Book from an active patient account.', FailureCode.unauthorized);
    }
    final timezone = requiredData(reads[2]);
    final reserved = await Future.wait([
      db
          .collection('doctorReservations/$doctorId/slots')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('dateTime', isLessThan: Timestamp.fromDate(end))
          .get(const GetOptions(source: Source.server)),
      db
          .collection('patientReservations/$uid/slots')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('dateTime', isLessThan: Timestamp.fromDate(end))
          .get(const GetOptions(source: Source.server)),
    ]);
    guard(uid);
    final occupied = reserved.expand((q) => q.docs).map((d) => d.id).toSet();
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(day.year, day.month, day.day);
    if (!selected.isAfter(today) ||
        selected.isAfter(today.add(const Duration(days: 14))) ||
        profile['isAvailable'] != true) {
      return {'zone': ClinicClock.zone, 'startMillis': <int>[]};
    }
    final values = <int>{};
    final periods = FirestoreSchedule.fromStorage(profile['availability']);
    for (final raw in periods) {
      final period = Map<String, dynamic>.from(raw as Map);
      if (period['isActive'] != true ||
          period['day'] != DayOfWeek.values[day.weekday - 1].value) {
        continue;
      }
      final start = _minutes(period['startTime'] as String);
      final finish = _minutes(period['endTime'] as String);
      for (
        var minute = ((start + 29) ~/ 30) * 30;
        minute + 30 <= finish;
        minute += 30
      ) {
        final at = tz.TZDateTime(
          clock.location,
          day.year,
          day.month,
          day.day,
          minute ~/ 60,
          minute % 60,
        );
        final after = clock.inClinic(at.add(const Duration(minutes: 30)));
        final fall = (timezone['dstEnd'] as Timestamp).toDate();
        if (at.hour * 60 + at.minute != minute ||
            after.hour * 60 + after.minute != minute + 30 ||
            (!at.isBefore(fall.subtract(const Duration(hours: 1))) &&
                at.isBefore(fall.add(const Duration(hours: 1))))) {
          continue;
        }
        final milliseconds = at.millisecondsSinceEpoch;
        if (!occupied.contains('$milliseconds')) values.add(milliseconds);
      }
    }
    return {'zone': ClinicClock.zone, 'startMillis': values.toList()..sort()};
  }

  int _minutes(String text) {
    if (!RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(text)) {
      reject('The clinic working hours are invalid.', FailureCode.invalidInput);
    }
    final parts = text.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  Future<Map<String, dynamic>> book(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final id = input['requestId'] as String,
        doctorId = input['doctorId'] as String;
    final milliseconds = (input['startMillis'] as num).toInt();
    final at = clock.fromMilliseconds(milliseconds);
    final key = '$milliseconds';
    final visitRef = db.doc('appointments/$id');
    final doctorRef = db.doc('doctors/$doctorId');
    final userRef = db.doc('users/$uid');
    final doctorLock = db.doc('doctorReservations/$doctorId/slots/$key');
    final patientLock = db.doc('patientReservations/$uid/slots/$key');
    final historyRef = db.doc('patientHistory/$uid');
    final guardRef = db.doc('bookingGuards/$doctorId');
    await db.runTransaction((tx) async {
      guard(uid);
      final previous = await tx.get(visitRef);
      if (previous.exists) {
        final old = previous.data()!;
        if (old['patientId'] != uid ||
            old['doctorId'] != doctorId ||
            (old['dateTime'] as Timestamp).millisecondsSinceEpoch !=
                milliseconds ||
            old['fee'] != input['expectedFee'] ||
            old['specialty'] != input['expectedSpecialty'] ||
            (old['reason'] ?? '') != (input['reason'] ?? '')) {
          reject('This booking request belongs to another reservation.');
        }
        guard(uid);
        return;
      }
      final doctor = requiredData(await tx.get(doctorRef));
      final user = requiredData(await tx.get(userRef));
      final occupiedDoctor = await tx.get(doctorLock);
      final occupiedPatient = await tx.get(patientLock);
      final history = await tx.get(historyRef);
      final scheduleGuard = await tx.get(guardRef);
      final doctorUid = doctor['userId'] as String;
      final careRef = db.doc('doctorPatients/$doctorUid/patients/$uid');
      final care = await tx.get(careRef);
      guard(uid);
      if (user['role'] != 'patient' || user['isActive'] != true) {
        reject('Book from your patient account.', FailureCode.unauthorized);
      }
      if (doctor['isAvailable'] != true ||
          doctor['consultationFee'] != input['expectedFee'] ||
          doctor['specialty'] != input['expectedSpecialty']) {
        reject('Doctor details changed. Refresh and choose again.');
      }
      if (occupiedDoctor.exists || occupiedPatient.exists) {
        reject('This time is already reserved. Choose another slot.');
      }
      if (milliseconds % 1800000 != 0) {
        reject('Select a published 30-minute slot.', FailureCode.invalidInput);
      }
      final minute = at.hour * 60 + at.minute;
      final periods = FirestoreSchedule.fromStorage(doctor['availability']);
      final index = periods.indexWhere((raw) {
        final period = raw as Map;
        return period['isActive'] == true &&
            period['day'] == DayOfWeek.values[at.weekday - 1].value &&
            _minutes(period['startTime'] as String) <= minute &&
            _minutes(period['endTime'] as String) >= minute + 30;
      });
      if (index < 0) {
        reject(
          'Choose a slot within clinic working hours.',
          FailureCode.invalidInput,
        );
      }
      tx.set(visitRef, {
        'id': id,
        'patientId': uid,
        'patientName': user['fullName'],
        'doctorId': doctorId,
        'doctorUserId': doctorUid,
        'doctorName': doctor['fullName'],
        'specialty': doctor['specialty'],
        'dateTime': Timestamp.fromMillisecondsSinceEpoch(milliseconds),
        'durationMinutes': 30,
        'status': 'pending',
        'notes': null,
        'reason': input['reason'] ?? '',
        'fee': doctor['consultationFee'],
        'paymentStatus': 'unpaid',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        'startKey': key,
      });
      final lock = {
        'appointmentId': id,
        'dateTime': Timestamp.fromMillisecondsSinceEpoch(milliseconds),
      };
      tx.set(doctorLock, lock);
      tx.set(patientLock, lock);
      tx.set(guardRef, {
        'activeCount': (scheduleGuard.data()?['activeCount'] as int? ?? 0) + 1,
        'lastAppointmentId': id,
      });
      if (!history.exists) tx.set(historyRef, {'firstAppointmentId': id});
      if (!care.exists) {
        tx.set(careRef, {'patientId': uid, 'appointmentId': id});
      }
    });
    guard(uid);
    final result = requiredData(
      await visitRef.get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...result, 'id': id};
  }

  Future<Map<String, dynamic>> changeStatus(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final id = input['appointmentId'] as String;
    final ref = db.doc('appointments/$id');
    await db.runTransaction((tx) async {
      guard(uid);
      final data = requiredData(await tx.get(ref));
      final user = requiredData(await tx.get(db.doc('users/$uid')));
      final doctor = requiredData(
        await tx.get(db.doc('doctors/${data['doctorId']}')),
      );
      final guardRef = db.doc('bookingGuards/${data['doctorId']}');
      final scheduleGuard = await tx.get(guardRef);
      final mapper = FirebaseClinicMapper(clock);
      final actor = mapper.user(uid, user),
          visit = mapper.appointment(id, data);
      final snapshot = ClinicSnapshot(
        patients: actor.role == UserRole.patient ? [actor] : [],
        doctors: [mapper.doctor(data['doctorId'] as String, doctor)],
      );
      final expected = AppointmentStatus.values.firstWhere(
        (v) => v.value == input['expectedStatus'],
      );
      final target = AppointmentStatus.values.firstWhere(
        (v) => v.value == input['targetStatus'],
      );
      AppointmentLifecycle.validate(
        snapshot,
        actor,
        visit,
        expected,
        target,
        clock.now(),
      );
      guard(uid);
      tx.update(ref, {
        'status': target.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      if (!AppointmentPolicy.reservesTime(target)) {
        tx.delete(
          db.doc(
            'doctorReservations/${data['doctorId']}/slots/${data['startKey']}',
          ),
        );
        tx.delete(
          db.doc(
            'patientReservations/${data['patientId']}/slots/${data['startKey']}',
          ),
        );
        tx.update(guardRef, {
          'activeCount':
              (scheduleGuard.data()?['activeCount'] as int? ?? 0) - 1,
          'lastAppointmentId': id,
        });
      }
    });
    guard(uid);
    final result = requiredData(
      await ref.get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...result, 'id': id};
  }
}
