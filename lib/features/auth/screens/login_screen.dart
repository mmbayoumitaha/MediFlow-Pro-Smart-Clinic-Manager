import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/app_dependencies.dart';
import '../presentation/demo_notice.dart';

import 'package:mediflow/features/clinic/domain/app_enums.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.patient;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (ref.read(isDemoProvider)) {
      _emailController.text = 'demo@mediflow.com';
      _passwordController.text = 'password123';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .login(
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDemo = ref.watch(isDemoProvider);
    final recovery = isDemo ? null : ref.watch(passwordRecoveryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Welcome Back', style: theme.textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(
                  isDemo
                      ? 'Explore MediFlow Pro with fictional clinic data'
                      : 'Sign in to your clinic account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 16),
                if (isDemo) ...[
                  const Text(
                    'Offline demo: no real authentication. Passwords are not '
                    'checked or stored. Use dummy details only.',
                  ),
                  const SizedBox(height: 16),

                  // Role selector
                  Text('Demo role', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Role selection applies to demo@mediflow.com only. '
                    'Other demo accounts keep their registered role.',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: UserRole.values.map((role) {
                      final isSelected = _selectedRole == role;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = role),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(
                              right: role != UserRole.admin ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.slate300,
                              ),
                            ),
                            child: Text(
                              role.labelEn,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.slate500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const DemoNotice(),
                  const SizedBox(height: 12),
                  const Text(
                    'Your clinic account determines your role. Doctors and administrators are provisioned by the clinic.',
                  ),
                  const SizedBox(height: 24),
                ],

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v != null && v.contains('@')
                      ? null
                      : 'Enter a valid email',
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: isDemo
                        ? 'Dummy password (6+ characters)'
                        : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isDemo
                        ? () => confirmDemoReset(context, ref)
                        : recovery!.isSubmitting || authState.isLoading
                        ? null
                        : () => ref
                              .read(passwordRecoveryProvider.notifier)
                              .send(_emailController.text),
                    child: Text(
                      isDemo
                          ? 'Reset demo'
                          : recovery!.isSubmitting
                          ? 'Requesting reset...'
                          : 'Reset password',
                    ),
                  ),
                ),
                if (recovery?.requested == true)
                  const Text(
                    'If this address can receive a reset, check its inbox for a password reset link.',
                  ),
                if (recovery?.error != null)
                  Text(
                    recovery!.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                const SizedBox(height: 16),

                // Login button
                FilledButton(
                  onPressed: authState.isLoading ? null : _login,
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),

                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
