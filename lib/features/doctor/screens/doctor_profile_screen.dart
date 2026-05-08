import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(children: [
          CircleAvatar(radius: 48, backgroundColor: AppColors.secondaryContainer,
            child: Text((user?.fullName ?? 'D')[0], style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.secondary))),
          const SizedBox(height: 12),
          Text(user?.fullName ?? '', style: theme.textTheme.headlineMedium),
          Text(user?.email ?? '', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.person_outline, color: AppColors.primary), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
          ListTile(leading: const Icon(Icons.schedule_outlined, color: AppColors.primary), title: const Text('Availability'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
          ListTile(
            leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: AppColors.primary),
            title: Text(isDark ? 'Light Mode' : 'Dark Mode'),
            trailing: Switch(value: isDark, onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light, activeColor: AppColors.primary),
            onTap: () => ref.read(themeModeProvider.notifier).state = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () { ref.read(authProvider.notifier).logout(); context.go('/login'); },
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), minimumSize: const Size(double.infinity, 48)),
          )),
        ]),
      ),
    );
  }
}
