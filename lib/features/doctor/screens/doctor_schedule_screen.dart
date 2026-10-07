import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../clinic/presentation/appointment_action_card.dart';

class DoctorScheduleScreen extends ConsumerWidget {
  const DoctorScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apts = ref.watch(sortedAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: apts.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No Appointments',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: apts.length,
              itemBuilder: (ctx, i) {
                final apt = apts[i];
                return AppointmentActionCard(
                  appointment: apt,
                  title: apt.patientName,
                );
              },
            ),
    );
  }
}
