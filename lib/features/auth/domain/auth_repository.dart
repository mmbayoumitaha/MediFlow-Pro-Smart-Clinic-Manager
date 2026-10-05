import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/entities.dart';

class RegistrationInput {
  final String fullName;
  final String email;
  final String password;
  final String phone;
  final UserRole role;

  const RegistrationInput({
    required this.fullName,
    required this.email,
    required this.password,
    required this.phone,
    required this.role,
  });
}

abstract interface class AuthRepository {
  /// The role argument selects a synthetic account in demo adapters only.
  /// Backend adapters must obtain roles from trusted records, never this input.
  Future<ClinicUser> login(String email, String password, UserRole demoRole);
  Future<ClinicUser> register(RegistrationInput input);
  Future<void> logout();
}
