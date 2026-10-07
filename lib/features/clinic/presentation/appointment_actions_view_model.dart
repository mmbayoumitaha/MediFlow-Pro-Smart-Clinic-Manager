import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_enums.dart';
import '../domain/change_appointment_status.dart';
import '../domain/clinic_failure.dart';
import '../domain/entities.dart';

class AppointmentActionState {
  final String? busyId;
  final String? error;
  const AppointmentActionState({this.busyId, this.error});
}

class AppointmentActionsViewModel
    extends StateNotifier<AppointmentActionState> {
  final ChangeAppointmentStatus _change;
  final ClinicUser? Function() _actor;
  AppointmentActionsViewModel(this._change, this._actor)
    : super(const AppointmentActionState());

  Future<bool> change(Appointment appointment, AppointmentStatus target) async {
    if (!mounted || state.busyId != null) return false;
    state = AppointmentActionState(busyId: appointment.id);
    try {
      await _change(
        actor: _actor(),
        appointmentId: appointment.id,
        expected: appointment.status,
        target: target,
      );
      if (!mounted) return false;
      state = const AppointmentActionState();
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = AppointmentActionState(
        error: error is ClinicFailure
            ? error.message
            : 'Could not update the appointment. Please try again.',
      );
      return false;
    }
  }
}
