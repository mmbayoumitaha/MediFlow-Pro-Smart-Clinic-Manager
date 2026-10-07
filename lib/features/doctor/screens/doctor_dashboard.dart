import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_dependencies.dart';
import '../../../core/formatters/clinic_formatters.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

import '../../../shared/widgets/shared_widgets.dart';

class DoctorDashboard extends ConsumerWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final metrics = ref.watch(clinicMetricsProvider);
    final todayApts = metrics.today;
    final pendingApts = metrics.pending;
    final completedApts = metrics.completed;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondaryContainer,
                    child: Text(
                      ClinicFormatters.initial(user?.fullName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_getGreeting(ref.watch(clinicTimeProvider))}!',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          user?.fullName ?? 'Doctor',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats
              StatsGrid(
                children: [
                  StatCard(
                    title: "Today's appointments",
                    value: '${todayApts.length}',
                    icon: Icons.people_rounded,
                    gradient: AppColors.primaryGradient,
                  ),
                  StatCard(
                    title: 'Pending',
                    value: '${pendingApts.length}',
                    icon: Icons.pending_actions_rounded,
                    gradient: AppColors.secondaryGradient,
                  ),
                  StatCard(
                    title: 'Completed',
                    value: '${completedApts.length}',
                    icon: Icons.check_circle_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    ),
                  ),
                  StatCard(
                    title: 'Completed visit fees',
                    value: ClinicFormatters.money(
                      metrics.completedAppointmentFees,
                    ),
                    subtitle: 'Visit fees; not collected payments',
                    icon: Icons.payments_rounded,
                    gradient: AppColors.accentGradient,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Today's schedule
              SectionHeader(
                title: "Today's Schedule",
                actionText: 'View All',
                onAction: () => context.go('/doctor/schedule'),
              ),
              if (todayApts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'No appointments today',
                  ),
                )
              else
                ...todayApts.map(
                  (apt) => AppointmentCard(
                    doctorName: apt.patientName,
                    specialty: apt.specialty.labelEn,
                    dateStr: DateFormat('MMM dd').format(apt.dateTime),
                    timeStr: DateFormat('hh:mm a').format(apt.dateTime),
                    status: apt.status.labelEn,
                    statusColor: Color(apt.status.colorValue),
                  ),
                ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Upcoming Appointments'),
              ...ref
                  .watch(upcomingAppointmentsProvider)
                  .take(4)
                  .map(
                    (apt) => AppointmentCard(
                      doctorName: apt.patientName,
                      specialty: apt.specialty.labelEn,
                      dateStr: DateFormat('MMM dd').format(apt.dateTime),
                      timeStr: DateFormat('hh:mm a').format(apt.dateTime),
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

  String _getGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
