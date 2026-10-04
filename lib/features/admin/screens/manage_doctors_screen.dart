import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ManageDoctorsScreen extends ConsumerWidget {
  const ManageDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Doctors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: doctors.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final doc = doctors[i];
          return DoctorCard(
            name: doc.fullName,
            specialty: doc.specialty.labelEn,
            emoji: doc.specialty.emoji,
            rating: doc.rating,
            reviews: doc.totalReviews,
            fee: doc.consultationFee,
            isAvailable: doc.isAvailable,
          );
        },
      ),
    );
  }
}
