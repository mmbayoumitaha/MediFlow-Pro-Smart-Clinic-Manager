import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  var clock = DateTime(2026, 10, 5, 9);
  final at = DateTime(2026, 10, 6, 13, 30);
  Future<ProviderContainer> setup(
    WidgetTester tester,
    UserRole role,
    String path,
  ) async {
    clock = DateTime(2026, 10, 5, 9);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => clock)],
    );
    addTearDown(container.dispose);
    final auth = container.read(authProvider.notifier);
    await auth.login('demo@mediflow.com', 'dummy123', UserRole.patient);
    await BookAppointment(
      container.read(clinicRepositoryProvider),
      now: () => clock,
      newId: () => 'widget-lifecycle',
    )(
      patient: container.read(authProvider).currentUser,
      doctorId: 'doc-001',
      dateTime: at,
    );
    if (role != UserRole.patient) {
      await auth.logout();
      await auth.login('demo@mediflow.com', 'dummy123', role);
    }
    container.read(routerProvider).go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder action(AppointmentStatus status) =>
      find.byKey(ValueKey('appointment-widget-lifecycle-${status.value}'));
  Future<void> open(WidgetTester tester, AppointmentStatus status) async {
    // Let feedback from the previous action expire before the next tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      action(status),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(action(status)),
      alignment: 0.1,
    );
    await tester.pumpAndSettle();
    await tester.tap(action(status));
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester, AppointmentStatus status) async {
    await open(tester, status);
    await tester.tap(find.text('Apply change'));
    await tester.pumpAndSettle();
  }

  Future<AppointmentStatus> currentStatus(ProviderContainer container) async =>
      (await container.read(clinicRepositoryProvider).load()).appointments
          .singleWhere((a) => a.id == 'widget-lifecycle')
          .status;

  testWidgets(
    'patient cancellation confirmation preserves or releases the visit and shows history',
    (tester) async {
      final container = await setup(
        tester,
        UserRole.patient,
        '/patient/appointments',
      );
      await open(tester, AppointmentStatus.cancelled);
      await tester.tap(find.text('Keep appointment'));
      await tester.pumpAndSettle();
      expect(await currentStatus(container), AppointmentStatus.pending);
      await apply(tester, AppointmentStatus.cancelled);
      expect(await currentStatus(container), AppointmentStatus.cancelled);
      expect(container.read(clinicMetricsProvider).completed, isEmpty);
      expect(
        container
            .read(upcomingAppointmentsProvider)
            .any((a) => a.id == 'widget-lifecycle'),
        isFalse,
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);
      expect(action(AppointmentStatus.confirmed), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'doctor confirms, clock enables check-in, completion reaches the patient history',
    (tester) async {
      final container = await setup(
        tester,
        UserRole.doctor,
        '/doctor/schedule',
      );
      await apply(tester, AppointmentStatus.confirmed);
      expect(await currentStatus(container), AppointmentStatus.confirmed);
      expect(action(AppointmentStatus.inProgress), findsNothing);
      clock = at;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      await apply(tester, AppointmentStatus.inProgress);
      expect(
        container
            .read(upcomingAppointmentsProvider)
            .any((a) => a.id == 'widget-lifecycle'),
        isTrue,
      );
      await apply(tester, AppointmentStatus.completed);
      expect(await currentStatus(container), AppointmentStatus.completed);
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login('demo@mediflow.com', 'dummy123', UserRole.patient);
      container.read(routerProvider).go('/patient/appointments');
      await tester.pumpAndSettle();
      expect(container.read(clinicMetricsProvider).completed, hasLength(1));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(action(AppointmentStatus.completed), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'admin reaches all appointments and marks a no-show at the scheduled end',
    (tester) async {
      final container = await setup(tester, UserRole.admin, '/admin');
      final viewAll = find.widgetWithText(TextButton, 'View All');
      await tester.ensureVisible(viewAll);
      await tester.pumpAndSettle();
      await tester.tap(viewAll);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/admin/appointments',
      );
      clock = at.add(const Duration(minutes: 30));
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      await apply(tester, AppointmentStatus.noShow);
      expect(await currentStatus(container), AppointmentStatus.noShow);
      expect(
        container
            .read(pastAppointmentsProvider)
            .any((a) => a.id == 'widget-lifecycle'),
        isTrue,
      );
      expect(container.read(clinicMetricsProvider).completed, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'live clock rolls booking dates over midnight without resetting the clinic',
    (tester) async {
      final container = await setup(
        tester,
        UserRole.patient,
        '/patient/book?doctorId=doc-001',
      );
      final repository = container.read(clinicRepositoryProvider);
      final count = (await repository.load()).appointments.length;
      clock = DateTime(2026, 10, 5, 23, 59);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(
        container.read(bookingDateOptionsProvider).first,
        DateTime(2026, 10, 6),
      );
      clock = DateTime(2026, 10, 6);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(
        container.read(bookingDateOptionsProvider).first,
        DateTime(2026, 10, 7),
      );
      expect(container.read(clinicRepositoryProvider), same(repository));
      expect((await repository.load()).appointments, hasLength(count));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
