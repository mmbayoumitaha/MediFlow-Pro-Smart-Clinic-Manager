import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/patient/screens/book_appointment_screen.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  Future<ProviderContainer> setup(WidgetTester tester, String path) async {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(() => 'slot-widget-booking'),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login('demo@mediflow.com', 'dummy123', UserRole.patient);
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

  testWidgets(
    'directory search carries the chosen doctor into working-hour booking',
    (tester) async {
      final container = await setup(tester, '/patient/doctors');
      await tester.enterText(find.byType(TextField), 'nora');
      await tester.pumpAndSettle();
      expect(find.text('Dr. Ahmed Hassan'), findsNothing);
      await tester.tap(find.text('Dr. Nora Ibrahim'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookAppointmentScreen>(find.byType(BookAppointmentScreen))
            .doctorId,
        'doc-006',
      );
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 6))));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '09:00 AM'), findsNothing);
      final at = find.widgetWithText(ChoiceChip, '10:00 AM');
      await tester.ensureVisible(at);
      await tester.tap(at);
      await tester.pumpAndSettle();
      final book = find.widgetWithText(FilledButton, 'Confirm Booking');
      await tester.ensureVisible(book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final snapshot = await container.read(clinicRepositoryProvider).load();
      final appointment = snapshot.appointments.singleWhere(
        (a) => a.id == 'slot-widget-booking',
      );
      expect(appointment.doctorId, 'doc-006');
      expect(appointment.dateTime, DateTime(2026, 10, 6, 10));
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/patient/appointments',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'invalid deep link and a slot taken after selection cannot submit stale data',
    (tester) async {
      final container = await setup(tester, '/patient/book?doctorId=missing');
      expect(
        find.text('This doctor no longer exists. Choose another doctor.'),
        findsOneWidget,
      );
      final book = find.widgetWithText(FilledButton, 'Confirm Booking');
      expect(tester.widget<FilledButton>(book).onPressed, isNull);
      container.read(routerProvider).go('/patient/book?doctorId=doc-001');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 6))));
      await tester.pumpAndSettle();
      final time = find.widgetWithText(ChoiceChip, '01:30 PM');
      await tester.ensureVisible(time);
      await tester.tap(time);
      await tester.pump();
      expect(tester.widget<FilledButton>(book).onPressed, isNotNull);
      final repository = container.read(clinicRepositoryProvider);
      final source = await repository.load();
      await repository.bookAppointment(
        source.appointments.first.copyWith(
          id: 'competing-reservation',
          patientId: 'pat-002',
          status: AppointmentStatus.pending,
          dateTime: DateTime(2026, 10, 6, 13, 30),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '01:30 PM'), findsNothing);
      expect(tester.widget<FilledButton>(book).onPressed, isNull);
      final replacement = find.widgetWithText(ChoiceChip, '02:00 PM');
      await tester.ensureVisible(replacement);
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      await tester.ensureVisible(book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      expect((await repository.load()).appointments, hasLength(10));
      expect(container.read(appointmentsProvider), hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
