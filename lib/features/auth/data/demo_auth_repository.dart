import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/clinic_failure.dart';
import '../../clinic/domain/clinic_repository.dart';
import '../../clinic/domain/entities.dart';
import '../domain/auth_repository.dart';

/// Synthetic accounts only. Passwords are validated by the use case, not stored.
class DemoAuthRepository implements AuthRepository {
  final ClinicRepository _clinic;
  final DateTime Function() now;
  final String Function() newId;
  final Map<String, ClinicUser> _registered = {};

  DemoAuthRepository(this._clinic, {required this.now, required this.newId});

  @override
  Future<ClinicUser> login(
    String email,
    String password,
    UserRole demoRole,
  ) async {
    final normalized = email.trim().toLowerCase();
    final registered = _registered[normalized];
    if (registered != null) return registered;
    final snapshot = await _clinic.load();
    if (normalized == 'demo@mediflow.com') {
      switch (demoRole) {
        case UserRole.patient:
          return snapshot.patients.first;
        case UserRole.doctor:
          return _doctorUser(snapshot.doctors.first);
        case UserRole.admin:
          final now = this.now();
          return ClinicUser(
            id: 'admin-001',
            email: normalized,
            fullName: 'Admin User',
            phone: '+201001234567',
            role: UserRole.admin,
            createdAt: now,
            updatedAt: now,
          );
      }
    }
    for (final patient in snapshot.patients) {
      if (patient.email.toLowerCase() == normalized) return patient;
    }
    for (final doctor in snapshot.doctors) {
      if (doctor.email.toLowerCase() == normalized) return _doctorUser(doctor);
    }
    throw const ClinicFailure(
      FailureCode.notFound,
      'Use demo@mediflow.com or a registered demo account.',
    );
  }

  ClinicUser _doctorUser(Doctor doctor) => ClinicUser(
    id: doctor.userId,
    email: doctor.email,
    fullName: doctor.fullName,
    phone: doctor.phone,
    role: UserRole.doctor,
    createdAt: doctor.createdAt,
    updatedAt: doctor.createdAt,
  );

  @override
  Future<ClinicUser> register(RegistrationInput input) async {
    if (input.email == 'demo@mediflow.com' ||
        _registered.containsKey(input.email)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This email is reserved or already registered.',
      );
    }
    final now = this.now();
    final user = ClinicUser(
      id: newId(),
      email: input.email,
      fullName: input.fullName,
      phone: input.phone,
      role: input.role,
      createdAt: now,
      updatedAt: now,
    );
    final doctor = input.role == UserRole.doctor
        ? Doctor(
            id: newId(),
            userId: user.id,
            fullName: user.fullName,
            email: user.email,
            phone: user.phone,
            specialty: MedicalSpecialty.generalPractice,
            consultationFee: 0,
            experienceYears: 0,
            isAvailable: false,
            createdAt: now,
          )
        : null;
    await _clinic.registerUser(user, doctor: doctor);
    _registered[input.email] = user;
    return user;
  }

  @override
  Future<void> logout() async {}
}
