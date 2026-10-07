import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../clinic/domain/entities.dart';
import '../../clinic/presentation/appointment_action_card.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingAppointmentsProvider);
    final past = ref.watch(pastAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(upcoming, 'No upcoming appointments'),
          _buildList(past, 'No appointment history'),
        ],
      ),
    );
  }

  Widget _buildList(List<Appointment> apts, String emptyMsg) {
    if (apts.isEmpty) {
      return EmptyState(icon: Icons.event_busy_rounded, title: emptyMsg);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: apts.length,
      itemBuilder: (ctx, i) {
        final apt = apts[i];
        return AppointmentActionCard(appointment: apt, title: apt.doctorName);
      },
    );
  }
}
