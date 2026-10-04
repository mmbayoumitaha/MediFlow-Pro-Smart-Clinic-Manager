import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/widgets/shared_widgets.dart';

class DoctorDashboard extends ConsumerWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final allApts = ref.watch(appointmentsProvider);
    final todayApts = allApts.where((a) {
      final now = DateTime.now();
      return a.dateTime.day == now.day && a.dateTime.month == now.month && a.dateTime.year == now.year;
    }).toList();
    final pendingApts = allApts.where((a) => a.status == AppointmentStatus.pending).toList();
    final completedApts = allApts.where((a) => a.status == AppointmentStatus.completed).toList();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: AppColors.secondaryContainer,
                child: Text((user?.fullName ?? 'D')[0], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good ${_getGreeting()}!', style: theme.textTheme.bodySmall),
                Text(user?.fullName ?? 'Doctor', style: theme.textTheme.headlineSmall),
              ])),
              IconButton(onPressed: () {}, icon: const Badge(smallSize: 8, child: Icon(Icons.notifications_outlined))),
            ]),
            const SizedBox(height: 24),

            // Stats
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
              children: [
                StatCard(title: "Today's Patients", value: '${todayApts.length}', icon: Icons.people_rounded, gradient: AppColors.primaryGradient),
                StatCard(title: 'Pending', value: '${pendingApts.length}', icon: Icons.pending_actions_rounded, gradient: AppColors.secondaryGradient),
                StatCard(title: 'Completed', value: '${completedApts.length}', icon: Icons.check_circle_rounded, gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])),
                StatCard(title: 'Total Revenue', value: '\$${completedApts.fold<double>(0, (s, a) => s + a.fee).toStringAsFixed(0)}', icon: Icons.payments_rounded, gradient: AppColors.accentGradient),
              ],
            ),
            const SizedBox(height: 24),

            // Today's schedule
            const SectionHeader(title: "Today's Schedule", actionText: 'View All'),
            if (todayApts.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: EmptyState(icon: Icons.event_available_rounded, title: 'No appointments today'))
            else
              ...todayApts.map((apt) => AppointmentCard(
                doctorName: apt.patientName,
                specialty: apt.specialty.labelEn,
                dateStr: DateFormat('MMM dd').format(apt.dateTime),
                timeStr: DateFormat('hh:mm a').format(apt.dateTime),
                status: apt.status.labelEn,
                statusColor: Color(apt.status.colorValue),
              )),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Upcoming Appointments'),
            ...ref.watch(upcomingAppointmentsProvider).take(4).map((apt) => AppointmentCard(
              doctorName: apt.patientName,
              specialty: apt.specialty.labelEn,
              dateStr: DateFormat('MMM dd').format(apt.dateTime),
              timeStr: DateFormat('hh:mm a').format(apt.dateTime),
              status: apt.status.labelEn,
              statusColor: Color(apt.status.colorValue),
            )),
          ]),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
