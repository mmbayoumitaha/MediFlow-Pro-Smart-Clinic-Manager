import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class DoctorScheduleScreen extends ConsumerWidget {
  const DoctorScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apts = ref.watch(appointmentsProvider);
    apts.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: apts.isEmpty
          ? const EmptyState(icon: Icons.calendar_today_outlined, title: 'No Appointments')
          : ListView.builder(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: apts.length,
              itemBuilder: (ctx, i) {
                final apt = apts[i];
                return AppointmentCard(
                  doctorName: apt.patientName,
                  specialty: apt.specialty.labelEn,
                  dateStr: DateFormat('MMM dd, yyyy').format(apt.dateTime),
                  timeStr: DateFormat('hh:mm a').format(apt.dateTime),
                  status: apt.status.labelEn,
                  statusColor: Color(apt.status.colorValue),
                );
              },
            ),
    );
  }
}
