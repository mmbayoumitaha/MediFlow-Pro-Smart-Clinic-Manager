import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import '../domain/app_enums.dart';
import '../domain/billing_policy.dart';
import '../domain/billing_use_cases.dart';
import '../domain/clinic_failure.dart';

class BillingActionState {
  final String? busyId;
  final String? error;
  const BillingActionState({this.busyId, this.error});
}

class BillingViewModel extends StateNotifier<BillingActionState> {
  final IssueAppointmentInvoice _issue;
  final RecordInvoicePayment _record;
  final ClinicUser? Function() _actor;
  BillingViewModel(this._issue, this._record, this._actor)
    : super(const BillingActionState());

  Future<bool> _run(String id, Future<Invoice> Function() operation) async {
    if (!mounted || state.busyId != null) return false;
    state = BillingActionState(busyId: id);
    try {
      await operation();
      if (!mounted) return false;
      state = const BillingActionState();
      return true;
    } catch (error) {
      if (mounted) {
        state = BillingActionState(
          error: error is ClinicFailure
              ? error.message
              : 'Billing could not be updated. Try again.',
        );
      }
      return false;
    }
  }

  Future<bool> issue(String appointmentId) => _run(
    appointmentId,
    () => _issue(actor: _actor(), appointmentId: appointmentId),
  );
  Future<bool> record(
    Invoice invoice,
    PaymentStatus target, {
    DemoPaymentMethod? method,
  }) => _run(
    invoice.id,
    () => _record(
      actor: _actor(),
      invoiceId: invoice.id,
      expected: invoice.paymentStatus,
      target: target,
      method: method,
    ),
  );
}
