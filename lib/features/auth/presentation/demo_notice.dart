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

enum _ModeAction { details, reset }

/// A quiet mode indicator; details and demo reset stay available in its menu.
class DemoNotice extends ConsumerWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(backendConfigurationProvider);
    final theme = Theme.of(context);
    final label = config.isDemo
        ? 'Demo'
        : config.useEmulators
        ? 'Emulator'
        : 'Clinic';
    final details = config.isDemo
        ? 'Offline demo · Fictional data\nChanges last until reset or restart.'
        : config.useEmulators
        ? 'Local emulator · Fictional data\nClinic time: Africa/Cairo.'
        : 'Connected clinic · Clinic time: Africa/Cairo.';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<_ModeAction>(
            key: const ValueKey('clinic-mode-indicator'),
            tooltip: config.isDemo ? 'Demo mode' : 'Clinic connection',
            onSelected: (action) {
              if (action == _ModeAction.reset) {
                confirmDemoReset(context, ref);
                return;
              }
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    config.isDemo ? 'Demo mode' : 'Clinic connection',
                  ),
                  content: Text(details),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ModeAction.details,
                child: Text('Mode details'),
              ),
              if (config.isDemo)
                const PopupMenuItem(
                  value: _ModeAction.reset,
                  child: Text('Reset demo'),
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          config.isDemo
                              ? Icons.science_outlined
                              : Icons.cloud_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(label, style: theme.textTheme.labelSmall),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.expand_more,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
