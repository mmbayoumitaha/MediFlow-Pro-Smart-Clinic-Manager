import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clinic_failure.dart';
import '../domain/entities.dart';
import '../domain/manage_profiles.dart';
import '../domain/profile_policy.dart';

class ProfileActionState {
  final bool isSubmitting;
  final String? error;
  const ProfileActionState({this.isSubmitting = false, this.error});
}

class ProfileViewModel extends StateNotifier<ProfileActionState> {
  final ManageProfiles _manage;
  final ClinicUser? Function() _actor;
  ProfileViewModel(this._manage, this._actor)
    : super(const ProfileActionState());
  Future<bool> _run(Future<void> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    state = const ProfileActionState(isSubmitting: true);
    try {
      await action();
      if (!mounted) return false;
      state = const ProfileActionState();
      return true;
    } catch (error) {
      if (mounted) {
        state = ProfileActionState(
          error: error is ClinicFailure
              ? error.message
              : 'Profile update failed. Try again.',
        );
      }
      return false;
    }
  }

  Future<bool> patient(ClinicUser expected, ContactInput input) =>
      _run(() async {
        await _manage.patient(_actor(), expected, input);
      });
  Future<bool> doctor(Doctor? expected, DoctorInput input) => _run(() async {
    await _manage.doctor(_actor(), expected, input);
  });
  Future<bool> removePatient(ClinicUser expected) =>
      _run(() => _manage.removePatient(_actor(), expected));
  Future<bool> removeDoctor(Doctor expected) =>
      _run(() => _manage.removeDoctor(_actor(), expected));
}
