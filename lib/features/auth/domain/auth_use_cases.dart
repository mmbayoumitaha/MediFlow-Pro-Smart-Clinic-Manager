import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/clinic_failure.dart';
import '../../clinic/domain/entities.dart';
import 'auth_repository.dart';
import 'auth_session.dart';

String _email(String input) {
  final email = input.trim().toLowerCase();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    throw const ClinicFailure(FailureCode.invalidInput, 'Enter a valid email.');
  }
  return email;
}

void _password(String input) {
  if (input.length < 6) {
    throw const ClinicFailure(
      FailureCode.invalidInput,
      'Password must have at least 6 characters.',
    );
  }
}

class SignIn {
  final AuthRepository _repository;
  const SignIn(this._repository);

  Future<ClinicUser> call(String email, String password, UserRole role) async {
    final normalized = _email(email);
    _password(password);
    final user = await _repository.login(normalized, password, role);
    if (!user.isActive) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'This account is inactive.',
      );
    }
    return user;
  }
}

class RegisterUser {
  final AuthRepository _repository;
  const RegisterUser(this._repository);

  Future<ClinicUser> call(RegistrationInput input) async {
    final name = input.fullName.trim();
    final phone = input.phone.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final email = _email(input.email);
    _password(input.password);
    if (name.length < 3) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Enter your full name.',
      );
    }
    if (digits.length < 8 ||
        digits.length > 15 ||
        !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Enter a valid phone number.',
      );
    }
    if (input.role == UserRole.admin) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Administrator accounts cannot self-register.',
      );
    }
    return _repository.register(
      RegistrationInput(
        fullName: name,
        email: email,
        password: input.password,
        phone: phone,
        role: input.role,
      ),
    );
  }
}

class SignOut {
  final AuthRepository _repository;
  const SignOut(this._repository);
  Future<void> call() => _repository.logout();
}

class RequestPasswordReset {
  final AuthRepository repository;
  const RequestPasswordReset(this.repository);
  Future<void> call(String email) {
    final normalized = _email(email);
    final target = repository;
    if (target is! PasswordRecovery) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'Password recovery is available only for Firebase accounts.',
      );
    }
    return (target as PasswordRecovery).resetPassword(normalized);
  }
}
