import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('startup reaches sign-in in ${mode.name} mode', (tester) async {
      final container = ProviderContainer(
        overrides: [themeModeProvider.overrideWith((ref) => mode)],
      );
      final router = container.read(routerProvider);
      addTearDown(() {
        router.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediFlowApp(),
        ),
      );

      expect(find.text('MediFlow Pro'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The splash has an indeterminate spinner: don't settle until it leaves.
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('MediFlow Pro'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Book Appointments'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        Theme.of(tester.element(find.text('Welcome Back'))).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('disposing the splash cancels pending navigation', (
    tester,
  ) async {
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediFlowApp(),
      ),
    );
    expect(find.text('MediFlow Pro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // testWidgets also verifies that no timers remain pending at teardown.
    expect(router.routeInformationProvider.value.uri.path, '/');
  });
}
