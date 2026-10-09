import 'app_enums.dart';
import 'clinic_snapshot.dart';
import 'entities.dart';

class RevenueMonth {
  final DateTime month;
  final int cents;
  const RevenueMonth(this.month, this.cents);
  double get total => cents / 100;
}

class SpecialtyCount {
  final MedicalSpecialty specialty;
  final int count;
  const SpecialtyCount(this.specialty, this.count);
}

/// Current fully paid invoices, grouped by payment month. This is a snapshot
/// metric, not a cash-flow ledger: partial/refunded invoices are excluded.
class ClinicAnalytics {
  final List<RevenueMonth> months;
  final List<SpecialtyCount> specialties;
  final List<Appointment> recentChanges;
  final int paidCents;
  final int excludedPaidInvoices;

  ClinicAnalytics._(
    this.months,
    this.specialties,
    this.recentChanges,
    this.paidCents,
    this.excludedPaidInvoices,
  );

  factory ClinicAnalytics(ClinicSnapshot snapshot, DateTime now) {
    // Adapters normalize backend dates to clinic time; the demo supplies local
    // dates. Converting again would replace the clinic calendar with the device's.
    final dates = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final totals = List<int>.filled(6, 0);
    var paidCents = 0;
    var excluded = 0;
    for (final invoice in snapshot.invoices) {
      if (invoice.paymentStatus != PaymentStatus.paid) continue;
      final paid = invoice.paidDate;
      if (paid == null ||
          paid.isAfter(now) ||
          paid.isBefore(invoice.issuedDate) ||
          !invoice.total.isFinite ||
          invoice.total < 0 ||
          invoice.total * 100 > 9007199254740991) {
        excluded++;
        continue;
      }
      final cents = (invoice.total * 100).round();
      paidCents += cents;
      final index =
          (paid.year - dates.first.year) * 12 + paid.month - dates.first.month;
      if (index >= 0 && index < totals.length) totals[index] += cents;
    }
    final counts = <MedicalSpecialty, int>{};
    for (final visit in snapshot.appointments) {
      counts.update(visit.specialty, (n) => n + 1, ifAbsent: () => 1);
    }
    final specialties =
        counts.entries.map((e) => SpecialtyCount(e.key, e.value)).toList()
          ..sort((a, b) {
            final comparison = b.count.compareTo(a.count);
            return comparison != 0
                ? comparison
                : a.specialty.index.compareTo(b.specialty.index);
          });
    final recent = snapshot.appointments.toList()
      ..sort((a, b) {
        final comparison = b.updatedAt.compareTo(a.updatedAt);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
    return ClinicAnalytics._(
      List.unmodifiable(
        List.generate(6, (i) => RevenueMonth(dates[i], totals[i])),
      ),
      List.unmodifiable(specialties),
      List.unmodifiable(recent.take(4)),
      paidCents,
      excluded,
    );
  }
  double get paidInvoiceTotal => paidCents / 100;
  double get periodTotal => months.fold<int>(0, (n, m) => n + m.cents) / 100;
}
