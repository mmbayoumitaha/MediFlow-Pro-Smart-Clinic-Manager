import '../../clinic/domain/entities.dart';

class AuthSession {
  final ClinicUser? user;
  final bool isRestoring;
  final String? error;
  const AuthSession({this.user, this.isRestoring = false, this.error});
}

/// Optional capability for a backend with persisted authentication and trusted
/// profile events. The synthetic adapter needs no restoration subscription.
abstract interface class AuthSessionSource {
  Stream<AuthSession> watchSession();
}

abstract interface class PasswordRecovery {
  Future<void> resetPassword(String email);
}
