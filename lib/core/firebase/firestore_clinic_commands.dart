import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/clinic/domain/clinic_failure.dart';
import 'clinic_commands.dart';
import 'firebase_failure.dart';
import 'clinic_clock.dart';
import 'firestore_reservations.dart';
import 'clinic_calendar.dart';
import 'firestore_billing.dart';
import 'firestore_profiles.dart';

/// Clinic writes use SDK transactions enforced by Firestore Security Rules.
class FirestoreClinicCommands implements ClinicCommands {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ClinicClock? clock;
  const FirestoreClinicCommands(this.firestore, this.auth, {this.clock});

  void _guard(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Your clinic session changed. Sign in again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  }) async {
    _guard(expectedUid);
    if ([
      'savePatient',
      'saveDoctor',
      'removePatient',
      'removeDoctor',
    ].contains(name)) {
      try {
        return await FirestoreProfiles(
          firestore,
          auth,
        ).call(name, data, expectedUid);
      } catch (error) {
        _guard(expectedUid);
        throw firebaseFailure(error);
      }
    }
    if (['issueAppointmentInvoice', 'recordInvoicePayment'].contains(name)) {
      try {
        return await FirestoreBilling(
          firestore,
          auth,
          clock ?? ClinicClock(),
        ).call(name, data, expectedUid);
      } catch (error) {
        _guard(expectedUid);
        throw firebaseFailure(error);
      }
    }
    if (name == 'prepareClinic') {
      final clinicClock = clock ?? ClinicClock();
      final calendar = ClinicCalendar(clinicClock);
      for (final year in calendar.requiredYears(clinicClock.now())) {
        final values = calendar
            .transitions(year)
            .map((key, value) => MapEntry(key, Timestamp.fromDate(value)));
        final ref = firestore.doc('clinicTimezones/$year');
        await firestore.runTransaction((tx) async {
          _guard(expectedUid);
          final actor = await tx.get(firestore.doc('users/$expectedUid'));
          final existing = await tx.get(ref);
          _guard(expectedUid);
          if (actor.data()?['role'] != 'admin' ||
              actor.data()?['isActive'] != true) {
            throw const ClinicFailure(
              FailureCode.unauthorized,
              'Only the clinic administrator can prepare its calendar.',
            );
          }
          if (existing.exists) {
            for (final key in values.keys) {
              if (existing.data()![key] != values[key]) {
                throw const ClinicFailure(
                  FailureCode.unavailable,
                  'The clinic timezone configuration needs an operator update.',
                );
              }
            }
          } else {
            tx.set(ref, values);
          }
        });
        _guard(expectedUid);
      }
      return {};
    }
    if ([
      'availableSlots',
      'bookAppointment',
      'changeAppointmentStatus',
    ].contains(name)) {
      try {
        return await FirestoreReservations(
          firestore,
          auth,
          clock ?? ClinicClock(),
        ).call(name, data, expectedUid);
      } catch (error) {
        _guard(expectedUid);
        throw firebaseFailure(error);
      }
    }
    if (name != 'completePatientRegistration') {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Unknown clinic operation.',
      );
    }
    try {
      final email = auth.currentUser!.email?.trim().toLowerCase();
      if (email == null || email.contains('/')) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'Use a valid email address for clinic enrollment.',
        );
      }
      final user = firestore.doc('users/$expectedUid');
      final emailRef = firestore.doc('accountEmails/$email');
      final revoked = firestore.doc('revokedUsers/$expectedUid');
      await firestore.runTransaction((transaction) async {
        _guard(expectedUid);
        final existing = await transaction.get(user);
        final reservation = await transaction.get(emailRef);
        final removed = await transaction.get(revoked);
        _guard(expectedUid);
        if (removed.exists ||
            (reservation.exists &&
                reservation.data()!['userId'] != expectedUid)) {
          throw const ClinicFailure(
            FailureCode.unauthorized,
            'This clinic identity cannot be enrolled.',
          );
        }
        if (existing.exists) {
          if (existing.data()!['role'] != 'patient' ||
              existing.data()!['isActive'] != true) {
            throw const ClinicFailure(
              FailureCode.unauthorized,
              'This clinic identity cannot be enrolled as a patient.',
            );
          }
          if (!reservation.exists) {
            transaction.set(emailRef, {'userId': expectedUid});
          }
          return;
        }
        transaction.set(emailRef, {'userId': expectedUid});
        transaction.set(user, {
          'id': expectedUid,
          'email': email,
          'fullName': (data['fullName'] as String).trim(),
          'phone': (data['phone'] as String).trim(),
          'role': 'patient',
          'avatarUrl': null,
          'gender': null,
          'dateOfBirth': null,
          'address': null,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _guard(expectedUid);
      return {};
    } catch (error) {
      _guard(expectedUid);
      throw firebaseFailure(error);
    }
  }
}
