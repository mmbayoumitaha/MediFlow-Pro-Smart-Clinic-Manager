import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/domain/profile_policy.dart';
import 'package:mediflow/main.dart' as app;
import 'package:mediflow/routes/app_router.dart';

import 'firebase_workflow_test.dart' show until, tap;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Spark staff: admin binds real Auth UID; staff edits hours and unused deletion revokes access',
    (tester) async {
      await app.main();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.MediFlowApp)),
      );
      final config = container.read(backendConfigurationProvider);
      expect(config.useEmulators, isTrue);
      expect(config.projectId, 'demo-mediflow');
      await until(
        tester,
        () => !container.read(authProvider).isLoading,
        'startup',
      );
      Future<void> login(String uid, UserRole role) async {
        await container
            .read(authProvider.notifier)
            .login('$uid@example.test', 'Emulator-only-password1!', role);
        await until(
          tester,
          () =>
              container.read(authProvider).currentUser?.id == uid &&
              container.read(clinicViewModelProvider).valueOrNull != null &&
              !container.read(clinicViewModelProvider).hasError,
          'trusted role scope',
        );
        await tester.pumpAndSettle();
        expect(container.read(authProvider).currentUser!.role, role);
      }

      final router = container.read(routerProvider);
      await login('browser-admin', UserRole.admin);
      final runtime = container.read(firebaseRuntimeProvider);
      for (final year in [2026, 2027]) {
        final calendar = await runtime.firestore
            .doc('clinicTimezones/$year')
            .get();
        expect(
          calendar.exists,
          isTrue,
          reason: 'admin initializes the missing clinic calendar',
        );
      }
      router.go('/admin/doctors');
      await tester.pumpAndSettle();
      expect(find.text('Manage Doctors'), findsOneWidget);
      expect(container.read(profileActionsProvider).isSubmitting, isFalse);
      await tap(tester, find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-account-id')),
        findsOneWidget,
        reason:
            'route=${router.routeInformationProvider.value.uri}; demo=${container.read(isDemoProvider)}; dialogs=${find.byType(AlertDialog).evaluate().length}; texts=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(" | ")}',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-account-id')),
        'browser-newstaff',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'New Clinic Doctor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-email')),
        'browser-newstaff@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-phone')),
        '+201000000004',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-fee')),
        '95.50',
      );
      await tap(tester, find.byKey(const ValueKey('profile-save')));
      await until(
        tester,
        () =>
            container.read(doctorsProvider).length == 3 &&
            find.byType(AlertDialog).evaluate().isEmpty,
        'staff binding saved',
      );
      final id = container
          .read(doctorsProvider)
          .singleWhere((d) => d.userId == 'browser-newstaff')
          .id;
      await container.read(authProvider.notifier).logout();
      await login('browser-newstaff', UserRole.doctor);
      final bound = container.read(doctorsProvider).single;
      expect(bound.id, id);
      final hold = container.listen(profileActionsProvider, (_, _) {});
      expect(
        await container
            .read(profileActionsProvider.notifier)
            .doctor(
              bound,
              DoctorInput(
                fullName: 'Updated Clinic Doctor',
                email: bound.email,
                phone: '+201000000005',
                specialty: bound.specialty,
                consultationFee: bound.consultationFee,
                experienceYears: 0,
                isAvailable: true,
                availability: const [
                  AvailabilitySlot(
                    day: DayOfWeek.monday,
                    startTime: '09:15',
                    endTime: '10:45',
                  ),
                ],
              ),
            ),
        isTrue,
        reason: container.read(profileActionsProvider).error,
      );
      await until(
        tester,
        () =>
            container.read(doctorsProvider).single.fullName ==
            'Updated Clinic Doctor',
        'staff contact stream',
      );
      expect(
        container.read(doctorsProvider).single.availability.single.startTime,
        '09:30',
      );
      expect(
        container.read(doctorsProvider).single.availability.single.endTime,
        '10:30',
      );
      hold.close();
      await container.read(authProvider.notifier).logout();
      await login('browser-admin', UserRole.admin);
      router.go('/admin/doctors');
      await tester.pumpAndSettle();
      expect(
        await container
            .read(profileActionsProvider.notifier)
            .removeDoctor(
              container.read(doctorsProvider).singleWhere((d) => d.id == id),
            ),
        isTrue,
        reason: container.read(profileActionsProvider).error,
      );
      await until(
        tester,
        () => container.read(doctorsProvider).length == 2,
        'safe staff deletion',
      );
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login(
            'browser-newstaff@example.test',
            'Emulator-only-password1!',
            UserRole.doctor,
          );
      await until(
        tester,
        () =>
            !container.read(authProvider).isLoading &&
            container.read(authProvider).error != null,
        'removed staff gets denied sign-in feedback',
      );
      expect(container.read(authProvider).currentUser, isNull);
      expect(container.read(authProvider).error, isNotNull);
      expect(container.read(clinicSnapshotProvider).doctors, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await runtime.app.delete();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
