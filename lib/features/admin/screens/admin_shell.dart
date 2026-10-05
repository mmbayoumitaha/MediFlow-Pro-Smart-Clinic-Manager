import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../clinic/presentation/clinic_data_gate.dart';

class AdminShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AdminShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClinicDataGate(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Billing',
          ),
        ],
      ),
    );
  }
}
