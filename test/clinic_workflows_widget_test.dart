import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/presentation/clinic_data_gate.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  const portalPaths = [
    '/patient',
    '/patient/book',
    '/patient/prescriptions',
    '/patient/doctors',
    '/patient/appointments',
    '/patient/profile',
    '/doctor',
    '/doctor/schedule',
    '/doctor/patients',
    '/doctor/profile',
    '/admin',
    '/admin/doctors',
    '/admin/patients',
    '/admin/billing',
  ];

  for (final role in UserRole.values) {
    testWidgets('${role.value} signs in and out using the same owned router', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediFlowApp(),
        ),
      );
      router.go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text(role.labelEn));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider), same(router));
      expect(router.routeInformationProvider.value.uri.path, '/${role.value}');
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(
        find.textContaining('Offline demo · Fictional data'),
        findsOneWidget,
      );
      expect(
        container.read(doctorsProvider),
        hasLength(role == UserRole.doctor ? 1 : 6),
      );
      for (final path in portalPaths) {
        router.go('$path?source=direct-link');
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          path.startsWith('/${role.value}/') || path == '/${role.value}'
              ? path
              : '/${role.value}',
          reason: '${role.value}: $path',
        );
        expect(tester.takeException(), isNull);
      }
      for (final path in ['/', '/login', '/register', '/onboarding']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/${role.value}',
        );
      }
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
      for (final path in portalPaths) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/login');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('booking selections persist through the injected repository', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(() => 'widget-booking'),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login('demo@mediflow.com', 'password123', UserRole.patient);
    final router = container.read(routerProvider);
    router.go('/patient/book');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hassan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 6))));
    await tester.pumpAndSettle();
    final time = find.widgetWithText(ChoiceChip, '01:30 PM');
    await tester.ensureVisible(time);
    await tester.tap(time);
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Confirm Booking');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final snapshot = await container.read(clinicRepositoryProvider).load();
    final booked = snapshot.appointments.singleWhere(
      (a) => a.id == 'widget-booking',
    );
    expect(booked.dateTime, DateTime(2026, 10, 6, 13, 30));
    expect(booked.patientId, 'pat-001');
    expect(booked.doctorId, 'doc-001');
    expect(container.read(appointmentsProvider), hasLength(3));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/patient/appointments',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('repository loading and failures render with a working retry', (
    tester,
  ) async {
    final repository = MockClinicRepository();
    final stream = StreamController<ClinicSnapshot>.broadcast(sync: true);
    when(repository.watch()).thenAnswer((_) => stream.stream);
    when(repository.load()).thenAnswer((_) async => ClinicSnapshot());
    final container = ProviderContainer(
      overrides: [clinicRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await stream.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ClinicDataGate(child: Text('Ready'))),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    stream.addError(Exception('internal backend detail'), StackTrace.current);
    await tester.pump();
    expect(
      find.text('Clinic data could not be loaded. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    verify(repository.load()).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
