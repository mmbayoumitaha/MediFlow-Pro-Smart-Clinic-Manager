import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatters/clinic_formatters.dart';
import '../../../core/providers/app_providers.dart';
import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/billing_policy.dart';
import '../../clinic/domain/entities.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  Future<void> _issue(
    BuildContext context,
    WidgetRef ref,
    Appointment visit,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Issue demo invoice?'),
        content: Text(
          'Consultation only: ${ClinicFormatters.money(visit.fee)}. No tax or discount is added. No payment is collected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Issue invoice'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    final ok = await ref.read(billingActionsProvider.notifier).issue(visit.id);
    if (context.mounted) _feedback(context, ref, ok);
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    bool refund,
  ) async {
    var method = DemoPaymentMethod.cash;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            refund
                ? 'Record full demo refund?'
                : 'Record full demo settlement?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ClinicFormatters.money(invoice.total)} • ${invoice.patientName}',
              ),
              const SizedBox(height: 12),
              const Text(
                'This updates fictional records only. No money is charged or refunded.',
              ),
              if (!refund)
                DropdownButtonFormField<DemoPaymentMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: DemoPaymentMethod.values
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m, child: Text(_method(m))),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => method = value!),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(refund ? 'Record refund' : 'Record settlement'),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !context.mounted) return;
    final ok = await ref
        .read(billingActionsProvider.notifier)
        .record(
          invoice,
          refund ? PaymentStatus.refunded : PaymentStatus.paid,
          method: refund ? null : method,
        );
    if (context.mounted) _feedback(context, ref, ok);
  }

  void _feedback(BuildContext context, WidgetRef ref, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demo billing updated.'
              : ref.read(billingActionsProvider).error ??
                    'Another billing update is in progress.',
        ),
      ),
    );
    if (!ok) ref.read(clinicViewModelProvider.notifier).refresh();
  }

  static String _method(DemoPaymentMethod method) => switch (method) {
    DemoPaymentMethod.cash => 'Cash',
    DemoPaymentMethod.card => 'Card',
    DemoPaymentMethod.bankTransfer => 'Bank transfer',
  };
  Color _color(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => Colors.green,
    PaymentStatus.unpaid => Colors.orange,
    PaymentStatus.partial => Colors.blue,
    PaymentStatus.refunded => Colors.grey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider).toList()
      ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
    final eligible = ref
        .watch(appointmentsProvider)
        .where(
          (a) =>
              a.status == AppointmentStatus.completed &&
              a.paymentStatus == PaymentStatus.unpaid &&
              a.fee > 0 &&
              a.fee.isFinite &&
              !invoices.any((i) => i.appointmentId == a.id),
        );
    final busy = ref.watch(billingActionsProvider).busyId != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Demo settlements and full refunds only. No real payment processing. Partial balances are not tracked; an imported partial invoice can be marked fully settled.',
          ),
          const SizedBox(height: 16),
          Text(
            'Fully paid invoices: ${ClinicFormatters.money(ref.watch(clinicAnalyticsProvider).paidInvoiceTotal)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (eligible.isNotEmpty) ...[
            Text(
              'Completed visits awaiting an invoice',
              style: theme.textTheme.titleMedium,
            ),
            ...eligible.map(
              (a) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.patientName} • ${a.doctorName}'),
                      Text(ClinicFormatters.money(a.fee)),
                      OutlinedButton(
                        key: ValueKey('issue-${a.id}'),
                        onPressed: busy ? null : () => _issue(context, ref, a),
                        child: const Text('Issue consultation invoice'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (invoices.isEmpty) const Text('No invoices yet'),
          ...invoices.map(
            (invoice) => Card(
              key: ValueKey('invoice-${invoice.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.patientName,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Invoice #${invoice.id}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          ClinicFormatters.money(invoice.total),
                          style: theme.textTheme.titleLarge,
                        ),
                        Chip(
                          label: Text(invoice.paymentStatus.labelEn),
                          side: BorderSide(
                            color: _color(invoice.paymentStatus),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...invoice.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 12,
                          children: [
                            Text('${item.description} × ${item.quantity}'),
                            Text(ClinicFormatters.money(item.total)),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'Subtotal: ${ClinicFormatters.money(invoice.subtotal)}',
                    ),
                    Text(
                      'Tax: ${ClinicFormatters.money(invoice.tax)} • Discount: ${ClinicFormatters.money(invoice.discount)}',
                    ),
                    Text(
                      'Issued: ${DateFormat('MMM dd, yyyy').format(invoice.issuedDate)}',
                    ),
                    if (invoice.paidDate != null)
                      Text(
                        'Settlement date: ${DateFormat('MMM dd, yyyy').format(invoice.paidDate!)}',
                      ),
                    if (invoice.paymentMethod != null)
                      Text('Method: ${invoice.paymentMethod}'),
                    if (invoice.paymentStatus == PaymentStatus.unpaid ||
                        invoice.paymentStatus == PaymentStatus.partial)
                      OutlinedButton(
                        key: ValueKey('settle-${invoice.id}'),
                        onPressed: busy
                            ? null
                            : () => _record(context, ref, invoice, false),
                        child: const Text('Record full settlement'),
                      ),
                    if (invoice.paymentStatus == PaymentStatus.paid)
                      OutlinedButton(
                        key: ValueKey('refund-${invoice.id}'),
                        onPressed: busy
                            ? null
                            : () => _record(context, ref, invoice, true),
                        child: const Text('Record full refund'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
