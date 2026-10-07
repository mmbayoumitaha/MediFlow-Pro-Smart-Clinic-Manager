import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/formatters/clinic_formatters.dart';
import '../domain/clinic_analytics.dart';
import 'enum_labels.dart';

class AnalyticsCharts extends StatelessWidget {
  final ClinicAnalytics analytics;
  const AnalyticsCharts({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final largest = analytics.months.fold<double>(
      0,
      (v, m) => math.max(v, m.total),
    );
    final interval = largest == 0
        ? 1.0
        : math.pow(10, (math.log(largest / 4) / math.ln10).floor()).toDouble();
    final step = largest == 0
        ? 1.0
        : (largest / 4 / interval).ceil() * interval;
    final maxY = largest == 0 ? 4.0 : (largest / step).ceil() * step + step;
    final theme = Theme.of(context);
    final totalVisits = analytics.specialties.fold<int>(
      0,
      (n, s) => n + s.count,
    );
    Color color(int index) =>
        HSVColor.fromAHSV(1, (index * 137.5) % 360, .65, .7).toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paid invoices by month (USD)', style: theme.textTheme.titleLarge),
        Text(
          'Last six months: ${ClinicFormatters.money(analytics.periodTotal)}. Fully paid invoices only; refunds and partial payments excluded.',
          style: theme.textTheme.bodySmall,
        ),
        if (analytics.excludedPaidInvoices > 0)
          Text(
            '${analytics.excludedPaidInvoices} paid invoice(s) excluded because their amount or payment date is invalid.',
            style: theme.textTheme.bodySmall,
          ),
        if (largest == 0)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No paid invoices in this period'),
          )
        else
          SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, index, rod, rodIndex) =>
                          BarTooltipItem(
                            '${DateFormat('MMM yyyy').format(analytics.months[group.x].month)}\n${ClinicFormatters.money(rod.toY)}',
                            const TextStyle(color: Colors.white),
                          ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: step,
                        getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact(locale: 'en').format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          return index < 0 || index >= analytics.months.length
                              ? const SizedBox.shrink()
                              : Text(
                                  DateFormat('MMM\nyy')
                                      .format(analytics.months[index].month),
                                  style: theme.textTheme.labelSmall,
                                );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    analytics.months.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: analytics.months[i].total,
                          color: theme.colorScheme.primary,
                          width: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                duration: Duration.zero,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Appointments by specialty', style: theme.textTheme.titleLarge),
        Text(
          'All recorded appointments, including cancelled and no-show visits ($totalVisits total).',
          style: theme.textTheme.bodySmall,
        ),
        if (totalVisits == 0)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No appointments to chart'),
          )
        else ...[
          SizedBox(
            height: 210,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: List.generate(analytics.specialties.length, (i) {
                  final s = analytics.specialties[i];
                  return PieChartSectionData(
                    value: s.count.toDouble(),
                    color: color(s.specialty.index),
                    title: '${(s.count * 100 / totalVisits).round()}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ),
              duration: Duration.zero,
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: analytics.specialties
                .map(
                  (s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: color(s.specialty.index),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.specialty.labelEn}: ${s.count}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
