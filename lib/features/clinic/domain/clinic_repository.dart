import 'clinic_snapshot.dart';
import 'app_enums.dart';
import 'entities.dart';
import 'billing_policy.dart';

abstract interface class ClinicRepository {
  Future<ClinicSnapshot> load();

  /// Every subscription receives current data (or an error), then updates.
  Stream<ClinicSnapshot> watch();

  /// Register a patient or a user with a matching doctor profile atomically.
  Future<void> registerUser(ClinicUser user, {Doctor? doctor});

  /// Atomically validate/persist a reservation; acknowledge identical ID retries.
  Future<void> bookAppointment(Appointment appointment);

  /// Apply an authorized transition against the current status and repository clock.
  Future<Appointment> changeAppointmentStatus({
    required ClinicUser actor,
    required String appointmentId,
    required AppointmentStatus expected,
    required AppointmentStatus target,
  });

  /// One consultation-only invoice per completed visit; identical retries return it.
  Future<Invoice> issueAppointmentInvoice({
    required ClinicUser actor,
    required String appointmentId,
    required String invoiceId,
  });

  /// Atomic demo settlement/refund with an expected-status concurrency check.
  Future<Invoice> recordInvoicePayment({
    required ClinicUser actor,
    required String invoiceId,
    required PaymentStatus expected,
    required PaymentStatus target,
    DemoPaymentMethod? method,
  });
}
