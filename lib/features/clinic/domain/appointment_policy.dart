import 'app_enums.dart';
import 'clinic_failure.dart';
import 'clinic_snapshot.dart';
import 'entities.dart';

/// Clinic wall-clock slots: 30 minutes, aligned to each active working period.
abstract final class AppointmentPolicy {
  static const durationMinutes = 30;

  static bool reservesTime(AppointmentStatus status) =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.confirmed ||
      status == AppointmentStatus.inProgress;

  static bool overlaps(DateTime a, int aMinutes, DateTime b, int bMinutes) =>
      a.isBefore(b.add(Duration(minutes: bMinutes))) &&
      b.isBefore(a.add(Duration(minutes: aMinutes)));

  static int? _minutes(String text) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return null;
    final parts = text.split(':').map(int.parse).toList();
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 + parts[1];
  }

  static List<DateTime> workingSlots(Doctor doctor, DateTime date) {
    if (!doctor.isAvailable || date.isUtc) return const [];
    final slots = <DateTime>{};
    for (final period in doctor.availability) {
      if (!period.isActive || period.day.index + 1 != date.weekday) continue;
      final start = _minutes(period.startTime);
      final end = _minutes(period.endTime);
      // Malformed/reversed/overnight intervals are unavailable, never invented.
      if (start == null || end == null || end <= start) continue;
      for (
        var minute = start;
        minute + durationMinutes <= end;
        minute += durationMinutes
      ) {
        slots.add(
          DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60),
        );
      }
    }
    return List.unmodifiable(slots.toList()..sort());
  }

  static bool hasConflict(
    Iterable<Appointment> appointments, {
    required String doctorId,
    required String patientId,
    required DateTime at,
  }) => appointments.any(
    (a) =>
        reservesTime(a.status) &&
        (a.doctorId == doctorId || a.patientId == patientId) &&
        overlaps(at, durationMinutes, a.dateTime, a.durationMinutes),
  );

  static List<DateTime> availableSlots(
    ClinicSnapshot snapshot, {
    required Doctor doctor,
    required String patientId,
    required DateTime date,
    required DateTime now,
  }) => List.unmodifiable(
    workingSlots(doctor, date).where(
      (at) =>
          at.isAfter(now) &&
          !hasConflict(
            snapshot.appointments,
            doctorId: doctor.id,
            patientId: patientId,
            at: at,
          ),
    ),
  );

  static void validate(
    ClinicSnapshot snapshot,
    Appointment appointment,
    DateTime now,
  ) {
    final patients = snapshot.patients.where(
      (p) => p.id == appointment.patientId,
    );
    final doctors = snapshot.doctors.where((d) => d.id == appointment.doctorId);
    if (patients.length != 1 || doctors.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Patient or doctor no longer exists.',
      );
    }
    final patient = patients.single;
    final doctor = doctors.single;
    if (!patient.isActive || patient.role != UserRole.patient) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'This patient account cannot book.',
      );
    }
    if (!doctor.isAvailable) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'This doctor is unavailable.',
      );
    }
    if (appointment.status != AppointmentStatus.pending ||
        appointment.durationMinutes != durationMinutes ||
        appointment.dateTime.isUtc ||
        !appointment.dateTime.isAfter(now) ||
        !workingSlots(
          doctor,
          appointment.dateTime,
        ).contains(appointment.dateTime)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Choose a future 30-minute slot within the doctor\'s working hours.',
      );
    }
    if (appointment.fee != doctor.consultationFee ||
        appointment.specialty != doctor.specialty) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'Doctor details changed. Refresh and choose the slot again.',
      );
    }
    if (hasConflict(
      snapshot.appointments,
      doctorId: doctor.id,
      patientId: patient.id,
      at: appointment.dateTime,
    )) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This time overlaps a doctor or patient appointment. Choose another slot.',
      );
    }
  }

  /// A repeated request ID may acknowledge the same original booking only.
  static bool sameRequest(Appointment existing, Appointment request) =>
      request.status == AppointmentStatus.pending &&
      existing.patientId == request.patientId &&
      existing.doctorId == request.doctorId &&
      existing.dateTime == request.dateTime &&
      existing.durationMinutes == request.durationMinutes &&
      existing.fee == request.fee &&
      existing.specialty == request.specialty &&
      existing.reason == request.reason;
}
