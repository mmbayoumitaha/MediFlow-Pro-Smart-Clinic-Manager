import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  for (final role in UserRole.values) {
    testWidgets('${role.value} can cancel or confirm a demo reset', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 9)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .login('demo@mediflow.com', 'dummy123', role);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Offline demo · Fictional data'),
        findsOneWidget,
      );
      final original = container.read(clinicRepositoryProvider);
      await tester.tap(find.widgetWithText(TextButton, 'Reset demo'));
      await tester.pumpAndSettle();
      expect(find.text('Reset demo?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(clinicRepositoryProvider), same(original));
      await tester.tap(find.widgetWithText(TextButton, 'Reset demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset demo'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(clinicRepositoryProvider), isNot(same(original)));
      expect(container.read(appointmentsProvider), isEmpty);
      expect(find.textContaining('no real authentication'), findsOneWidget);
      expect(container.read(routerProvider), same(router));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('demo registration, logout and known-account role are explicit', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 9)),
        idGeneratorProvider.overrideWithValue(
          () => 'registered-widget-patient',
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider)..go('/register');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Use fictional details'), findsOneWidget);
    final fields = find.byType(TextFormField);
    for (final entry in [
      (0, 'Demo Person'),
      (1, 'demo-person@example.com'),
      (2, '+201001234567'),
      (3, 'dummy123'),
      (4, 'dummy123'),
    ]) {
      await tester.ensureVisible(fields.at(entry.$1));
      await tester.enterText(fields.at(entry.$1), entry.$2);
    }
    final create = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/patient');
    expect(container.read(appointmentsProvider), isEmpty);
    // Sign out through the actual profile action, preserving demo registration.
    router.go('/patient/profile');
    await tester.pumpAndSettle();
    final logout = find.text('Logout');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.textContaining('Role selection applies'), findsOneWidget);
    await tester.tap(find.text('Admin'));
    await tester.enterText(
      find.byType(TextFormField).first,
      'demo-person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'different-dummy');
    final signIn = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/patient');
    expect(
      container.read(authProvider).currentUser!.id,
      'registered-widget-patient',
    );
    expect(container.read(authProvider).currentUser!.role, UserRole.patient);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
