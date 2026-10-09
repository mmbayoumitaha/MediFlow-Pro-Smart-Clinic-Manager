import '../../../core/formatters/clinic_formatters.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../clinic/presentation/profile_forms.dart';

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
        child: Column(
          children: [
            // Avatar & Info
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                ClinicFormatters.initial(user?.fullName),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(user?.fullName ?? '', style: theme.textTheme.headlineMedium),
            Text(user?.email ?? '', style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),

            // Settings tiles
            _ProfileTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: user == null
                  ? null
                  : () => editPatientProfile(context, user),
            ),
            _ProfileTile(
              icon: isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              title: isDark ? 'Light Mode' : 'Dark Mode',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (v) => ref.read(themeModeProvider.notifier).state = v
                    ? ThemeMode.dark
                    : ThemeMode.light,
                activeThumbColor: AppColors.primary,
              ),
              onTap: () => ref.read(themeModeProvider.notifier).state = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
            _ProfileTile(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'MediFlow Pro',
                applicationVersion: '1.0.0',
                children: [
                  const Text(
                    'MediFlow Pro is a personal clinic-management project with an offline demo and an optional connected backend. Billing actions record payments; they do not charge or refund money.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
    );
  }
}
