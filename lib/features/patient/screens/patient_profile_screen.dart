import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(children: [
          // Avatar & Info
          CircleAvatar(radius: 48, backgroundColor: AppColors.primaryContainer,
            child: Text((user?.fullName ?? 'P')[0], style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primary))),
          const SizedBox(height: 12),
          Text(user?.fullName ?? '', style: theme.textTheme.headlineMedium),
          Text(user?.email ?? '', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),

          // Settings tiles
          _ProfileTile(icon: Icons.person_outline, title: 'Edit Profile', onTap: () {}),
          _ProfileTile(icon: Icons.lock_outline, title: 'Change Password', onTap: () {}),
          _ProfileTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
          _ProfileTile(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: isDark ? 'Light Mode' : 'Dark Mode',
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light,
              activeThumbColor: AppColors.primary,
            ),
            onTap: () => ref.read(themeModeProvider.notifier).state = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          _ProfileTile(icon: Icons.language_outlined, title: 'Language', subtitle: 'English', onTap: () {}),
          _ProfileTile(icon: Icons.info_outline, title: 'About', onTap: () {}),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () { ref.read(authProvider.notifier).logout(); context.go('/login'); },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: const Text('Logout', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), minimumSize: const Size(double.infinity, 48)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle; final VoidCallback onTap; final Widget? trailing;
  const _ProfileTile({required this.icon, required this.title, this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
    );
  }
}
