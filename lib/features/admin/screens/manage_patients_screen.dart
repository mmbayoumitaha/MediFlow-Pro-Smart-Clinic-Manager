import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/formatters/clinic_formatters.dart';
import '../../clinic/presentation/profile_forms.dart';

class ManagePatientsScreen extends ConsumerWidget {
  const ManagePatientsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);
    final busy = ref.watch(profileActionsProvider).isSubmitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Patients')),
      body: patients.isEmpty
          ? const Center(child: Text('No patients yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: patients
                  .map(
                    (patient) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            ClinicFormatters.initial(patient.fullName),
                          ),
                        ),
                        title: Text(patient.fullName),
                        subtitle: Text(
                          '${patient.email}\n${patient.phone} • ${patient.isActive ? 'Active' : 'Inactive'}',
                        ),
                        isThreeLine: true,
                        onTap: busy
                            ? null
                            : () => editPatientProfile(context, patient),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('patient-menu-${patient.id}'),
                          enabled: !busy,
                          onSelected: (action) {
                            if (action == 'edit') {
                              editPatientProfile(context, patient);
                            } else {
                              removeProfile(context, ref, patient: patient);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete unused profile'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
