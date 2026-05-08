import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/main.dart';

void main() {
  testWidgets('MediFlow Pro smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediFlowApp()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // Verify the splash screen shows the app name
    expect(find.text('MediFlow Pro'), findsOneWidget);
  });
}
