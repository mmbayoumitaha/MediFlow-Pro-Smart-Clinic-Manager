import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediflow/core/config/backend_configuration.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/main.dart' as app;
import 'package:mediflow/routes/app_router.dart';

Future<void> until(
  WidgetTester tester,
  bool Function() ready,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: label);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Firebase browser: trusted portals, private booking, lifecycle, billing, profile and registration',
    (tester) async {
      final requested = BackendConfiguration.fromEnvironment();
      expect(requested.useEmulators, isTrue);
      expect(requested.projectId, 'demo-mediflow');
      await app.main();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.MediFlowApp)),
      );
      final config = container.read(backendConfigurationProvider);
      expect(config.isDemo, isFalse);
      expect(config.useEmulators, isTrue);
      expect(config.projectId, 'demo-mediflow');
      await until(
        tester,
        () => !container.read(authProvider).isLoading,
        'initial Firebase session',
      );
      final router = container.read(routerProvider);
      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Demo role'), findsNothing);
      expect(find.text('Reset demo'), findsNothing);

      Future<void> readScope() => until(tester, () {
        final data = container.read(clinicViewModelProvider);
        return !data.isLoading && !data.hasError && data.valueOrNull != null;
      }, 'server-confirmed clinic scope');
      Future<void> login(String uid, UserRole role) async {
        await until(
          tester,
          () =>
              find.byType(TextFormField).evaluate().length == 2 &&
              !container.read(authProvider).isLoading,
          'login form',
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          '$uid@example.test',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'Emulator-only-password1!',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Sign In'));
        await until(
          tester,
          () => container.read(authProvider).currentUser?.id == uid,
          'trusted login for $role',
        );
        await readScope();
        await tester.pumpAndSettle();
        expect(container.read(authProvider).currentUser!.role, role);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/${role.value}',
        );
      }

      Future<void> logout() async {
        await container.read(authProvider.notifier).logout();
        await until(
          tester,
          () =>
              !container.read(authProvider).isLoading &&
              container.read(authProvider).currentUser == null,
          'logout',
        );
        await tester.pumpAndSettle();
        expect(container.read(clinicSnapshotProvider).appointments, isEmpty);
        expect(router.routeInformationProvider.value.uri.path, '/login');
      }

      await login('browser-patient', UserRole.patient);
      expect(
        container.read(appointmentsProvider).map((a) => a.id),
        unorderedEquals(['browser-past', 'browser-completed']),
      );
      expect(container.read(patientsProvider).single.id, 'browser-patient');
      final runtime = container.read(firebaseRuntimeProvider);
      await expectLater(
        runtime.firestore
            .collection('appointments')
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await expectLater(
        runtime.firestore.doc('users/browser-patient').update({
          'role': 'admin',
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      router.go('/admin/billing');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/patient');
      router.go('/patient/book?doctorId=browser-doc1');
      await tester.pumpAndSettle();
      final date = container.read(bookingDateOptionsProvider).first;
      await tap(tester, find.byKey(ValueKey(date)));
      await until(
        tester,
        () => find.byType(ChoiceChip).evaluate().isNotEmpty,
        'server availability',
      );
      await tap(tester, find.widgetWithText(ChoiceChip, '09:00 AM'));
      await tap(tester, find.widgetWithText(FilledButton, 'Confirm Booking'));
      await until(
        tester,
        () =>
            router.routeInformationProvider.value.uri.path ==
            '/patient/appointments',
        'booking acknowledgement and navigation',
      );
      await until(
        tester,
        () => container.read(appointmentsProvider).length == 3,
        'booking stream',
      );
      final booked = container
          .read(appointmentsProvider)
          .singleWhere((a) => !a.id.startsWith('browser-'));
      expect(booked.dateTime.hour, 9);
      expect(booked.dateTime.timeZoneName, anyOf('EEST', 'EET'));
      expect(booked.patientId, 'browser-patient');
      expect(booked.status, AppointmentStatus.pending);
      expect(booked.fee, 80.25);
      debugPrint(
        'Verified patient scope, SDK rule denials and server slot booking.',
      );

      router.go('/patient/profile');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Edit Profile'));
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Updated Browser Patient',
      );
      await tap(tester, find.byKey(const ValueKey('profile-save')));
      await until(
        tester,
        () =>
            container.read(authProvider).currentUser?.fullName ==
            'Updated Browser Patient',
        'trusted profile event',
      );
      // Recreate the application auth adapter while the SDK keeps its session;
      // it must restore the updated role/profile through a server read.
      container.invalidate(authRepositoryProvider);
      await tester.pump();
      await until(
        tester,
        () =>
            container.read(authProvider).currentUser?.fullName ==
            'Updated Browser Patient',
        'SDK session restoration after adapter recreation',
      );
      await readScope();
      expect(runtime.auth.currentUser?.uid, 'browser-patient');
      expect(container.read(appointmentsProvider), hasLength(3));
      await logout();

      await login('browser-doctor', UserRole.doctor);
      expect(container.read(doctorsProvider).single.id, 'browser-doc1');
      expect(
        container.read(patientsProvider).single.fullName,
        'Updated Browser Patient',
      );
      expect(container.read(invoicesProvider), isEmpty);
      expect(
        container
            .read(appointmentsProvider)
            .every((a) => a.doctorId == 'browser-doc1'),
        isTrue,
      );
      router.go('/doctor/schedule');
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(ValueKey('appointment-${booked.id}-confirmed')),
      );
      await tap(tester, find.text('Apply change'));
      await until(
        tester,
        () =>
            container
                .read(appointmentsProvider)
                .singleWhere((a) => a.id == booked.id)
                .status ==
            AppointmentStatus.confirmed,
        'confirmed visit',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('appointment-browser-past-in_progress')),
      );
      await tap(tester, find.text('Apply change'));
      await until(
        tester,
        () =>
            container
                .read(appointmentsProvider)
                .singleWhere((a) => a.id == 'browser-past')
                .status ==
            AppointmentStatus.inProgress,
        'started visit',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('appointment-browser-past-completed')),
      );
      await tap(tester, find.text('Apply change'));
      await until(
        tester,
        () =>
            container
                .read(appointmentsProvider)
                .singleWhere((a) => a.id == 'browser-past')
                .status ==
            AppointmentStatus.completed,
        'completed visit',
      );
      debugPrint(
        'Verified doctor scope, projected contacts and callable lifecycle.',
      );
      await logout();

      await login('browser-admin', UserRole.admin);
      expect(container.read(appointmentsProvider), hasLength(4));
      router.go('/admin/billing');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('issue-browser-completed')));
      await tap(tester, find.widgetWithText(FilledButton, 'Issue invoice'));
      await until(
        tester,
        () => container.read(invoicesProvider).length == 1,
        'issued invoice stream',
      );
      final invoiceId = container.read(invoicesProvider).single.id;
      await tap(tester, find.byKey(ValueKey('settle-$invoiceId')));
      await tap(tester, find.text('Record settlement'));
      await until(
        tester,
        () =>
            container.read(invoicesProvider).single.paymentStatus ==
                PaymentStatus.paid &&
            container
                    .read(appointmentsProvider)
                    .singleWhere((a) => a.id == 'browser-completed')
                    .paymentStatus ==
                PaymentStatus.paid,
        'settled invoice stream',
      );
      expect(container.read(clinicAnalyticsProvider).paidInvoiceTotal, 80.25);
      expect(
        container
            .read(appointmentsProvider)
            .singleWhere((a) => a.id == 'browser-completed')
            .paymentStatus,
        PaymentStatus.paid,
      );
      await tap(tester, find.byKey(ValueKey('refund-$invoiceId')));
      await tap(tester, find.text('Record refund'));
      await until(
        tester,
        () =>
            container.read(invoicesProvider).single.paymentStatus ==
            PaymentStatus.refunded,
        'refunded invoice stream',
      );
      expect(container.read(clinicAnalyticsProvider).paidInvoiceTotal, 0);
      debugPrint(
        'Verified admin invoices, atomic payment links and analytics.',
      );
      await logout();

      router.go('/register');
      await tester.pumpAndSettle();
      final forms = find.byType(TextFormField);
      await tester.enterText(forms.at(0), 'New Browser Patient');
      await tester.enterText(forms.at(1), 'browser-registration@example.test');
      await tester.enterText(forms.at(2), '+201000000002');
      await tester.enterText(forms.at(3), 'Emulator-only-password1!');
      await tester.enterText(forms.at(4), 'Emulator-only-password1!');
      await tap(tester, find.widgetWithText(FilledButton, 'Create Account'));
      await until(
        tester,
        () =>
            container.read(authProvider).currentUser?.email ==
            'browser-registration@example.test',
        'patient Auth enrollment and trusted callable profile',
      );
      await readScope();
      await tester.pumpAndSettle();
      expect(container.read(authProvider).currentUser!.role, UserRole.patient);
      expect(container.read(appointmentsProvider), isEmpty);
      expect(container.read(invoicesProvider), isEmpty);
      await logout();
      await tester.enterText(
        find.byType(TextFormField).first,
        'browser-doctor@example.test',
      );
      await tap(tester, find.text('Reset password'));
      await until(
        tester,
        () => container.read(passwordRecoveryProvider).requested,
        'emulator-only password recovery',
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'Verified patient-only SDK registration and emulator password recovery.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await runtime.app.delete();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
