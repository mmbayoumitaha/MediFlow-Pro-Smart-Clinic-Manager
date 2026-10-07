import 'app_enums.dart';
import 'clinic_failure.dart';
import 'clinic_repository.dart';
import 'entities.dart';

class ChangeAppointmentStatus {
  final ClinicRepository _repository;
  const ChangeAppointmentStatus(this._repository);

  Future<Appointment> call({
    required ClinicUser? actor,
    required String appointmentId,
    required AppointmentStatus expected,
    required AppointmentStatus target,
  }) async {
    if (actor == null || !actor.isActive) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Sign in to change an appointment.',
      );
    }
    return _repository.changeAppointmentStatus(
      actor: actor,
      appointmentId: appointmentId,
      expected: expected,
      target: target,
    );
  }
}
