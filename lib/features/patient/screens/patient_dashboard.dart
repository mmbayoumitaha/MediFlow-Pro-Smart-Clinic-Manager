import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class PatientDashboard extends ConsumerWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final upcoming = ref.watch(upcomingAppointmentsProvider);
    final theme = Theme.of(context);

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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hello 👋', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.slate500)),
                      Text(user?.fullName ?? 'Patient', style: theme.textTheme.headlineMedium),
                    ]),
                  ),
                  IconButton(onPressed: () {}, icon: Badge(smallSize: 8, child: const Icon(Icons.notifications_outlined))),
                  const SizedBox(width: 4),
                  CircleAvatar(radius: 22, backgroundColor: AppColors.primaryContainer, child: Text((user?.fullName ?? 'P')[0], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary))),
                ],
              ),
              const SizedBox(height: 24),

              // Quick actions
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppSizes.radiusXl)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Need a Consultation?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Book an appointment now', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/patient/book'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(140, 40)),
                      child: const Text('Book Now'),
                    ),
                  ])),
                  const Icon(Icons.medical_services_rounded, size: 64, color: Colors.white24),
                ]),
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(children: [
                Expanded(child: _MiniStat(icon: Icons.calendar_today_rounded, label: 'Upcoming', value: '${upcoming.length}', color: AppColors.info)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStat(icon: Icons.check_circle_outline, label: 'Completed', value: '${ref.watch(pastAppointmentsProvider).length}', color: AppColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStat(icon: Icons.description_outlined, label: 'Prescriptions', value: '${ref.watch(prescriptionsProvider).length}', color: AppColors.secondary)),
              ]),
              const SizedBox(height: 24),

              // Upcoming appointments
              SectionHeader(title: 'Upcoming Appointments', actionText: 'View All', onAction: () => context.go('/patient/appointments')),
              if (upcoming.isEmpty)
                const EmptyState(icon: Icons.calendar_today_outlined, title: 'No Upcoming Appointments')
              else
                ...upcoming.take(3).map((apt) => AppointmentCard(
                  doctorName: apt.doctorName,
                  specialty: apt.specialty.labelEn,
                  dateStr: DateFormat('MMM dd').format(apt.dateTime),
                  timeStr: DateFormat('hh:mm a').format(apt.dateTime),
                  status: apt.status.labelEn,
                  statusColor: Color(apt.status.colorValue),
                )),
              const SizedBox(height: 24),

              // Quick links
              SectionHeader(title: 'Quick Actions'),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.8,
                children: [
                  _QuickAction(icon: Icons.search_rounded, label: 'Find Doctor', color: AppColors.primary, onTap: () => context.go('/patient/doctors')),
                  _QuickAction(icon: Icons.receipt_long_outlined, label: 'Prescriptions', color: AppColors.secondary, onTap: () => context.go('/patient/prescriptions')),
                  _QuickAction(icon: Icons.folder_outlined, label: 'Medical Records', color: AppColors.accent, onTap: () {}),
                  _QuickAction(icon: Icons.settings_outlined, label: 'Settings', color: AppColors.slate600, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: BorderRadius.circular(AppSizes.radiusMd), border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: BorderRadius.circular(AppSizes.radiusLg), border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
