import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../clinic/presentation/appointment_action_card.dart';

class AdminAppointmentsScreen extends ConsumerWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(sortedAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Appointments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: visits.isEmpty
          ? const EmptyState(icon: Icons.event_busy, title: 'No Appointments')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];
                return AppointmentActionCard(
                  appointment: visit,
                  title: '${visit.patientName} → ${visit.doctorName}',
                );
              },
            ),
    );
  }
}
