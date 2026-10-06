import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';

import 'route_access.dart';

import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/patient/screens/patient_shell.dart';
import '../features/patient/screens/patient_dashboard.dart';
import '../features/patient/screens/doctors_list_screen.dart';
import '../features/patient/screens/appointments_screen.dart';
import '../features/patient/screens/patient_profile_screen.dart';
import '../features/patient/screens/book_appointment_screen.dart';
import '../features/patient/screens/prescription_history_screen.dart';
import '../features/doctor/screens/doctor_shell.dart';
import '../features/doctor/screens/doctor_dashboard.dart';
import '../features/doctor/screens/doctor_schedule_screen.dart';
import '../features/doctor/screens/doctor_patients_screen.dart';
import '../features/doctor/screens/doctor_profile_screen.dart';
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/admin_dashboard.dart';
import '../features/admin/screens/manage_doctors_screen.dart';
import '../features/admin/screens/manage_patients_screen.dart';
import '../features/admin/screens/billing_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      return RouteAccess.redirect(
        state.uri.path,
        ref.read(authProvider).currentUser,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (ctx, state) => const RegisterScreen(),
      ),

      // ── Patient Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => PatientShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient',
                builder: (ctx, state) => const PatientDashboard(),
                routes: [
                  GoRoute(
                    path: 'book',
                    builder: (ctx, state) => const BookAppointmentScreen(),
                  ),
                  GoRoute(
                    path: 'prescriptions',
                    builder: (ctx, state) => const PrescriptionHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/doctors',
                builder: (ctx, state) => const DoctorsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/appointments',
                builder: (ctx, state) => const AppointmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/profile',
                builder: (ctx, state) => const PatientProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Doctor Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => DoctorShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor',
                builder: (ctx, state) => const DoctorDashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/schedule',
                builder: (ctx, state) => const DoctorScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/patients',
                builder: (ctx, state) => const DoctorPatientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/doctor/profile',
                builder: (ctx, state) => const DoctorProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Admin Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (ctx, state) => const AdminDashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/doctors',
                builder: (ctx, state) => const ManageDoctorsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/patients',
                builder: (ctx, state) => const ManagePatientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/billing',
                builder: (ctx, state) => const BillingScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
