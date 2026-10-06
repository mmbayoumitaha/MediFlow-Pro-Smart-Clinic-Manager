import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../auth/presentation/demo_notice.dart';
import '../domain/clinic_failure.dart';

/// All three portals share repository loading, failure and retry behavior.
class ClinicDataGate extends ConsumerWidget {
  final Widget child;
  const ClinicDataGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(clinicViewModelProvider);
    final error = data.error;
    final message = error is ClinicFailure
        ? error.message
        : 'Clinic data could not be loaded. Please try again.';
    void retry() => ref.read(clinicViewModelProvider.notifier).refresh();

    if (data.valueOrNull == null) {
      if (data.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: retry, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        const DemoNotice(),
        if (data.isLoading) const LinearProgressIndicator(),
        if (data.hasError)
          MaterialBanner(
            content: Text(message),
            actions: [TextButton(onPressed: retry, child: const Text('Retry'))],
          ),
        Expanded(child: child),
      ],
    );
  }
}
