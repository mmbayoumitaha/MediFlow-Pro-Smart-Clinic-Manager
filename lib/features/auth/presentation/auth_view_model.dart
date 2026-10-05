import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/clinic_failure.dart';
import '../../clinic/domain/entities.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_use_cases.dart';

class AuthState {
  final ClinicUser? currentUser;
  final bool isLoading;
  final String? error;
  bool get isAuthenticated => currentUser?.isActive == true;

  const AuthState({this.currentUser, this.isLoading = false, this.error});
}

class AuthViewModel extends StateNotifier<AuthState> {
  final SignIn _signIn;
  final RegisterUser _register;
  final SignOut _signOut;
  int _operation = 0;

  AuthViewModel(this._signIn, this._register, this._signOut)
    : super(const AuthState());

  Future<void> login(String email, String password, UserRole role) => _perform(
    () => _signIn(email, password, role),
    'Could not sign in. Please try again.',
  );

  Future<void> register(
    String name,
    String email,
    String password,
    String phone,
    UserRole role,
  ) => _perform(
    () => _register(
      RegistrationInput(
        fullName: name,
        email: email,
        password: password,
        phone: phone,
        role: role,
      ),
    ),
    'Could not register. Please try again.',
  );

  Future<void> _perform(
    Future<ClinicUser> Function() action,
    String fallback,
  ) async {
    if (!mounted || state.isLoading) return;
    final operation = ++_operation;
    state = AuthState(currentUser: state.currentUser, isLoading: true);
    try {
      final user = await action();
      if (mounted && operation == _operation) {
        state = AuthState(currentUser: user);
      }
    } catch (error) {
      if (mounted && operation == _operation) {
        state = AuthState(
          error: error is ClinicFailure ? error.message : fallback,
        );
      }
    }
  }

  Future<void> logout() async {
    if (!mounted) return;
    final operation = ++_operation;
    state = const AuthState();
    try {
      await _signOut();
    } catch (_) {
      if (mounted && operation == _operation) {
        state = const AuthState(
          error: 'Could not finish signing out. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _operation++;
    super.dispose();
  }
}
