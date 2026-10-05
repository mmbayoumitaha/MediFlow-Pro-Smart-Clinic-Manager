import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_use_cases.dart';
import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/clinic/domain/app_enums.dart';
import '../../features/clinic/domain/book_appointment.dart';
import '../../features/clinic/domain/clinic_queries.dart';
import '../../features/clinic/domain/clinic_snapshot.dart';
import '../../features/clinic/domain/entities.dart';
import '../../features/clinic/presentation/booking_view_model.dart';
import '../../features/clinic/presentation/clinic_view_model.dart';
import 'app_dependencies.dart';

export '../../features/auth/presentation/auth_view_model.dart' show AuthState;
export '../../features/clinic/presentation/enum_labels.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

final authProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthViewModel(
    SignIn(repository),
    RegisterUser(repository),
    SignOut(repository),
  );
});

final clinicViewModelProvider =
    StateNotifierProvider<ClinicViewModel, AsyncValue<ClinicSnapshot>>(
      (ref) => ClinicViewModel(ref.watch(clinicRepositoryProvider)),
    );

final clinicSnapshotProvider = Provider<ClinicSnapshot>(
  (ref) => ref.watch(clinicViewModelProvider).valueOrNull ?? ClinicSnapshot(),
);
final doctorsProvider = Provider<List<Doctor>>(
  (ref) => ref.watch(clinicSnapshotProvider).doctors,
);
final patientsProvider = Provider<List<ClinicUser>>(
  (ref) => ref.watch(clinicSnapshotProvider).patients,
);
final appointmentsProvider = Provider<List<Appointment>>(
  (ref) => ref.watch(clinicSnapshotProvider).appointments,
);
final prescriptionsProvider = Provider<List<Prescription>>(
  (ref) => ref.watch(clinicSnapshotProvider).prescriptions,
);
final invoicesProvider = Provider<List<Invoice>>(
  (ref) => ref.watch(clinicSnapshotProvider).invoices,
);

final selectedSpecialtyProvider = StateProvider<MedicalSpecialty?>(
  (ref) => null,
);
final searchQueryProvider = StateProvider<String>((ref) => '');
final filteredDoctorsProvider = Provider<List<Doctor>>(
  (ref) => ClinicQueries.doctors(
    ref.watch(doctorsProvider),
    ref.watch(selectedSpecialtyProvider),
    ref.watch(searchQueryProvider),
  ),
);
final sortedAppointmentsProvider = Provider<List<Appointment>>(
  (ref) => ClinicQueries.schedule(ref.watch(appointmentsProvider)),
);
final upcomingAppointmentsProvider = Provider<List<Appointment>>(
  (ref) => ClinicQueries.upcoming(
    ref.watch(appointmentsProvider),
    ref.watch(clockProvider)(),
  ),
);
final pastAppointmentsProvider = Provider<List<Appointment>>(
  (ref) => ClinicQueries.past(
    ref.watch(appointmentsProvider),
    ref.watch(clockProvider)(),
  ),
);
final clinicMetricsProvider = Provider<ClinicMetrics>(
  (ref) => ClinicMetrics(
    ref.watch(clinicSnapshotProvider),
    ref.watch(clockProvider)(),
  ),
);

final bookingProvider =
    StateNotifierProvider.autoDispose<BookingViewModel, BookingState>((ref) {
      // Dispose a pending presentation operation when the signed-in identity changes.
      ref.watch(authProvider.select((state) => state.currentUser?.id));
      return BookingViewModel(
        BookAppointment(
          ref.watch(clinicRepositoryProvider),
          now: ref.watch(clockProvider),
          newId: ref.watch(idGeneratorProvider),
        ),
        () => ref.read(authProvider).currentUser,
      );
    });

final bookingDateOptionsProvider = Provider<List<DateTime>>(
  (ref) => ClinicQueries.dateOptions(ref.watch(clockProvider)()),
);
