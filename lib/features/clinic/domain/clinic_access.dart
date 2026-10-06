import 'app_enums.dart';
import 'clinic_snapshot.dart';
import 'entities.dart';

/// Read policy for the synthetic demo. Backend authorization belongs in rules.
abstract final class ClinicAccess {
  static ClinicSnapshot scope(ClinicSnapshot source, ClinicUser? user) {
    if (user == null || !user.isActive) return ClinicSnapshot();
    switch (user.role) {
      case UserRole.admin:
        return source;
      case UserRole.patient:
        return ClinicSnapshot(
          doctors: source.doctors,
          patients: source.patients.where((p) => p.id == user.id).toList(),
          appointments: source.appointments
              .where((a) => a.patientId == user.id)
              .toList(),
          prescriptions: source.prescriptions
              .where((p) => p.patientId == user.id)
              .toList(),
          invoices: source.invoices
              .where((i) => i.patientId == user.id)
              .toList(),
        );
      case UserRole.doctor:
        final profiles = source.doctors
            .where((d) => d.userId == user.id)
            .toList();
        // Missing or ambiguous identity linkage must never select another doctor.
        if (profiles.length != 1) return ClinicSnapshot();
        final doctorId = profiles.single.id;
        final appointments = source.appointments
            .where((a) => a.doctorId == doctorId)
            .toList();
        final patientIds = appointments.map((a) => a.patientId).toSet();
        return ClinicSnapshot(
          doctors: profiles,
          patients: source.patients
              .where((p) => patientIds.contains(p.id))
              .toList(),
          appointments: appointments,
          prescriptions: source.prescriptions
              .where((p) => p.doctorId == doctorId)
              .toList(),
        );
    }
  }
}
