import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/admin/screens/billing_screen.dart';
import 'package:mediflow/features/clinic/data/clinic_mapper.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  testWidgets(
    'admin issues, cancels a settlement, then settles and refunds with live totals',
    (tester) async {
      var clock = DateTime(2026, 10, 5, 9);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => clock),
          idGeneratorProvider.overrideWithValue(() => 'invoice-widget'),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authProvider.notifier);
      await auth.login('demo@mediflow.com', 'dummy123', UserRole.patient);
      final repo = container.read(clinicRepositoryProvider);
      final visit =
          await BookAppointment(
            repo,
            now: () => clock,
            newId: () => 'billing-widget',
          )(
            patient: container.read(authProvider).currentUser,
            doctorId: 'doc-001',
            dateTime: DateTime(2026, 10, 6, 13, 30),
          );
      await auth.logout();
      await auth.login('demo@mediflow.com', 'dummy123', UserRole.doctor);
      final doctor = container.read(authProvider).currentUser!;
      await repo.changeAppointmentStatus(
        actor: doctor,
        appointmentId: visit.id,
        expected: AppointmentStatus.pending,
        target: AppointmentStatus.confirmed,
      );
      clock = visit.dateTime;
      await repo.changeAppointmentStatus(
        actor: doctor,
        appointmentId: visit.id,
        expected: AppointmentStatus.confirmed,
        target: AppointmentStatus.inProgress,
      );
      await repo.changeAppointmentStatus(
        actor: doctor,
        appointmentId: visit.id,
        expected: AppointmentStatus.inProgress,
        target: AppointmentStatus.completed,
      );
      await auth.logout();
      await auth.login('demo@mediflow.com', 'dummy123', UserRole.admin);
      container.read(routerProvider).go('/admin/billing');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapKey(String key) async {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await Scrollable.ensureVisible(tester.element(finder), alignment: .1);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapKey('issue-billing-widget');
      await tester.tap(find.widgetWithText(FilledButton, 'Issue invoice'));
      await tester.pumpAndSettle();
      expect((await repo.load()).invoices, hasLength(4));
      await tapKey('settle-invoice-widget');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(clinicAnalyticsProvider).paidInvoiceTotal, 1083);
      await tapKey('settle-invoice-widget');
      await tester.tap(find.text('Record settlement'));
      await tester.pumpAndSettle();
      expect(container.read(clinicAnalyticsProvider).paidInvoiceTotal, 1433);
      expect(
        (await repo.load()).appointments
            .singleWhere((a) => a.id == visit.id)
            .paymentStatus,
        PaymentStatus.paid,
      );
      await tapKey('refund-invoice-widget');
      await tester.tap(find.text('Record refund'));
      await tester.pumpAndSettle();
      expect(container.read(clinicAnalyticsProvider).paidInvoiceTotal, 1083);
      expect(find.byKey(const ValueKey('refund-invoice-widget')), findsNothing);
      container.read(routerProvider).go('/admin');
      await tester.pumpAndSettle();
      expect(find.text('USD 1,083.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  testWidgets('every payment status is rendered with its own label', (
    tester,
  ) async {
    final seed = DateTime(2026, 10, 5, 9);
    final original = DemoFixtures.generateInvoices(at: seed).first;
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => seed),
        invoicesProvider.overrideWithValue(
          PaymentStatus.values
              .map(
                (s) => ClinicMapper.invoiceFromMap({
                  ...ClinicMapper.invoiceToMap(original),
                  'id': s.value,
                  'paymentStatus': s.value,
                }),
              )
              .toList(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BillingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final status in PaymentStatus.values) {
      final finder = find.text(status.labelEn);
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(finder, findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
}
