import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

class PrescriptionHistoryScreen extends ConsumerWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(prescriptionsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Prescriptions')),
      body: prescriptions.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No Prescriptions Yet')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: prescriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final p = prescriptions[i];
                return Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.medication_rounded, color: AppColors.secondary, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.diagnosis, style: theme.textTheme.titleMedium),
                        Text('By ${p.doctorName}', style: theme.textTheme.bodySmall),
                      ])),
                      Text(DateFormat('MMM dd').format(p.prescribedDate), style: theme.textTheme.labelSmall),
                    ]),
                    const Divider(height: 24),
                    ...p.medications.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.circle, size: 6, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m.name} — ${m.dosage}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text('${m.frequency} for ${m.durationDays} days', style: theme.textTheme.bodySmall),
                          if (m.instructions != null) Text(m.instructions!, style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic)),
                        ])),
                      ]),
                    )),
                    if (p.notes != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.note_outlined, size: 16, color: AppColors.accentDark),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p.notes!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accentDark))),
                        ]),
                      ),
                    ],
                  ]),
                );
              },
            ),
    );
  }
}
