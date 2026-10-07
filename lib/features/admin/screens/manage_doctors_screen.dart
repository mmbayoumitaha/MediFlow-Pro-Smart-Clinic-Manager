import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/formatters/clinic_formatters.dart';
import '../../clinic/presentation/profile_forms.dart';

class ManageDoctorsScreen extends ConsumerWidget {
  const ManageDoctorsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider);
    final busy = ref.watch(profileActionsProvider).isSubmitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Doctors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => editDoctorProfile(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
      ),
      body: doctors.isEmpty
          ? const Center(child: Text('No doctors yet'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: doctors
                  .map(
                    (doctor) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            ClinicFormatters.initial(doctor.fullName),
                          ),
                        ),
                        title: Text(doctor.fullName),
                        subtitle: Text(
                          '${doctor.specialty.labelEn} • ${ClinicFormatters.money(doctor.consultationFee)}\n${doctor.isAvailable ? 'Accepting bookings' : 'Booking disabled'}',
                        ),
                        isThreeLine: true,
                        onTap: busy
                            ? null
                            : () => editDoctorProfile(context, doctor),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('doctor-menu-${doctor.id}'),
                          enabled: !busy,
                          onSelected: (action) {
                            if (action == 'edit') {
                              editDoctorProfile(context, doctor);
                            } else {
                              removeProfile(context, ref, doctor: doctor);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit profile & availability'),
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
