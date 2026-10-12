import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  const formats = [
    (Size(320, 568), 1.0),
    (Size(375, 812), 2.0),
    (Size(768, 1024), 1.5),
    (Size(1280, 800), 1.5),
  ];
  const portals = {
    UserRole.patient: [
      '/patient',
      '/patient/doctors',
      '/patient/appointments',
      '/patient/profile',
      '/patient/prescriptions',
      '/patient/book?doctorId=doc-001',
    ],
    UserRole.doctor: [
      '/doctor',
      '/doctor/schedule',
      '/doctor/patients',
      '/doctor/profile',
    ],
    UserRole.admin: [
      '/admin',
      '/admin/appointments',
      '/admin/doctors',
      '/admin/patients',
      '/admin/billing',
    ],
  };
  for (final (size, scale) in formats) {
    for (final entry in portals.entries) {
      for (final path in entry.value) {
        testWidgets('$path at ${size.width.toInt()}px and ${scale}x text', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final container = ProviderContainer(
            overrides: [
              clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 9)),
            ],
          );
          addTearDown(container.dispose);
          await container
              .read(authProvider.notifier)
              .login('demo@mediflow.com', 'dummy123', entry.key);
          container.read(routerProvider).go(path);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MediFlowApp(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Demo mode'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.pump();
        });
      }
    }
    for (final path in ['/onboarding', '/login', '/register']) {
      testWidgets('$path at ${size.width.toInt()}px and ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(routerProvider).go(path);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MediFlowApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      });
    }
  }
}
