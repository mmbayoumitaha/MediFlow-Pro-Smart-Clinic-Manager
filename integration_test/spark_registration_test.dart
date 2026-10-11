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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Spark: register, restore, logout and re-enroll with Auth/Firestore only',
    (tester) async {
      final config = BackendConfiguration.fromEnvironment();
      expect(config.projectId, 'demo-mediflow');
      expect(config.useEmulators, isTrue);
      await app.main();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.MediFlowApp)),
      );
      Future<void> until(bool Function() ready, String label) async {
        final deadline = DateTime.now().add(const Duration(seconds: 35));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(
          ready(),
          isTrue,
          reason: '$label: ${container.read(authProvider).error}',
        );
      }

      await until(
        () => !container.read(authProvider).isLoading,
        'initial session',
      );
      container.read(routerProvider).go('/register');
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(5));
      final email =
          'spark-${DateTime.now().microsecondsSinceEpoch}@example.test';
      for (final entry in [
        'Spark Patient',
        email,
        '+201000000000',
        'Emulator-only-password1!',
        'Emulator-only-password1!',
      ].indexed) {
        await tester.enterText(fields.at(entry.$1), entry.$2);
      }
      final button = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await until(
        () => container.read(authProvider).currentUser != null,
        'rules-protected enrollment',
      );
      final runtime = container.read(firebaseRuntimeProvider);
      final uid = container.read(authProvider).currentUser!.id;
      expect(container.read(authProvider).currentUser!.role, UserRole.patient);
      final first = await runtime.firestore
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server));
      expect(first.data()!['createdAt'], isA<Timestamp>());
      expect(
        (await runtime.firestore.doc('accountEmails/$email').get())
            .data()!['userId'],
        uid,
      );
      await expectLater(
        runtime.firestore.doc('users/$uid').update({'role': 'admin'}),
        throwsA(isA<FirebaseException>()),
      );
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login(email, 'Emulator-only-password1!', UserRole.admin);
      await until(
        () => container.read(authProvider).currentUser?.id == uid,
        'trusted login ignores admin input',
      );
      expect(container.read(authProvider).currentUser!.role, UserRole.patient);
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .register(
            'Changed Retry Name',
            email,
            'Emulator-only-password1!',
            '+201111111111',
            UserRole.patient,
          );
      await until(
        () => container.read(authProvider).currentUser?.id == uid,
        'same-owner enrollment retry',
      );
      final last = await runtime.firestore
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server));
      expect(last.data()!['fullName'], 'Spark Patient');
      expect(last.data()!['createdAt'], first.data()!['createdAt']);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await runtime.app.delete();
    },
  );
}
