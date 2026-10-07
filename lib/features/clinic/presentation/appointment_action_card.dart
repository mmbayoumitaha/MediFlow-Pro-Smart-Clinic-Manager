import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_dependencies.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../domain/app_enums.dart';
import '../domain/appointment_lifecycle.dart';
import '../domain/entities.dart';

class AppointmentActionCard extends ConsumerWidget {
  final Appointment appointment;
  final String title;
  const AppointmentActionCard({
    super.key,
    required this.appointment,
    required this.title,
  });

  static String label(AppointmentStatus status) => switch (status) {
    AppointmentStatus.confirmed => 'Confirm',
    AppointmentStatus.inProgress => 'Start visit',
    AppointmentStatus.completed => 'Complete',
    AppointmentStatus.cancelled => 'Cancel appointment',
    AppointmentStatus.noShow => 'Mark no-show',
    AppointmentStatus.pending => 'Pending',
  };

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    AppointmentStatus target,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${label(target)}?'),
        content: Text(
          'Change this demo appointment to ${target.labelEn}? '
          'Payments and invoices are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep appointment'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply change'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final updated = await ref
        .read(appointmentActionsProvider.notifier)
        .change(appointment, target);
    if (!context.mounted) return;
    final error = ref.read(appointmentActionsProvider).error;
    if (!updated) {
      await ref.read(clinicViewModelProvider.notifier).refresh();
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? 'Appointment updated: ${target.labelEn}'
              : error ?? 'An appointment update is already in progress.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = AppointmentLifecycle.targets(
      ref.watch(clinicSnapshotProvider),
      ref.watch(authProvider).currentUser,
      appointment,
      ref.watch(clinicTimeProvider),
    );
    final action = ref.watch(appointmentActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppointmentCard(
          doctorName: title,
          specialty: appointment.specialty.labelEn,
          dateStr: DateFormat('MMM dd, yyyy').format(appointment.dateTime),
          timeStr: DateFormat('hh:mm a').format(appointment.dateTime),
          status: appointment.status.labelEn,
          statusColor: Color(appointment.status.colorValue),
        ),
        if (targets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: targets
                  .map(
                    (target) => OutlinedButton(
                      key: ValueKey(
                        'appointment-${appointment.id}-${target.value}',
                      ),
                      onPressed: action.busyId != null
                          ? null
                          : () => _change(context, ref, target),
                      child: Text(
                        action.busyId == appointment.id
                            ? 'Updating...'
                            : label(target),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
