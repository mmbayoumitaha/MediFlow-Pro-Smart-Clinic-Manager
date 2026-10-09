import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_analytics.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  final now = DateTime(2026, 2, 5, 9);
  Invoice invoice(
    String id,
    double total,
    DateTime? paid, {
    PaymentStatus status = PaymentStatus.paid,
    DateTime? issued,
  }) => Invoice(
    id: id,
    patientId: 'p',
    patientName: 'Patient',
    items: const [],
    subtotal: total,
    total: total,
    paymentStatus: status,
    issuedDate: issued ?? DateTime(2020),
    paidDate: paid,
    createdAt: DateTime(2020),
  );

  test(
    'six zero months cross the year boundary and collections are immutable',
    () {
      final a = ClinicAnalytics(ClinicSnapshot(), now);
      expect(
        a.months.map((m) => m.month),
        List.generate(6, (i) => DateTime(2025, 9 + i)),
      );
      expect(a.months.map((m) => m.cents), everyElement(0));
      expect(a.paidInvoiceTotal, 0);
      expect(a.specialties, isEmpty);
      expect(a.recentChanges, isEmpty);
      expect(() => a.months.clear(), throwsUnsupportedError);
    },
  );

  test(
    'payment month, range edges and cent arithmetic agree with lifetime totals',
    () {
      final a = ClinicAnalytics(
        ClinicSnapshot(
          invoices: [
            invoice('old', 50, DateTime(2025, 8, 31)),
            invoice('start', .1, DateTime(2025, 9)),
            invoice('same-month', .2, DateTime(2025, 9, 30, 23, 59)),
            invoice('end', 100000, now),
            invoice('unpaid', 20, now, status: PaymentStatus.unpaid),
            invoice('partial', 30, now, status: PaymentStatus.partial),
            invoice('refund', 40, now, status: PaymentStatus.refunded),
          ],
        ),
        now,
      );
      expect(a.months.first.cents, 30);
      expect(a.months.last.total, 100000);
      expect(a.periodTotal, 100000.3);
      expect(a.paidInvoiceTotal, 100050.3);
    },
  );

  test(
    'invalid paid records are flagged instead of fabricating dates or revenue',
    () {
      final a = ClinicAnalytics(
        ClinicSnapshot(
          invoices: [
            invoice('no-date', 1, null),
            invoice('future', 1, now.add(const Duration(seconds: 1))),
            invoice(
              'reversed',
              1,
              now,
              issued: now.add(const Duration(days: 1)),
            ),
            invoice('negative', -1, now),
            invoice('nan', double.nan, now),
            invoice('infinite', double.infinity, now),
            invoice('too-large', 1e308, now),
          ],
        ),
        now,
      );
      expect(a.excludedPaidInvoices, 7);
      expect(a.paidInvoiceTotal, 0);
    },
  );

  test(
    'payment-month grouping preserves the clinic calendar across UTC midnight',
    () {
      final clock = ClinicClock();
      final paid = clock.inClinic(DateTime.utc(2026, 1, 31, 22, 30));
      final evaluated = clock.inClinic(DateTime.utc(2026, 2, 5, 7));
      expect(paid.month, 2);
      final analytics = ClinicAnalytics(
        ClinicSnapshot(invoices: [invoice('clinic-midnight', 80.25, paid)]),
        evaluated,
      );
      expect(analytics.months.last.month.month, 2);
      expect(analytics.months.last.total, 80.25);
      expect(analytics.months[4].total, 0);
    },
  );

  test(
    'specialty distribution includes every status and specialty without Others',
    () {
      final base = DemoFixtures.generateAppointments(at: now).first;
      final visits = List.generate(
        MedicalSpecialty.values.length,
        (i) => base.copyWith(
          id: '$i',
          specialty: MedicalSpecialty.values[i],
          status: AppointmentStatus.values[i % AppointmentStatus.values.length],
        ),
      );
      visits.add(
        base.copyWith(id: 'extra', specialty: MedicalSpecialty.gynecology),
      );
      final a = ClinicAnalytics(ClinicSnapshot(appointments: visits), now);
      expect(a.specialties, hasLength(MedicalSpecialty.values.length));
      expect(a.specialties.first.specialty, MedicalSpecialty.gynecology);
      expect(a.specialties.first.count, 2);
      expect(a.specialties.fold<int>(0, (n, s) => n + s.count), visits.length);
    },
  );

  test(
    'recent changes sort by update time then ID without mutating the snapshot',
    () {
      final base = DemoFixtures.generateAppointments(at: now).first;
      final visits = [
        base.copyWith(id: 'old', updatedAt: DateTime(2025)),
        base.copyWith(id: 'b', updatedAt: now),
        base.copyWith(id: 'a', updatedAt: now),
        base.copyWith(
          id: 'new',
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        base.copyWith(
          id: 'middle',
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      final a = ClinicAnalytics(ClinicSnapshot(appointments: visits), now);
      expect(a.recentChanges.map((v) => v.id), ['new', 'a', 'b', 'middle']);
      expect(visits.first.id, 'old');
      expect(() => a.specialties.clear(), throwsUnsupportedError);
      expect(() => a.recentChanges.clear(), throwsUnsupportedError);
    },
  );
}
