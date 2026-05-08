import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../shared/enums/app_enums.dart';
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _patientShellKey = GlobalKey<NavigatorState>();
final _doctorShellKey = GlobalKey<NavigatorState>();
final _adminShellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/' ||
          state.matchedLocation == '/onboarding';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) {
        switch (authState.currentUser?.role) {
          case UserRole.patient:
            return '/patient';
          case UserRole.doctor:
            return '/doctor';
          case UserRole.admin:
            return '/admin';
          default:
            return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (ctx, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, state) => const RegisterScreen()),

      // ── Patient Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => PatientShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _patientShellKey, routes: [
            GoRoute(path: '/patient', builder: (ctx, state) => const PatientDashboard(), routes: [
              GoRoute(path: 'book', builder: (ctx, state) => const BookAppointmentScreen()),
              GoRoute(path: 'prescriptions', builder: (ctx, state) => const PrescriptionHistoryScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/doctors', builder: (ctx, state) => const DoctorsListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/appointments', builder: (ctx, state) => const AppointmentsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/profile', builder: (ctx, state) => const PatientProfileScreen()),
          ]),
        ],
      ),

      // ── Doctor Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => DoctorShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _doctorShellKey, routes: [
            GoRoute(path: '/doctor', builder: (ctx, state) => const DoctorDashboard()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/doctor/schedule', builder: (ctx, state) => const DoctorScheduleScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/doctor/patients', builder: (ctx, state) => const DoctorPatientsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/doctor/profile', builder: (ctx, state) => const DoctorProfileScreen()),
          ]),
        ],
      ),

      // ── Admin Shell ──
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _adminShellKey, routes: [
            GoRoute(path: '/admin', builder: (ctx, state) => const AdminDashboard()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/doctors', builder: (ctx, state) => const ManageDoctorsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/patients', builder: (ctx, state) => const ManagePatientsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/billing', builder: (ctx, state) => const BillingScreen()),
          ]),
        ],
      ),
    ],
  );
});
