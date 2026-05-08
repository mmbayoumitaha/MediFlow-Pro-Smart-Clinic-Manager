import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/enums/app_enums.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoices')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final inv = invoices[i];
          final isPaid = inv.paymentStatus == PaymentStatus.paid;
          return Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_rounded, color: isPaid ? AppColors.success : AppColors.warning, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inv.patientName, style: theme.textTheme.titleMedium),
                  Text('Invoice #${inv.id.substring(0, inv.id.length < 8 ? inv.id.length : 8).toUpperCase()}', style: theme.textTheme.bodySmall),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${inv.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isPaid ? AppColors.success : AppColors.warning)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSizes.radiusFull)),
                    child: Text(isPaid ? 'Paid' : 'Unpaid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : AppColors.warning)),
                  ),
                ]),
              ]),
              const Divider(height: 20),
              ...inv.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(item.description, style: theme.textTheme.bodySmall),
                  Text('\$${item.total.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                ]),
              )),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tax', style: theme.textTheme.bodySmall),
                Text('\$${inv.tax.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              Text('Issued: ${DateFormat('MMM dd, yyyy').format(inv.issuedDate)}', style: theme.textTheme.labelSmall),
            ]),
          );
        },
      ),
    );
  }
}
