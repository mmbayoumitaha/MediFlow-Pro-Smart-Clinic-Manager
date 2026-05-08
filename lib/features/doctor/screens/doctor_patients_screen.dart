import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class DoctorPatientsScreen extends ConsumerWidget {
  const DoctorPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Patients')),
      body: patients.isEmpty
          ? const EmptyState(icon: Icons.people_outlined, title: 'No Patients')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = patients[i];
                return Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  ),
                  child: Row(children: [
                    CircleAvatar(radius: 22, backgroundColor: AppColors.secondaryContainer,
                      child: Text(p.fullName[0], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.fullName, style: theme.textTheme.titleMedium),
                      Text(p.email, style: theme.textTheme.bodySmall),
                    ])),
                    Text(p.gender?.labelEn ?? '', style: theme.textTheme.labelSmall),
                  ]),
                );
              },
            ),
    );
  }
}
