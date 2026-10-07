import 'app_enums.dart';
import 'clinic_failure.dart';
import 'entities.dart';

enum DemoPaymentMethod { cash, card, bankTransfer }

abstract final class BillingPolicy {
  static void requireAdmin(ClinicUser? actor) {
    if (actor == null || !actor.isActive || actor.role != UserRole.admin) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Only an active administrator can change billing.',
      );
    }
  }

  static int cents(double value) {
    final scaled = value * 100;
    if (!value.isFinite ||
        value < 0 ||
        scaled > 9007199254740991 ||
        (scaled - scaled.roundToDouble()).abs() > .000001) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Amounts must be non-negative and have at most two decimal places.',
      );
    }
    return scaled.round();
  }

  static void validateInvoice(Invoice invoice, DateTime now) {
    final subtotal = cents(invoice.subtotal);
    final total = cents(invoice.total);
    final tax = cents(invoice.tax);
    final discount = cents(invoice.discount);
    var sum = 0;
    for (final item in invoice.items) {
      if (item.description.trim().isEmpty ||
          item.quantity < 1 ||
          cents(item.total) != cents(item.unitPrice) * item.quantity) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'Invoice line items are invalid.',
        );
      }
      sum += cents(item.total);
    }
    if (invoice.items.isEmpty ||
        subtotal != sum ||
        total != subtotal + tax - discount ||
        total <= 0 ||
        invoice.issuedDate.isAfter(now)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Invoice totals or issue date are invalid.',
      );
    }
  }

  static void validateTransition(
    Invoice invoice,
    PaymentStatus expected,
    PaymentStatus target,
    DemoPaymentMethod? method,
    DateTime now,
  ) {
    if (invoice.paymentStatus != expected) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This invoice changed. Refresh and try again.',
      );
    }
    validateInvoice(invoice, now);
    final settle =
        target == PaymentStatus.paid &&
        method != null &&
        (expected == PaymentStatus.unpaid || expected == PaymentStatus.partial);
    final refund =
        target == PaymentStatus.refunded &&
        expected == PaymentStatus.paid &&
        invoice.paidDate != null &&
        !invoice.paidDate!.isAfter(now) &&
        !invoice.paidDate!.isBefore(invoice.issuedDate);
    if (!settle && !refund) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Only full settlement or full refund can be recorded.',
      );
    }
  }
}
