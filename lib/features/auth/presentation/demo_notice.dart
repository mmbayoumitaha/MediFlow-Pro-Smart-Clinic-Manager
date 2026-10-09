import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/app_dependencies.dart';

Future<void> confirmDemoReset(BuildContext context, WidgetRef ref) async {
  if (!ref.read(isDemoProvider)) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset demo?'),
      content: const Text(
        'This removes demo registrations and bookings, restores the sample '
        'clinic and signs you out. Changes are kept when you only sign out.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reset demo'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) ref.read(resetDemoProvider)();
}

/// Visible in each portal so simulated data never looks like live clinic data.
class DemoNotice extends ConsumerWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(backendConfigurationProvider);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.isDemo
                      ? 'Offline demo · Fictional data\nChanges last until reset or restart.'
                      : config.useEmulators
                      ? 'Local emulator · Fictional data\nClinic time: Africa/Cairo.'
                      : 'Connected clinic · Clinic time: Africa/Cairo.',
                ),
              ),
              if (config.isDemo)
                TextButton(
                  onPressed: () => confirmDemoReset(context, ref),
                  child: const Text('Reset demo'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
