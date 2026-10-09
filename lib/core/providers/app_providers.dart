import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_use_cases.dart';
import '../../features/auth/domain/auth_session.dart';
import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/auth/presentation/password_recovery_view_model.dart';
import '../../features/clinic/domain/app_enums.dart';
import '../../features/clinic/domain/book_appointment.dart';
import '../../features/clinic/domain/authoritative_reservations.dart';
import '../../features/clinic/domain/clinic_failure.dart';
import '../../features/clinic/domain/appointment_policy.dart';
import '../../features/clinic/domain/change_appointment_status.dart';
import '../../features/clinic/domain/clinic_access.dart';
import '../../features/clinic/domain/clinic_queries.dart';
import '../../features/clinic/domain/clinic_analytics.dart';
import '../../features/clinic/domain/billing_use_cases.dart';
import '../../features/clinic/presentation/billing_view_model.dart';
import '../../features/clinic/domain/manage_profiles.dart';
import '../../features/clinic/presentation/profile_view_model.dart';
import '../../features/clinic/domain/clinic_snapshot.dart';
import '../../features/clinic/domain/entities.dart';
import '../../features/clinic/presentation/booking_view_model.dart';
import '../../features/clinic/presentation/appointment_actions_view_model.dart';
import '../../features/clinic/presentation/clinic_view_model.dart';
import 'app_dependencies.dart';

export '../../features/auth/presentation/auth_view_model.dart' show AuthState;
export '../../features/clinic/presentation/enum_labels.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final passwordRecoveryProvider =
    StateNotifierProvider.autoDispose<
      PasswordRecoveryViewModel,
      PasswordRecoveryState
    >(
      (ref) => PasswordRecoveryViewModel(
        RequestPasswordReset(ref.watch(authRepositoryProvider)),
      ),
    );

final StateNotifierProvider<AuthViewModel, AuthState> authProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
      final repository = ref.watch(authRepositoryProvider);
      final model = AuthViewModel(
        SignIn(repository),
        RegisterUser(repository),
        SignOut(repository),
        sessions: repository is AuthSessionSource
            ? repository as AuthSessionSource
            : null,
      );
      if (ref.watch(isDemoProvider)) {
        ref.listen(clinicViewModelProvider, (previous, next) {
          if (!next.isLoading && !next.hasError && next.valueOrNull != null) {
            model.syncProfile(next.valueOrNull!);
          }
        });
      }
      return model;
    });

final clinicViewModelProvider =
    StateNotifierProvider<ClinicViewModel, AsyncValue<ClinicSnapshot>>((ref) {
      if (!ref.watch(isDemoProvider)) {
        ref.watch(
          authProvider.select(
            (state) => (state.currentUser?.id, state.currentUser?.role),
          ),
        );
      }
      return ClinicViewModel(ref.watch(clinicRepositoryProvider));
    });

final clinicSnapshotProvider = Provider<ClinicSnapshot>(
  (ref) => ClinicAccess.scope(
    ref.watch(clinicViewModelProvider).valueOrNull ?? ClinicSnapshot(),
    ref.watch(authProvider).currentUser,
  ),
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

final selectedSpecialtyProvider = StateProvider<MedicalSpecialty?>((ref) {
  ref.watch(authProvider.select((state) => state.currentUser?.id));
  return null;
});
final searchQueryProvider = StateProvider<String>((ref) {
  ref.watch(authProvider.select((state) => state.currentUser?.id));
  return '';
});
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
    ref.watch(clinicTimeProvider),
  ),
);
final pastAppointmentsProvider = Provider<List<Appointment>>(
  (ref) => ClinicQueries.past(
    ref.watch(appointmentsProvider),
    ref.watch(clinicTimeProvider),
  ),
);
final clinicMetricsProvider = Provider<ClinicMetrics>(
  (ref) => ClinicMetrics(
    ref.watch(clinicSnapshotProvider),
    ref.watch(analyticsTimeProvider),
  ),
);

final clinicAnalyticsProvider = Provider<ClinicAnalytics>(
  (ref) => ClinicAnalytics(
    ref.watch(clinicSnapshotProvider),
    ref.watch(analyticsTimeProvider),
  ),
);

