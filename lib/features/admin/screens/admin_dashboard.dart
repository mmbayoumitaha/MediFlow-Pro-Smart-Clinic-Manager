import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

import '../../../shared/widgets/shared_widgets.dart';
import '../../../core/formatters/clinic_formatters.dart';
import '../../clinic/presentation/analytics_charts.dart';

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
    final analytics = ref.watch(clinicAnalyticsProvider);
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
              StatsGrid(
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
                    title: 'Paid invoices',
                    value: ClinicFormatters.money(analytics.paidInvoiceTotal),
                    subtitle: 'All time • fully paid only',
                    icon: Icons.payments_rounded,
                    gradient: AppColors.accentGradient,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              AnalyticsCharts(analytics: analytics),
              const SizedBox(height: 24),

              // Recent appointments
              SectionHeader(
                title: 'Recent appointment changes',
                actionText: 'View All',
                onAction: () => context.go('/admin/appointments'),
              ),
              ...analytics.recentChanges.map(
                (apt) => AppointmentCard(
                  onTap: () => context.go('/admin/appointments'),
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
}
