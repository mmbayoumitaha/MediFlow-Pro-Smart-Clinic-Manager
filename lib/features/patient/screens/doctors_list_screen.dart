import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

import 'package:mediflow/features/clinic/domain/app_enums.dart';

import '../../../shared/widgets/shared_widgets.dart';

class DoctorsListScreen extends ConsumerWidget {
  const DoctorsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(filteredDoctorsProvider);
    final selectedSpecialty = ref.watch(selectedSpecialtyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a Doctor')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: TextField(
              onChanged: (query) =>
                  ref.read(searchQueryProvider.notifier).state = query,
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Specialty filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: selectedSpecialty == null,
                    onSelected: (_) =>
                        ref.read(selectedSpecialtyProvider.notifier).state =
                            null,
                    selectedColor: AppColors.primaryContainer,
                  ),
                ),
                ...MedicalSpecialty.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${s.emoji} ${s.labelEn}'),
                      selected: selectedSpecialty == s,
                      onSelected: (_) =>
                          ref.read(selectedSpecialtyProvider.notifier).state =
                              selectedSpecialty == s ? null : s,
                      selectedColor: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Doctor list
          Expanded(
            child: doctors.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'No doctors found',
                  )
                : ListView.separated(
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
          ),
        ],
      ),
    );
  }
}
