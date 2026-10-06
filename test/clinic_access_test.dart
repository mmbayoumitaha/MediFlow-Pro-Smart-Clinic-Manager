import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_access.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  late DemoClinicRepository repository;
  late ClinicSnapshot source;
  setUp(() async {
    repository = DemoClinicRepository(at: DateTime(2026, 10, 6, 9));
    source = await repository.load();
  });
  tearDown(() => repository.dispose());

  test('anonymous and inactive accounts receive no clinic data', () {
    for (final user in [
      null,
      source.patients.first.copyWith(isActive: false),
    ]) {
      final result = ClinicAccess.scope(source, user);
      expect(result.doctors, isEmpty);
      expect(result.patients, isEmpty);
      expect(result.appointments, isEmpty);
      expect(result.prescriptions, isEmpty);
      expect(result.invoices, isEmpty);
    }
  });

  test(
    'every patient sees only their appointments, prescriptions and invoices',
    () {
      for (final patient in source.patients) {
        final result = ClinicAccess.scope(source, patient);
        expect(result.doctors, source.doctors);
        expect(result.patients, [patient]);
        expect(
          result.appointments,
          source.appointments.where((a) => a.patientId == patient.id),
        );
        expect(
          result.prescriptions,
          source.prescriptions.where((p) => p.patientId == patient.id),
        );
        expect(
          result.invoices,
          source.invoices.where((i) => i.patientId == patient.id),
        );
        expect(() => result.appointments.clear(), throwsUnsupportedError);
      }
    },
  );

  test(
    'every doctor scopes through userId, including doctors with no patients',
    () {
      for (final doctor in source.doctors) {
        final user = source.patients.first.copyWith(
          id: doctor.userId,
          role: UserRole.doctor,
        );
        final result = ClinicAccess.scope(source, user);
        final own = source.appointments.where((a) => a.doctorId == doctor.id);
        final ids = own.map((a) => a.patientId).toSet();
        expect(result.doctors, [doctor]);
        expect(result.appointments, own);
        expect(
          result.patients,
          source.patients.where((p) => ids.contains(p.id)),
        );
        expect(
          result.prescriptions,
          source.prescriptions.where((p) => p.doctorId == doctor.id),
        );
        expect(result.invoices, isEmpty);
      }
    },
  );

  test('missing and ambiguous doctor linkage fail closed', () {
    final user = source.patients.first.copyWith(role: UserRole.doctor);
    expect(ClinicAccess.scope(source, user).appointments, isEmpty);
    final doctor = source.doctors.first;
    final ambiguous = source.copyWith(
      doctors: [
        doctor,
        doctor.copyWith(id: 'duplicate-profile'),
      ],
    );
    final result = ClinicAccess.scope(
      ambiguous,
      user.copyWith(id: doctor.userId),
    );
    expect(result.doctors, isEmpty);
    expect(result.patients, isEmpty);
    expect(result.appointments, isEmpty);
  });

  test(
    'new patient has no borrowed history and admin retains clinic totals',
    () {
      final ClinicUser user = source.patients.first.copyWith(id: 'new-account');
      final result = ClinicAccess.scope(source, user);
      expect(result.patients, isEmpty);
      expect(result.appointments, isEmpty);
      expect(result.prescriptions, isEmpty);
      expect(result.invoices, isEmpty);
      expect(
        ClinicAccess.scope(source, user.copyWith(role: UserRole.admin)),
        same(source),
      );
      expect(source.appointments, hasLength(8));
    },
  );
}
