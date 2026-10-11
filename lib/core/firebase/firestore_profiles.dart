import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/clinic/data/firestore_schedule.dart';

import '../../features/clinic/domain/app_enums.dart';
import '../../features/clinic/domain/clinic_failure.dart';
import '../../features/clinic/domain/entities.dart';
import '../../features/clinic/domain/profile_policy.dart';

class FirestoreProfiles {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  const FirestoreProfiles(this.db, this.auth);
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
      reject('The clinic profile is unavailable.', FailureCode.notFound);
  Future<Map<String, dynamic>> actor(
    Transaction tx,
    String uid, {
    bool admin = false,
  }) async {
    final data = requiredData(await tx.get(db.doc('users/$uid')));
    guard(uid);
    if (data['isActive'] != true || (admin && data['role'] != 'admin')) {
      reject(
        'Your account cannot manage this profile.',
        FailureCode.unauthorized,
      );
    }
    return data;
  }

  bool equal(Object? left, Object? right) {
    if (left is List && right is List) {
      return left.length == right.length &&
          List.generate(
            left.length,
            (i) => equal(left[i], right[i]),
          ).every((v) => v);
    }
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) => right.containsKey(key) && equal(left[key], right[key]),
          );
    }
    return left == right;
  }

  void expected(Map<String, dynamic> current, Map<String, dynamic> original) {
    current = {...current};
    if (current.containsKey('availability')) {
      current['availability'] = FirestoreSchedule.fromStorage(
        current['availability'],
      );
    }
    if (!original.entries.every(
      (e) => current.containsKey(e.key) && equal(current[e.key], e.value),
    )) {
      reject('This profile changed. Refresh before saving.');
    }
  }

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> input,
    String uid,
  ) async {
    guard(uid);
    if (name == 'savePatient') return savePatient(input, uid);
    if (name == 'saveDoctor') return saveDoctor(input, uid);
    await remove(input, uid, name == 'removeDoctor');
    return {};
  }

  Future<Map<String, dynamic>> savePatient(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final original = Map<String, dynamic>.from(input['expected'] as Map);
    final contact = Map<String, dynamic>.from(input['contact'] as Map);
    final id = original['id'] as String,
        ref = db.doc('users/${original['id']}');
    final fullName = (contact['fullName'] as String).trim(),
        phone = (contact['phone'] as String).trim();
    final address = (contact['address'] as String?)?.trim();
    ProfilePolicy.contact(fullName, phone);
    if (address != null && address.length > 500) {
      reject('The address is too long.', FailureCode.invalidInput);
    }
    await db.runTransaction((tx) async {
      guard(uid);
      final caller = await actor(tx, uid);
      final current = requiredData(await tx.get(ref));
      expected(current, original);
      guard(uid);
      if (current['role'] != 'patient' ||
          (caller['role'] != 'admin' && id != uid)) {
        reject(
          'Edit only an authorized patient profile.',
          FailureCode.unauthorized,
        );
      }
      if (caller['role'] != 'admin' &&
          contact['isActive'] != current['isActive']) {
        reject(
          'Only the administrator can change account activity.',
          FailureCode.unauthorized,
        );
      }
      tx.update(ref, {
        'fullName': fullName,
        'phone': phone,
        'address': address == '' ? null : address,
        'isActive': contact['isActive'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    });
    guard(uid);
    final data = requiredData(
      await ref.get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...data, 'id': id};
  }

  Future<Map<String, dynamic>> saveDoctor(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final original = input['expected'] == null
        ? null
        : Map<String, dynamic>.from(input['expected'] as Map);
    final profile = Map<String, dynamic>.from(input['profile'] as Map);
    profile['fullName'] = (profile['fullName'] as String).trim();
    profile['phone'] = (profile['phone'] as String).trim();
    profile['email'] = (profile['email'] as String).trim().toLowerCase();
    profile['bio'] = (profile['bio'] as String?)?.trim();
    if (profile['bio'] == '') profile['bio'] = null;
    final periods = (profile['availability'] as List).map((raw) {
      final period = Map<String, dynamic>.from(raw as Map);
      return AvailabilitySlot(
        day: DayOfWeek.values.firstWhere((d) => d.value == period['day']),
        startTime: period['startTime'] as String,
        endTime: period['endTime'] as String,
        isActive: period['isActive'] as bool,
      );
    }).toList();
    ProfilePolicy.doctor(
      DoctorInput(
        fullName: profile['fullName'] as String,
        email: profile['email'] as String,
        phone: profile['phone'] as String,
        bio: profile['bio'] as String?,
        specialty: MedicalSpecialty.values.firstWhere(
          (s) => s.value == profile['specialty'],
        ),
        consultationFee: (profile['consultationFee'] as num).toDouble(),
        experienceYears: profile['experienceYears'] as int,
        availability: periods,
        isAvailable: profile['isAvailable'] as bool,
      ),
    );
    if (periods.length > 14 ||
        ((profile['bio'] as String?)?.length ?? 0) > 1000) {
      reject(
        'Use at most 14 working periods and a short biography.',
        FailureCode.invalidInput,
      );
    }
    profile['availability'] = FirestoreSchedule.toStorage(
      profile['availability'] as List<dynamic>,
    );
    if (profile['isAvailable'] == true &&
        !(profile['availability'] as Map<String, String>).values.any(
          (value) => value.contains('1'),
        )) {
      reject(
        'Enable a working period containing a complete half-hour slot.',
        FailureCode.invalidInput,
      );
    }
    final id = (original?['id'] ?? input['newDoctorId']) as String;
    final userId = (original?['userId'] ?? input['newUserId']) as String;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(userId) ||
        (profile['email'] as String).contains('/')) {
      reject(
        'Enter the existing Auth account UID and its matching email.',
        FailureCode.invalidInput,
      );
    }
    final ref = db.doc('doctors/$id'), userRef = db.doc('users/$userId');
    await db.runTransaction((tx) async {
      guard(uid);
      final caller = await actor(tx, uid, admin: original == null);
      final current = await tx.get(ref), staff = await tx.get(userRef);
      final emailRef = db.doc('accountEmails/${profile['email']}');
      final reservation = await tx.get(emailRef);
      final removed = await tx.get(db.doc('revokedUsers/$userId'));
      final schedule = await tx.get(db.doc('bookingGuards/$id'));
      guard(uid);
      if (original == null) {
        if (current.exists ||
            staff.exists ||
            reservation.exists ||
            removed.exists ||
            schedule.exists) {
          reject('This UID, email or doctor profile is already registered.');
        }
        tx.set(userRef, {
          'id': userId,
          'email': profile['email'],
          'fullName': profile['fullName'],
          'phone': profile['phone'],
          'role': 'doctor',
          'isActive': true,
          'avatarUrl': null,
          'gender': null,
          'dateOfBirth': null,
          'address': null,
          'doctorId': id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        tx.set(ref, {
          'id': id,
          'userId': userId,
          ...profile,
          'avatarUrl': null,
          'rating': 0,
          'totalReviews': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        tx.set(emailRef, {'userId': userId});
      } else {
        final saved = requiredData(current);
        expected(saved, original);
        if (caller['role'] != 'admin' &&
            (caller['role'] != 'doctor' || userId != uid)) {
          reject(
            'Edit only your own doctor profile.',
            FailureCode.unauthorized,
          );
        }
        if (profile['email'] != saved['email']) {
          reject('The sign-in email cannot change.', FailureCode.invalidInput);
        }
        if (!equal(profile['availability'], saved['availability']) &&
            (schedule.data()?['activeCount'] as int? ?? 0) > 0) {
          reject(
            'Finish or cancel reserved visits before changing working periods. Contact and booking availability can still be updated.',
          );
        }
        final changes = {
          ...profile,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        }..remove('email');
        tx.update(ref, changes);
        tx.update(userRef, {
          'fullName': profile['fullName'],
          'phone': profile['phone'],
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      }
    });
    guard(uid);
    final data = requiredData(
      await ref.get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...data, 'id': id};
  }

  Future<void> remove(
    Map<String, dynamic> input,
    String uid,
    bool doctor,
  ) async {
    final original = Map<String, dynamic>.from(input['expected'] as Map);
    final id = original['id'] as String;
    final ref = db.doc('${doctor ? 'doctors' : 'users'}/$id');
    await db.runTransaction((tx) async {
      guard(uid);
      await actor(tx, uid, admin: true);
      final current = requiredData(await tx.get(ref));
      expected(current, original);
      final userId = doctor ? current['userId'] as String : id;
      final userRef = db.doc('users/$userId');
      final staff = doctor ? requiredData(await tx.get(userRef)) : current;
      final history = await tx.get(
        db.doc(doctor ? 'bookingGuards/$id' : 'patientHistory/$id'),
      );
      final revokedRef = db.doc('revokedUsers/$userId');
      final removed = await tx.get(revokedRef);
      guard(uid);
      if (history.exists ||
          removed.exists ||
          staff['role'] != (doctor ? 'doctor' : 'patient')) {
        reject('Historical or removed profiles cannot be deleted.');
      }
      tx.delete(ref);
      if (doctor) tx.delete(userRef);
      tx.set(revokedRef, {
        'userId': userId,
        'role': doctor ? 'doctor' : 'patient',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    guard(uid);
  }
}
