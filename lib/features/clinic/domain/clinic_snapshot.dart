import 'entities.dart';

/// A consistent, immutable clinic snapshot. All lists take defensive copies.
class ClinicSnapshot {
  final List<Doctor> doctors;
  final List<ClinicUser> patients;
  final List<Appointment> appointments;
  final List<Prescription> prescriptions;
  final List<Invoice> invoices;

  ClinicSnapshot({
    List<Doctor> doctors = const [],
    List<ClinicUser> patients = const [],
    List<Appointment> appointments = const [],
    List<Prescription> prescriptions = const [],
    List<Invoice> invoices = const [],
  }) : doctors = List.unmodifiable(doctors),
       patients = List.unmodifiable(patients),
       appointments = List.unmodifiable(appointments),
       prescriptions = List.unmodifiable(prescriptions),
       invoices = List.unmodifiable(invoices);

  ClinicSnapshot copyWith({
    List<Doctor>? doctors,
    List<ClinicUser>? patients,
    List<Appointment>? appointments,
    List<Prescription>? prescriptions,
    List<Invoice>? invoices,
  }) => ClinicSnapshot(
    doctors: doctors ?? this.doctors,
    patients: patients ?? this.patients,
    appointments: appointments ?? this.appointments,
    prescriptions: prescriptions ?? this.prescriptions,
    invoices: invoices ?? this.invoices,
  );
}
