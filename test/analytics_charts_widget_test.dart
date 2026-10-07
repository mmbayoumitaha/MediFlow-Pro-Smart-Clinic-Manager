import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/formatters/clinic_formatters.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_analytics.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/presentation/analytics_charts.dart';
import 'package:mediflow/features/clinic/presentation/enum_labels.dart';
import 'package:mediflow/shared/widgets/shared_widgets.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9);
  Future<void> render(WidgetTester tester, ClinicSnapshot snapshot) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsCharts(analytics: ClinicAnalytics(snapshot, now)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('charts show source totals and change after snapshot updates', (
    tester,
  ) async {
    final snapshot = ClinicSnapshot(
      invoices: DemoFixtures.generateInvoices(at: now),
      appointments: DemoFixtures.generateAppointments(at: now),
    );
    await render(tester, snapshot);
    final bars = tester.widget<BarChart>(find.byType(BarChart)).data;
    expect(bars.barGroups.map((b) => b.barRods.single.toY), [
      0,
      0,
      0,
      0,
      0,
      1083,
    ]);
    expect(bars.maxY, greaterThan(1083));
    final pie = tester.widget<PieChart>(find.byType(PieChart)).data;
    expect(pie.sections.fold<double>(0, (n, s) => n + s.value), 8);
    expect(find.text('Gynecology: 1'), findsOneWidget);
    await render(tester, snapshot.copyWith(invoices: [], appointments: []));
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('No paid invoices in this period'), findsOneWidget);
    expect(find.text('No appointments to chart'), findsOneWidget);
  });
  testWidgets('charts and statistic cards fit a narrow large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const StatsGrid(
                    children: [
                      StatCard(
                        title: 'Completed visit fees',
                        value: 'USD 123,456.78',
                        subtitle: 'Visit fees; not collected payments',
                        icon: Icons.payments,
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.cyan],
                        ),
                      ),
                    ],
                  ),
                  AnalyticsCharts(
                    analytics: ClinicAnalytics(ClinicSnapshot(), now),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('safe grapheme initials and the explicit currency preserve fractional values', () {
    expect(ClinicFormatters.initial('   '), '?');
    expect(ClinicFormatters.initial(null), '?');
    expect(ClinicFormatters.initial(' 👩🏽‍⚕️ Doctor'), '👩🏽‍⚕️');
    expect(ClinicFormatters.money(12.34), 'USD 12.34');
    expect(ClinicFormatters.money(double.nan), 'Unavailable');
    expect(PaymentStatus.partial.labelEn, 'Partial');
  });
}
