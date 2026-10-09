import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clinic/domain/clinic_failure.dart';
import '../domain/auth_use_cases.dart';

class PasswordRecoveryState {
  final bool isSubmitting, requested;
  final String? error;
  const PasswordRecoveryState({
    this.isSubmitting = false,
    this.requested = false,
    this.error,
  });
}

class PasswordRecoveryViewModel extends StateNotifier<PasswordRecoveryState> {
  final RequestPasswordReset request;
  PasswordRecoveryViewModel(this.request)
    : super(const PasswordRecoveryState());
  Future<void> send(String email) async {
    if (!mounted || state.isSubmitting) return;
    state = const PasswordRecoveryState(isSubmitting: true);
    try {
      await request(email);
      if (mounted) state = const PasswordRecoveryState(requested: true);
    } catch (error) {
      if (mounted) {
        state = PasswordRecoveryState(
          error: error is ClinicFailure
              ? error.message
              : 'Password recovery is unavailable. Try again.',
        );
      }
    }
  }
}
