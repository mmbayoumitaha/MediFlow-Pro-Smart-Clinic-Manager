import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

class ManagePatientsScreen extends ConsumerWidget {
  const ManagePatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Patients')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: patients.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
              CircleAvatar(radius: 22, backgroundColor: AppColors.primaryContainer,
                child: Text(p.fullName[0], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: theme.textTheme.titleMedium),
                Text('${p.email} • ${p.phone}', style: theme.textTheme.bodySmall),
              ])),
              PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
