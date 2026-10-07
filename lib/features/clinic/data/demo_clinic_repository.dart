import 'dart:async';

import '../domain/app_enums.dart';
import '../domain/appointment_policy.dart';
import '../domain/appointment_lifecycle.dart';
import '../domain/clinic_failure.dart';
import '../domain/clinic_repository.dart';
import '../domain/clinic_snapshot.dart';
import '../domain/entities.dart';
import '../domain/billing_policy.dart';
import 'demo_fixtures.dart';

/// Isolated, session-only data. The entire fixture set shares one seed clock.
class DemoClinicRepository implements ClinicRepository {
  final _changes = StreamController<ClinicSnapshot>.broadcast(sync: true);
  late ClinicSnapshot _snapshot;
  bool _disposed = false;
  final DateTime Function() _now;

  DemoClinicRepository({required DateTime at, DateTime Function()? now})
    : _now = now ?? (() => at) {
    _snapshot = ClinicSnapshot(
      doctors: DemoFixtures.generateDoctors(),
      patients: DemoFixtures.generatePatients(at: at),
      appointments: DemoFixtures.generateAppointments(at: at),
      prescriptions: DemoFixtures.generatePrescriptions(at: at),
      invoices: DemoFixtures.generateInvoices(at: at),
    );
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'Demo session is closed.',
      );
    }
  }

  @override
  Future<ClinicSnapshot> load() async {
    _ensureOpen();
    return _snapshot;
  }

  @override
  Stream<ClinicSnapshot> watch() => Stream.multi((controller) {
    if (_disposed) {
      controller.addError(
        const ClinicFailure(FailureCode.unavailable, 'Demo session is closed.'),
      );
      controller.close();
      return;
    }
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_snapshot);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> registerUser(ClinicUser user, {Doctor? doctor}) async {
    _ensureOpen();
    final duplicate =
        _snapshot.patients.any(
          (p) =>
              p.id == user.id ||
              p.email.toLowerCase() == user.email.toLowerCase(),
        ) ||
        _snapshot.doctors.any(
          (d) =>
              d.userId == user.id ||
              d.email.toLowerCase() == user.email.toLowerCase(),
        );
    if (duplicate) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'A demo account already uses this email or ID.',
      );
    }
    if (user.role == UserRole.patient && doctor == null) {
      _publish(_snapshot.copyWith(patients: [..._snapshot.patients, user]));
    } else if (user.role == UserRole.doctor &&
        doctor != null &&
        doctor.userId == user.id &&
        doctor.email == user.email &&
        !_snapshot.doctors.any((d) => d.id == doctor.id)) {
      _publish(_snapshot.copyWith(doctors: [..._snapshot.doctors, doctor]));
    } else {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Registration requires a matching patient or doctor profile.',
      );
    }
  }

  @override
  Future<void> bookAppointment(Appointment appointment) async {
    _ensureOpen();
    final existing = _snapshot.appointments.where(
      (a) => a.id == appointment.id,
    );
    if (existing.isNotEmpty) {
      if (AppointmentPolicy.sameRequest(existing.single, appointment)) return;
      throw const ClinicFailure(
        FailureCode.conflict,
        'This appointment already exists.',
      );
    }
    // No await between validation and publication: competing demo reservations
    // are serialized against the latest snapshot. Firebase must use a transaction.
    AppointmentPolicy.validate(_snapshot, appointment, _now());
    _publish(
      _snapshot.copyWith(
        appointments: [
          appointment.copyWith(
            patientName: _snapshot.patients
                .singleWhere((p) => p.id == appointment.patientId)
                .fullName,
            doctorName: _snapshot.doctors
                .singleWhere((d) => d.id == appointment.doctorId)
                .fullName,
          ),
          ..._snapshot.appointments,
        ],
      ),
    );
  }

  void _publish(ClinicSnapshot snapshot) {
    _snapshot = snapshot;
    _changes.add(snapshot);
  }

  @override
  Future<Appointment> changeAppointmentStatus({
    required ClinicUser actor,
    required String appointmentId,
    required AppointmentStatus expected,
    required AppointmentStatus target,
  }) async {
    _ensureOpen();
    final visits = _snapshot.appointments.where((a) => a.id == appointmentId);
    if (visits.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Appointment is unavailable.',
      );
    }
    final now = _now();
    final current = visits.single;
    AppointmentLifecycle.validate(
      _snapshot,
      actor,
      current,
      expected,
      target,
      now,
    );
    final updated = current.copyWith(status: target, updatedAt: now);
    _publish(
      _snapshot.copyWith(
        appointments: _snapshot.appointments
            .map((a) => a.id == appointmentId ? updated : a)
            .toList(),
      ),
    );
    return updated;
  }

  @override
  Future<Invoice> issueAppointmentInvoice({
    required ClinicUser actor,
    required String appointmentId,
    required String invoiceId,
  }) async {
    _ensureOpen();
    BillingPolicy.requireAdmin(actor);
    final existing = _snapshot.invoices.where(
      (i) => i.appointmentId == appointmentId,
    );
    if (existing.length == 1) return existing.single;
    if (existing.length > 1) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This visit has multiple invoices.',
      );
    }
    final visits = _snapshot.appointments.where((a) => a.id == appointmentId);
    if (visits.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Appointment is unavailable.',
      );
    }
    final visit = visits.single;
    if (visit.status != AppointmentStatus.completed ||
        visit.paymentStatus != PaymentStatus.unpaid) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Only an unpaid completed visit can receive a new invoice.',
      );
    }
    if (invoiceId.trim().isEmpty ||
        _snapshot.invoices.any((i) => i.id == invoiceId)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'Invoice ID is unavailable.',
      );
    }
    final now = _now();
    final invoice = Invoice(
      id: invoiceId,
      patientId: visit.patientId,
      patientName: visit.patientName,
      appointmentId: visit.id,
      items: [
        InvoiceItem(
          description: 'Consultation with ${visit.doctorName}',
          unitPrice: visit.fee,
          total: visit.fee,
        ),
      ],
      subtotal: visit.fee,
      total: visit.fee,
      issuedDate: now,
      createdAt: now,
    );
    BillingPolicy.validateInvoice(invoice, now);
    _publish(_snapshot.copyWith(invoices: [invoice, ..._snapshot.invoices]));
    return invoice;
  }

  @override
  Future<Invoice> recordInvoicePayment({
    required ClinicUser actor,
    required String invoiceId,
    required PaymentStatus expected,
    required PaymentStatus target,
    DemoPaymentMethod? method,
  }) async {
    _ensureOpen();
    BillingPolicy.requireAdmin(actor);
    final invoices = _snapshot.invoices.where((i) => i.id == invoiceId);
    if (invoices.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Invoice is unavailable.',
      );
    }
    final invoice = invoices.single;
    final now = _now();
    BillingPolicy.validateTransition(invoice, expected, target, method, now);
    if (invoice.appointmentId != null) {
      final visits = _snapshot.appointments.where(
        (a) => a.id == invoice.appointmentId,
      );
      final linkedInvoices = _snapshot.invoices.where(
        (i) => i.appointmentId == invoice.appointmentId,
      );
      if (visits.length != 1 ||
          visits.single.patientId != invoice.patientId ||
          linkedInvoices.length != 1) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'Invoice appointment linkage is invalid.',
        );
      }
    }
    final updated = invoice.copyWith(
      paymentStatus: target,
      paymentMethod: target == PaymentStatus.paid
          ? method!.name
          : invoice.paymentMethod,
      paidDate: target == PaymentStatus.paid ? now : invoice.paidDate,
    );
    _publish(
      _snapshot.copyWith(
        invoices: _snapshot.invoices
            .map((i) => i.id == invoiceId ? updated : i)
            .toList(),
        appointments: _snapshot.appointments
            .map(
              (a) => a.id == invoice.appointmentId
                  ? a.copyWith(paymentStatus: target, updatedAt: now)
                  : a,
            )
            .toList(),
      ),
    );
    return updated;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _changes.close();
  }
}
