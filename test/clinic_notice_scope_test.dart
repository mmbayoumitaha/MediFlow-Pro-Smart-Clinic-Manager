import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  testWidgets(
    'portal feedback clears on logout and never blocks the next account doctor creation',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .login('demo@mediflow.com', 'dummy123', UserRole.doctor);
      final router = container.read(routerProvider);
      router.go('/doctor/schedule');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(tester.element(find.text('My Schedule')))
          .showSnackBar(
            const SnackBar(
              content: Text('Previous doctor feedback'),
              duration: Duration(minutes: 1),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Previous doctor feedback'), findsOneWidget);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      await container
          .read(authProvider.notifier)
          .login('demo@mediflow.com', 'dummy123', UserRole.admin);
      router.go('/admin/doctors');
      await tester.pumpAndSettle();
      expect(find.text('Previous doctor feedback'), findsNothing);
      ScaffoldMessenger.of(tester.element(find.text('Manage Doctors')))
          .showSnackBar(
            const SnackBar(content: Text('Current administrator feedback')),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Doctor'));
      await tester.pumpAndSettle();
      expect(find.text('Add demo doctor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
