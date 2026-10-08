import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/clinic/domain/clinic_failure.dart';

ClinicFailure firebaseFailure(Object error) {
  if (error is ClinicFailure) return error;
  if (error is FirebaseException) {
    final code = switch (error.code) {
      'permission-denied' ||
      'unauthenticated' ||
      'invalid-credential' ||
      'wrong-password' ||
      'user-disabled' ||
      'user-not-found' => FailureCode.unauthorized,
      'already-exists' ||
      'email-already-in-use' ||
      'aborted' => FailureCode.conflict,
      'invalid-argument' ||
      'invalid-email' ||
      'weak-password' ||
      'failed-precondition' => FailureCode.invalidInput,
      'not-found' => FailureCode.notFound,
      _ => FailureCode.unavailable,
    };
    if (error is FirebaseFunctionsException &&
        code != FailureCode.unavailable &&
        error.message?.isNotEmpty == true) {
      return ClinicFailure(code, error.message!);
    }
    final message = switch (code) {
      FailureCode.unauthorized =>
        'Sign-in or clinic access failed. Check your account and try again.',
      FailureCode.conflict =>
        'This account or record changed. Refresh and try again.',
      FailureCode.invalidInput =>
        'Check the information you entered and try again.',
      FailureCode.notFound => 'The requested clinic record is unavailable.',
      FailureCode.unavailable => 'The clinic service is unavailable. Check your connection and try again.',
    };
    return ClinicFailure(code, message);
  }
  return const ClinicFailure(
    FailureCode.unavailable,
    'The clinic service could not complete this request.',
  );
}
