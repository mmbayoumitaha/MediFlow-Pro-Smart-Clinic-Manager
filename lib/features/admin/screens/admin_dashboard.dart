import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

import '../../../shared/widgets/shared_widgets.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider);
    final patients = ref.watch(patientsProvider);
    final appointments = ref.watch(appointmentsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final metrics = ref.watch(clinicMetricsProvider);
    final totalRevenue = metrics.paidInvoiceRevenue;
    final pendingCount = metrics.pending.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Panel', style: theme.textTheme.bodySmall),
                        Text(
                          'Dashboard',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(themeModeProvider.notifier).state = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    title: 'Total Doctors',
                    value: '${doctors.length}',
                    icon: Icons.medical_services_rounded,
                    gradient: AppColors.primaryGradient,
                  ),
                  StatCard(
                    title: 'Total Patients',
                    value: '${patients.length}',
                    icon: Icons.people_rounded,
                    gradient: AppColors.secondaryGradient,
                  ),
                  StatCard(
                    title: 'Appointments',
                    value: '${appointments.length}',
                    icon: Icons.calendar_month_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    ),
                    subtitle: '$pendingCount pending',
                  ),
                  StatCard(
                    title: 'Revenue',
                    value: '\$${totalRevenue.toStringAsFixed(0)}',
                    icon: Icons.payments_rounded,
                    gradient: AppColors.accentGradient,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Revenue chart
              const SectionHeader(title: 'Revenue Overview'),
              Container(
                height: 220,
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                  ),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 2500,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            const months = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                v.toInt() < months.length
                                    ? months[v.toInt()]
                                    : '',
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (v, meta) => Text(
                            '\$${v.toInt()}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 500,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeBar(0, 1200, AppColors.primary),
                      _makeBar(1, 1800, AppColors.primary),
                      _makeBar(2, 1500, AppColors.primary),
                      _makeBar(3, 2100, AppColors.primary),
                      _makeBar(
                        4,
                        totalRevenue.clamp(500, 2500),
                        AppColors.primaryLight,
                      ),
                      _makeBar(5, 900, AppColors.slate300),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Specialty distribution
              const SectionHeader(title: 'Appointments by Specialty'),
              Container(
                height: 200,
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: [
                            PieChartSectionData(
                              value: 30,
                              color: AppColors.primary,
                              title: '30%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: 25,
                              color: AppColors.secondary,
                              title: '25%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: 20,
                              color: AppColors.accent,
                              title: '20%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: 15,
                              color: AppColors.success,
                              title: '15%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: 10,
                              color: AppColors.info,
                              title: '10%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              radius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Legend(color: AppColors.primary, label: 'Cardiology'),
                        _Legend(color: AppColors.secondary, label: 'Neurology'),
                        _Legend(color: AppColors.accent, label: 'Orthopedics'),
                        _Legend(color: AppColors.success, label: 'Pediatrics'),
                        _Legend(color: AppColors.info, label: 'Others'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent appointments
              const SectionHeader(title: 'Recent Activity'),
              ...appointments
                  .take(4)
                  .map(
                    (apt) => AppointmentCard(
                      doctorName: '${apt.patientName} → ${apt.doctorName}',
                      specialty: apt.specialty.labelEn,
                      dateStr: '${apt.dateTime.day}/${apt.dateTime.month}',
                      timeStr:
                          '${apt.dateTime.hour}:${apt.dateTime.minute.toString().padLeft(2, '0')}',
                      status: apt.status.labelEn,
                      statusColor: Color(apt.status.colorValue),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeBar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
