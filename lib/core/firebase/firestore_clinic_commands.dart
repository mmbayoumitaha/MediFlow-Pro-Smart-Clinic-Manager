import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/clinic/domain/clinic_failure.dart';
import 'clinic_commands.dart';
import 'firebase_failure.dart';

/// Migration adapter: patient enrollment now uses rules-protected Firestore.
/// Remaining commands use the previous transport until their rules are tested.
class FirestoreClinicCommands implements ClinicCommands {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ClinicCommands remaining;
  const FirestoreClinicCommands(this.firestore, this.auth, this.remaining);

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
    if (name != 'completePatientRegistration') {
      return remaining.call(name, data, expectedUid: expectedUid);
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
