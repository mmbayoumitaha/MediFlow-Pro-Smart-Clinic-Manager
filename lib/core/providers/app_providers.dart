import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../shared/enums/app_enums.dart';
import '../../shared/models/app_models.dart';
import '../../services/demo_data_service.dart';

// ──────────────────────── THEME ────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ──────────────────────── LOCALE ────────────────────────

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

// ──────────────────────── AUTH STATE ────────────────────────

class AuthState {
  final UserModel? currentUser;
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
    UserModel? currentUser,
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
    final user = UserModel(
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
    final user = UserModel(
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

final doctorsProvider = StateProvider<List<DoctorModel>>(
  (ref) => DemoDataService.doctors,
);

final selectedSpecialtyProvider = StateProvider<MedicalSpecialty?>(
  (ref) => null,
);

final filteredDoctorsProvider = Provider<List<DoctorModel>>((ref) {
  final doctors = ref.watch(doctorsProvider);
  final specialty = ref.watch(selectedSpecialtyProvider);
  if (specialty == null) return doctors;
  return doctors.where((d) => d.specialty == specialty).toList();
});

// ──────────────────────── APPOINTMENTS ────────────────────────

final appointmentsProvider = StateProvider<List<AppointmentModel>>(
  (ref) => DemoDataService.generateAppointments(),
);

final upcomingAppointmentsProvider = Provider<List<AppointmentModel>>((ref) {
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

final pastAppointmentsProvider = Provider<List<AppointmentModel>>((ref) {
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

final prescriptionsProvider = StateProvider<List<PrescriptionModel>>(
  (ref) => DemoDataService.generatePrescriptions(),
);

// ──────────────────────── INVOICES ────────────────────────

final invoicesProvider = StateProvider<List<InvoiceModel>>(
  (ref) => DemoDataService.generateInvoices(),
);

// ──────────────────────── PATIENTS ────────────────────────

final patientsProvider = StateProvider<List<UserModel>>(
  (ref) => DemoDataService.generatePatients(),
);

// ──────────────────────── SEARCH ────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ──────────────────────── BOTTOM NAV INDEX ────────────────────────

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
