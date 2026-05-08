import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingAppointmentsProvider);
    final past = ref.watch(pastAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')]),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(upcoming, 'No upcoming appointments'),
          _buildList(past, 'No past appointments'),
        ],
      ),
    );
  }

  Widget _buildList(List apts, String emptyMsg) {
    if (apts.isEmpty) return EmptyState(icon: Icons.event_busy_rounded, title: emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: apts.length,
      itemBuilder: (ctx, i) {
        final apt = apts[i];
        return AppointmentCard(
          doctorName: apt.doctorName,
          specialty: apt.specialty.labelEn,
          dateStr: DateFormat('MMM dd, yyyy').format(apt.dateTime),
          timeStr: DateFormat('hh:mm a').format(apt.dateTime),
          status: apt.status.labelEn,
          statusColor: Color(apt.status.colorValue),
        );
      },
    );
  }
}
