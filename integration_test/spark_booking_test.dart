import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediflow/core/config/backend_configuration.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/authoritative_reservations.dart';
import 'package:mediflow/main.dart' as app;
import 'package:mediflow/routes/app_router.dart';

import 'firebase_workflow_test.dart' as steps;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Spark: scoped booking, retry, lifecycle and cancellation without Functions',
    (tester) async {
      expect(BackendConfiguration.fromEnvironment().projectId, 'demo-mediflow');
      expect(BackendConfiguration.fromEnvironment().useEmulators, isTrue);
      await app.main();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.MediFlowApp)),
      );
      final router = container.read(routerProvider);
      Future<void> scope() => steps.until(tester, () {
        final value = container.read(clinicViewModelProvider);
        return !value.isLoading && !value.hasError && value.valueOrNull != null;
      }, 'trusted clinic scope');
      Future<void> login(String uid, UserRole role) async {
        await container
            .read(authProvider.notifier)
            .login(
              '$uid@example.test',
              'Emulator-only-password1!',
              UserRole.admin,
            );
        await steps.until(
          tester,
          () => container.read(authProvider).currentUser?.id == uid,
          'login $uid',
        );
        expect(container.read(authProvider).currentUser!.role, role);
        await scope();
        await tester.pumpAndSettle();
      }

      await steps.until(
        tester,
        () => !container.read(authProvider).isLoading,
        'initial session',
      );
      await login('browser-patient', UserRole.patient);
      router.go('/patient/book?doctorId=browser-doc1');
      await tester.pumpAndSettle();
      final date = container.read(bookingDateOptionsProvider).first;
      await steps.tap(tester, find.byKey(ValueKey(date)));
      await steps.until(
        tester,
        () => find.widgetWithText(ChoiceChip, '09:00 AM').evaluate().isNotEmpty,
        'direct Firestore availability',
      );
      await steps.tap(tester, find.widgetWithText(ChoiceChip, '09:00 AM'));
      await steps.tap(
        tester,
        find.widgetWithText(FilledButton, 'Confirm Booking'),
      );
      await steps.until(
        tester,
        () => container.read(appointmentsProvider).length == 3,
        'atomic SDK booking',
      );
      final booked = container
          .read(appointmentsProvider)
          .singleWhere((a) => !a.id.startsWith('browser-'));
      final repository = container.read(clinicRepositoryProvider);
      final repeated = await (repository as AuthoritativeReservations).reserve(
        booked,
      );
      expect(repeated.id, booked.id);
      expect(booked.dateTime.hour, 9);
      expect(booked.fee, 80.25);
      final slots = await (repository as AuthoritativeReservations)
          .availableSlots(doctorId: 'browser-doc1', date: date);
      expect(slots.any((at) => at.isAtSameMomentAs(booked.dateTime)), isFalse);
      final runtime = container.read(firebaseRuntimeProvider);
      final lock = await runtime.firestore
          .doc(
            'doctorReservations/browser-doc1/slots/${booked.dateTime.millisecondsSinceEpoch}',
          )
          .get();
      expect(lock.data()!.keys, unorderedEquals(['appointmentId', 'dateTime']));
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      await login('browser-doctor', UserRole.doctor);
      expect(container.read(patientsProvider).single.id, 'browser-patient');
      final actor = container.read(authProvider).currentUser!;
      final staffRepository = container.read(clinicRepositoryProvider);
      await staffRepository.changeAppointmentStatus(
        actor: actor,
        appointmentId: booked.id,
        expected: AppointmentStatus.pending,
        target: AppointmentStatus.confirmed,
      );
      await staffRepository.changeAppointmentStatus(
        actor: actor,
        appointmentId: 'browser-past',
        expected: AppointmentStatus.confirmed,
        target: AppointmentStatus.inProgress,
      );
      await staffRepository.changeAppointmentStatus(
        actor: actor,
        appointmentId: 'browser-past',
        expected: AppointmentStatus.inProgress,
        target: AppointmentStatus.completed,
      );
      await steps.until(
        tester,
        () =>
            container
                .read(appointmentsProvider)
                .singleWhere((a) => a.id == 'browser-past')
                .status ==
            AppointmentStatus.completed,
        'completed past visit',
      );
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      await login('browser-patient', UserRole.patient);
      await container
          .read(clinicRepositoryProvider)
          .changeAppointmentStatus(
            actor: container.read(authProvider).currentUser!,
            appointmentId: booked.id,
            expected: AppointmentStatus.confirmed,
            target: AppointmentStatus.cancelled,
          );
      final free =
          await (container.read(clinicRepositoryProvider)
                  as AuthoritativeReservations)
              .availableSlots(doctorId: 'browser-doc1', date: date);
      expect(free.any((at) => at.isAtSameMomentAs(booked.dateTime)), isTrue);
      expect(
        (await runtime.firestore
                .doc(
                  'doctorReservations/browser-doc1/slots/${booked.dateTime.millisecondsSinceEpoch}',
                )
                .get())
            .exists,
        isFalse,
      );
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await runtime.app.delete();
    },
  );
}
