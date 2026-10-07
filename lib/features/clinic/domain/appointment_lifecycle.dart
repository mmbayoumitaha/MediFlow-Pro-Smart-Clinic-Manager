import 'app_enums.dart';
import 'clinic_failure.dart';
import 'clinic_snapshot.dart';
import 'entities.dart';

abstract final class AppointmentLifecycle {
  static bool _owns(
    ClinicSnapshot snapshot,
    ClinicUser? actor,
    Appointment visit,
  ) {
    if (actor == null || !actor.isActive) return false;
    switch (actor.role) {
      case UserRole.admin:
        return true;
      case UserRole.patient:
        return actor.id == visit.patientId &&
            snapshot.patients.any(
              (p) =>
                  p.id == actor.id && p.isActive && p.role == UserRole.patient,
            );
      case UserRole.doctor:
        final profiles = snapshot.doctors.where((d) => d.userId == actor.id);
        return profiles.length == 1 && profiles.single.id == visit.doctorId;
    }
  }

  static List<AppointmentStatus> targets(
    ClinicSnapshot snapshot,
    ClinicUser? actor,
    Appointment visit,
    DateTime now,
  ) {
    if (!_owns(snapshot, actor, visit)) return const [];
    final isPatient = actor!.role == UserRole.patient;
    final future = visit.dateTime.isAfter(now);
    final started = !now.isBefore(visit.dateTime);
    final ended = !now.isBefore(
      visit.dateTime.add(Duration(minutes: visit.durationMinutes)),
    );
    return List.unmodifiable([
      if (!isPatient &&
          visit.status == AppointmentStatus.pending &&
          !now.isAfter(visit.dateTime))
        AppointmentStatus.confirmed,
      if (!isPatient && visit.status == AppointmentStatus.confirmed && started)
        AppointmentStatus.inProgress,
      if (!isPatient && visit.status == AppointmentStatus.inProgress && started)
        AppointmentStatus.completed,
      if ((visit.status == AppointmentStatus.pending ||
              visit.status == AppointmentStatus.confirmed) &&
          (!isPatient || future))
        AppointmentStatus.cancelled,
      if (!isPatient &&
          ended &&
          (visit.status == AppointmentStatus.pending ||
              visit.status == AppointmentStatus.confirmed))
        AppointmentStatus.noShow,
    ]);
  }

  static void validate(
    ClinicSnapshot snapshot,
    ClinicUser actor,
    Appointment visit,
    AppointmentStatus expected,
    AppointmentStatus target,
    DateTime now,
  ) {
    if (!_owns(snapshot, actor, visit)) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'You cannot change this appointment.',
      );
    }
    if (visit.status != expected) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This appointment changed. Refresh and try again.',
      );
    }
    if (!targets(snapshot, actor, visit, now).contains(target)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'This status change is not allowed at this time.',
      );
    }
  }
}