// Re-evaluate at the actual clock time when new records arrive, as well as on
// periodic ticks. A newly paid invoice must not look future-dated for 30 seconds.
final analyticsTimeProvider = Provider<DateTime>((ref) {
  ref.watch(clinicTimeProvider);
  ref.watch(clinicSnapshotProvider);
  return ref.watch(clockProvider)();
});

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
  (ref) => ClinicQueries.dateOptions(ref.watch(clinicTimeProvider)),
);

final billingActionsProvider =
    StateNotifierProvider.autoDispose<BillingViewModel, BillingActionState>((
      ref,
    ) {
      ref.watch(authProvider.select((s) => s.currentUser?.id));
      final repository = ref.watch(clinicRepositoryProvider);
      return BillingViewModel(
        IssueAppointmentInvoice(repository, ref.watch(idGeneratorProvider)),
        RecordInvoicePayment(repository),
        () => ref.read(authProvider).currentUser,
      );
    });

final profileActionsProvider =
    StateNotifierProvider.autoDispose<ProfileViewModel, ProfileActionState>((
      ref,
    ) {
      ref.watch(authProvider.select((s) => s.currentUser?.id));
      return ProfileViewModel(
        ManageProfiles(
          ref.watch(clinicRepositoryProvider),
          ref.watch(idGeneratorProvider),
        ),
        () => ref.read(authProvider).currentUser,
      );
    });

final appointmentActionsProvider =
    StateNotifierProvider.autoDispose<
      AppointmentActionsViewModel,
      AppointmentActionState
    >((ref) {
      ref.watch(authProvider.select((s) => s.currentUser?.id));
      return AppointmentActionsViewModel(
        ChangeAppointmentStatus(ref.watch(clinicRepositoryProvider)),
        () => ref.read(authProvider).currentUser,
      );
    });

final bookingSlotsProvider =
    Provider.family<List<DateTime>, ({String doctorId, DateTime date})>((
      ref,
      selection,
    ) {
      final patient = ref.watch(authProvider).currentUser;
      if (patient == null ||
          !patient.isActive ||
          patient.role != UserRole.patient) {
        return const [];
      }
      // Synthetic availability can inspect the local full snapshot; a backend must
      // expose free slots without returning other patients' records.
      final snapshot = ref.watch(clinicViewModelProvider).valueOrNull;
      if (snapshot == null) return const [];
      final doctors = snapshot.doctors.where((d) => d.id == selection.doctorId);
      if (doctors.length != 1) return const [];
      return AppointmentPolicy.availableSlots(
        snapshot,
        doctor: doctors.single,
        patientId: patient.id,
        date: selection.date,
        now: ref.watch(clinicTimeProvider),
      );
    });

final remoteBookingSlotsProvider = FutureProvider.autoDispose
    .family<List<DateTime>, ({String doctorId, DateTime date})>((
      ref,
      selection,
    ) {
      ref.watch(
        authProvider.select(
          (state) => (state.currentUser?.id, state.currentUser?.role),
        ),
      );
      ref.watch(clinicViewModelProvider);
      ref.watch(clinicTimeProvider);
      final repository = ref.watch(clinicRepositoryProvider);
      if (repository is! AuthoritativeReservations) {
        throw const ClinicFailure(
          FailureCode.unavailable,
          'Remote availability is unavailable.',
        );
      }
      return (repository as AuthoritativeReservations).availableSlots(
        doctorId: selection.doctorId,
        date: selection.date,
      );
    });

/// Reset the whole synthetic clinic, including registered identities and pending
/// view-model operations. Logout alone preserves records for role switching.
final resetDemoProvider = Provider<void Function()>(
  (ref) => () {
    if (!ref.read(isDemoProvider)) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Reset is available only in the offline demo.',
      );
    }
    ref.invalidate(authProvider);
    ref.invalidate(authRepositoryProvider);
    ref.invalidate(clinicRepositoryProvider);
    ref.invalidate(clinicViewModelProvider);
    ref.invalidate(bookingProvider);
    ref.invalidate(appointmentActionsProvider);
    ref.invalidate(billingActionsProvider);
    ref.invalidate(profileActionsProvider);
    ref.invalidate(searchQueryProvider);
    ref.invalidate(selectedSpecialtyProvider);
  },
);
