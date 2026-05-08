import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(icon: Icons.calendar_month_rounded, title: 'Book Appointments', subtitle: 'Schedule visits with top doctors in just a few taps. Get reminders so you never miss an appointment.', color: AppColors.primary),
    _OnboardingPage(icon: Icons.medical_information_rounded, title: 'Medical Records', subtitle: 'Access your complete medical history, prescriptions, and test results securely from anywhere.', color: AppColors.secondary),
    _OnboardingPage(icon: Icons.analytics_rounded, title: 'Smart Analytics', subtitle: 'Doctors and admins get powerful dashboards with real-time insights to make better decisions.', color: AppColors.accent),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: () => context.go('/login'), child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Row(children: List.generate(3, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    width: _currentPage == i ? 24 : 8, height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i ? AppColors.primary : AppColors.slate300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ))),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                      } else {
                        context.go('/login');
                      }
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                    child: Text(_currentPage < 2 ? 'Next' : 'Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 40),
          Text(title, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.slate500, height: 1.6), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
