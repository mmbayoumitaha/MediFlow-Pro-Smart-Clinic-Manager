import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  Future<ProviderContainer> setup(
    WidgetTester tester,
    UserRole role,
    String path,
  ) async {
    var ids = 0;
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(() => 'profile-new-${++ids}'),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login('demo@mediflow.com', 'dummy123', role);
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

  Future<void> finish(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('profile-save')));

  testWidgets(
    'patient profile rejects whitespace and updates the running identity and re-login',
    (tester) async {
      final container = await setup(
        tester,
        UserRole.patient,
        '/patient/profile',
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).supportedLocales,
        [const Locale('en')],
      );
      await tap(tester, find.text('Edit Profile'));
      await field(tester, 'profile-name', '   ');
      await save(tester);
      expect(
        find.text('Enter a full name and a valid phone number.'),
        findsOneWidget,
      );
      await field(tester, 'profile-name', '  Updated Patient Name  ');
      await field(tester, 'profile-address', '');
      await save(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Updated Patient Name'), findsOneWidget);
      expect(container.read(authProvider).currentUser!.address, isNull);
      final repo = container.read(clinicRepositoryProvider);
      expect(
        (await repo.load()).appointments.first.patientName,
        'Mariam Saeed',
      );
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login('mariam@email.com', 'dummy123', UserRole.doctor);
      expect(
        container.read(authProvider).currentUser!.fullName,
        'Updated Patient Name',
      );
      expect(tester.takeException(), isNull);
      await finish(tester, container);
    },
  );
  testWidgets(
    'admin adds doctor, enables a working period, and safely confirms deletion',
    (tester) async {
      final container = await setup(tester, UserRole.admin, '/admin/doctors');
      await tap(tester, find.text('Add Doctor'));
      await field(tester, 'profile-name', 'New Demo Doctor');
      await field(tester, 'profile-email', 'new@clinic.com');
      await field(tester, 'profile-phone', '+201111222333');
      await field(tester, 'profile-fee', '85.50');
      await save(tester);
      final repo = container.read(clinicRepositoryProvider);
      var doctor = (await repo.load()).doctors.last;
      expect(doctor.fullName, 'New Demo Doctor');
      expect(doctor.isAvailable, isFalse);
      await tap(tester, find.text('New Demo Doctor'));
      await tap(tester, find.byKey(const ValueKey('profile-add-period')));
      await tap(tester, find.byKey(const ValueKey('profile-booking')));
      await save(tester);
      doctor = (await repo.load()).doctors.last;
      expect(doctor.isAvailable, isTrue);
      expect(doctor.availability.single.day, DayOfWeek.monday);
      await tap(tester, find.byKey(ValueKey('doctor-menu-${doctor.id}')));
      await tap(tester, find.text('Delete unused profile'));
      await tap(tester, find.text('Keep profile'));
      expect((await repo.load()).doctors, hasLength(7));
      await tap(tester, find.byKey(ValueKey('doctor-menu-${doctor.id}')));
      await tap(tester, find.text('Delete unused profile'));
      await tap(tester, find.text('Delete profile'));
      expect((await repo.load()).doctors, hasLength(6));
      expect(tester.takeException(), isNull);
      await finish(tester, container);
    },
  );
  testWidgets(
    'linked patient deletion is blocked and admin deactivation denies later login',
    (tester) async {
      final container = await setup(tester, UserRole.admin, '/admin/patients');
      await tap(tester, find.byKey(const ValueKey('patient-menu-pat-001')));
      await tap(tester, find.text('Delete unused profile'));
      await tap(tester, find.text('Delete profile'));
      expect(
        (await container.read(clinicRepositoryProvider).load()).patients,
        hasLength(5),
      );
      expect(
        find.text(
          'This patient has clinic records. Deactivate the account instead of deleting it.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Mariam Saeed'));
      await tap(tester, find.text('Account active'));
      await save(tester);
      final auth = container.read(authProvider.notifier);
      await auth.logout();
      await auth.login('mariam@email.com', 'dummy123', UserRole.patient);
      await tester.pumpAndSettle();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(tester.takeException(), isNull);
      await finish(tester, container);
    },
  );
  testWidgets(
    'doctor can disable own booking availability and profile header updates',
    (tester) async {
      final container = await setup(tester, UserRole.doctor, '/doctor/profile');
      await tap(tester, find.text('Availability'));
      await field(tester, 'profile-name', 'Updated Demo Doctor');
      await tap(tester, find.byKey(const ValueKey('profile-booking')));
      await save(tester);
      expect(find.text('Updated Demo Doctor'), findsOneWidget);
      final updated =
          (await container.read(clinicRepositoryProvider).load()).doctors.first;
      expect(updated.isAvailable, isFalse);
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login('demo@mediflow.com', 'dummy123', UserRole.patient);
      await tester.pumpAndSettle();
      expect(
        container.read(
          bookingSlotsProvider((
            doctorId: updated.id,
            date: DateTime(2026, 10, 6),
          )),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await finish(tester, container);
    },
  );
}
