import 'clinic_snapshot.dart';
import 'entities.dart';

abstract interface class ClinicRepository {
  Future<ClinicSnapshot> load();

  /// Every subscription receives current data (or an error), then updates.
  Stream<ClinicSnapshot> watch();

  /// Register a patient or a user with a matching doctor profile atomically.
  Future<void> registerUser(ClinicUser user, {Doctor? doctor});

  /// Persist a new appointment and publish the updated snapshot.
  Future<void> bookAppointment(Appointment appointment);
}
