import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';

// ──────────────────────── THEME ────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ──────────────────────── LOCALE ────────────────────────

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

// ──────────────────────── AUTH STATE ────────────────────────

class AuthState {
  final ClinicUser? currentUser;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    ClinicUser? currentUser,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Demo login — accepts any of the 3 roles.
  Future<void> login(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final user = ClinicUser(
      id: role == UserRole.admin
          ? 'admin-001'
          : (role == UserRole.doctor ? 'doc-001' : 'pat-001'),
      email: email,
      fullName: role == UserRole.admin
          ? 'Admin User'
          : (role == UserRole.doctor ? 'Dr. Ahmed Hassan' : 'Mariam Saeed'),
      phone: '+201001234567',
      role: role,
      gender: role == UserRole.doctor ? Gender.male : Gender.female,
      isActive: true,
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now,
    );

    state = AuthState(
      currentUser: user,
      isAuthenticated: true,
      isLoading: false,
    );
  }

  Future<void> register(
    String fullName,
    String email,
    String password,
    String phone,
    UserRole role,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(milliseconds: 1000));

    final now = DateTime.now();
    final user = ClinicUser(
      id: 'user-${now.millisecondsSinceEpoch}',
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    state = AuthState(
      currentUser: user,
      isAuthenticated: true,
      isLoading: false,
    );
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

// ──────────────────────── DOCTORS ────────────────────────

final doctorsProvider = StateProvider<List<Doctor>>(
  (ref) => DemoFixtures.generateDoctors(),
);

final selectedSpecialtyProvider = StateProvider<MedicalSpecialty?>(
  (ref) => null,
);

final filteredDoctorsProvider = Provider<List<Doctor>>((ref) {
  final doctors = ref.watch(doctorsProvider);
  final specialty = ref.watch(selectedSpecialtyProvider);
  if (specialty == null) return doctors;
  return doctors.where((d) => d.specialty == specialty).toList();
});

// ──────────────────────── APPOINTMENTS ────────────────────────

final appointmentsProvider = StateProvider<List<Appointment>>(
  (ref) => DemoFixtures.generateAppointments(),
);

final upcomingAppointmentsProvider = Provider<List<Appointment>>((ref) {
  final appointments = ref.watch(appointmentsProvider);
  final now = DateTime.now();
  return appointments
      .where(
        (a) =>
            a.dateTime.isAfter(now) && a.status != AppointmentStatus.cancelled,
      )
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
});

final pastAppointmentsProvider = Provider<List<Appointment>>((ref) {
  final appointments = ref.watch(appointmentsProvider);
  final now = DateTime.now();
  return appointments
      .where(
        (a) =>
            a.dateTime.isBefore(now) || a.status == AppointmentStatus.completed,
      )
      .toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
});

// ──────────────────────── PRESCRIPTIONS ────────────────────────

final prescriptionsProvider = StateProvider<List<Prescription>>(
  (ref) => DemoFixtures.generatePrescriptions(),
);

// ──────────────────────── INVOICES ────────────────────────

final invoicesProvider = StateProvider<List<Invoice>>(
  (ref) => DemoFixtures.generateInvoices(),
);

// ──────────────────────── PATIENTS ────────────────────────

final patientsProvider = StateProvider<List<ClinicUser>>(
  (ref) => DemoFixtures.generatePatients(),
);

// ──────────────────────── SEARCH ────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ──────────────────────── BOTTOM NAV INDEX ────────────────────────

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
