import 'app_enums.dart';
import 'billing_policy.dart';
import 'clinic_repository.dart';
import 'entities.dart';

class IssueAppointmentInvoice {
  final ClinicRepository _repository;
  final String Function() _newId;
  const IssueAppointmentInvoice(this._repository, this._newId);
  Future<Invoice> call({
    required ClinicUser? actor,
    required String appointmentId,
  }) {
    BillingPolicy.requireAdmin(actor);
    return _repository.issueAppointmentInvoice(
      actor: actor!,
      appointmentId: appointmentId,
      invoiceId: _newId(),
    );
  }
}

class RecordInvoicePayment {
  final ClinicRepository _repository;
  const RecordInvoicePayment(this._repository);
  Future<Invoice> call({
    required ClinicUser? actor,
    required String invoiceId,
    required PaymentStatus expected,
    required PaymentStatus target,
    DemoPaymentMethod? method,
  }) {
    BillingPolicy.requireAdmin(actor);
    return _repository.recordInvoicePayment(
      actor: actor!,
      invoiceId: invoiceId,
      expected: expected,
      target: target,
      method: method,
    );
  }
}
