import 'app_enums.dart';
import 'clinic_failure.dart';
import 'clinic_repository.dart';
import 'entities.dart';

/// Creates the domain appointment; views supply only selections and symptoms.
class BookAppointment {
  final ClinicRepository _repository;
  final DateTime Function() now;
  final String Function() newId;

  BookAppointment(this._repository, {required this.now, required this.newId});

  Future<Appointment> call({
    required ClinicUser? patient,
    required String doctorId,
    required DateTime dateTime,
    String? reason,
  }) async {
    if (patient == null ||
        !patient.isActive ||
        patient.role != UserRole.patient) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Sign in as a patient to book.',
      );
    }
    final snapshot = await _repository.load();
    Doctor? doctor;
    for (final candidate in snapshot.doctors) {
      if (candidate.id == doctorId) doctor = candidate;
    }
    if (doctor == null) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'This doctor no longer exists.',
      );
    }
    if (!doctor.isAvailable) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'This doctor is unavailable.',
      );
    }
    final now = this.now();
    if (!dateTime.isAfter(now)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Choose a future appointment.',
      );
    }
    final appointment = Appointment(
      id: newId(),
      patientId: patient.id,
      patientName: patient.fullName,
      doctorId: doctor.id,
      doctorName: doctor.fullName,
      specialty: doctor.specialty,
      dateTime: dateTime,
      status: AppointmentStatus.pending,
      reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
      fee: doctor.consultationFee,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.bookAppointment(appointment);
    return appointment;
  }
}
