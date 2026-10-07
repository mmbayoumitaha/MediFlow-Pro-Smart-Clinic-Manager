import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/features/auth/data/demo_auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_repository.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/appointment_policy.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/domain/manage_profiles.dart';
import 'package:mediflow/features/clinic/domain/profile_policy.dart';
import 'package:mediflow/features/clinic/presentation/profile_view_model.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  late DemoClinicRepository repository;
  final patient = DemoFixtures.generatePatients(at: now).first;
  final doctor = DemoFixtures.generateDoctors().first;
  final admin = patient.copyWith(id: 'admin', role: UserRole.admin);
  final owner = patient.copyWith(id: doctor.userId, role: UserRole.doctor);
  setUp(() => repository = DemoClinicRepository(at: now));
  tearDown(() => repository.dispose());
  Matcher fails(FailureCode code) =>
      throwsA(isA<ClinicFailure>().having((e) => e.code, 'code', code));
  DoctorInput input(
    Doctor d, {
    String? name,
    String? email,
    double? fee,
    int? years,
    bool? available,
    List<AvailabilitySlot>? periods,
  }) => DoctorInput(
    fullName: name ?? d.fullName,
    email: email ?? d.email,
    phone: d.phone,
    bio: d.bio,
    specialty: d.specialty,
    consultationFee: fee ?? d.consultationFee,
    experienceYears: years ?? d.experienceYears,
    availability: periods ?? d.availability,
    isAvailable: available ?? d.isAvailable,
  );
  ContactInput contact(
    ClinicUser p, {
    String? name,
    String? address,
    bool? active,
  }) => ContactInput(
    fullName: name ?? p.fullName,
    phone: p.phone,
    address: address,
    isActive: active ?? p.isActive,
  );

  test('patient edits are trimmed, nullable address clears and historical names remain', () async {
    final before = await repository.load();
    final updated = await repository.savePatient(
      actor: patient,
      expected: before.patients.first,
      input: contact(patient, name: '  New Patient Name  ', address: '  '),
    );
    expect(updated.fullName, 'New Patient Name');
    expect(updated.address, isNull);
    expect(updated.id, patient.id);
    expect(updated.role, UserRole.patient);
    expect(updated.email, patient.email);
    expect(
      (await repository.load()).appointments.first.patientName,
      before.appointments.first.patientName,
    );
    await expectLater(
      repository.savePatient(
        actor: patient,
        expected: patient,
        input: contact(patient, name: 'Overwrite'),
      ),
      fails(FailureCode.conflict),
    );
  });
  test('foreign actors, self-reactivation, missing and inactive identities fail closed', () async {
    final other = DemoFixtures.generatePatients(at: now)[1];
    for (final actor in [other, owner, patient.copyWith(isActive: false)]) {
      await expectLater(
        repository.savePatient(
          actor: actor,
          expected: patient,
          input: contact(patient),
        ),
        fails(FailureCode.unauthorized),
      );
    }
    final inactive = await repository.savePatient(
      actor: admin,
      expected: patient,
      input: contact(patient, active: false),
    );
    await expectLater(
      repository.savePatient(
        actor: patient,
        expected: inactive,
        input: contact(patient, active: true),
      ),
      fails(FailureCode.unauthorized),
    );
    await expectLater(
      repository.removePatient(actor: patient, expected: patient),
      fails(FailureCode.unauthorized),
    );
    await expectLater(
      repository.savePatient(
        actor: admin,
        expected: patient.copyWith(id: 'missing'),
        input: contact(patient),
      ),
      fails(FailureCode.notFound),
    );
  });
  test('registered patient login reflects edits and refuses deleted or inactive records', () async {
    var ids = 0;
    final auth = DemoAuthRepository(
      repository,
      now: () => now,
      newId: () => 'registered-${++ids}',
    );
    final user = await auth.register(
      const RegistrationInput(
        fullName: 'New Patient',
        email: 'new@example.com',
        password: 'dummy123',
        phone: '+201111222333',
        role: UserRole.patient,
      ),
    );
    await repository.savePatient(
      actor: user,
      expected: user,
      input: contact(user, name: 'Updated Patient'),
    );
    expect(
      (await auth.login(user.email, 'dummy123', UserRole.admin)).fullName,
      'Updated Patient',
    );
    final latest = (await repository.load()).patients.singleWhere(
      (p) => p.id == user.id,
    );
    await repository.removePatient(actor: admin, expected: latest);
    await expectLater(
      auth.login(user.email, 'dummy123', UserRole.admin),
      fails(FailureCode.notFound),
    );
  });
  test('administrator creates linked doctor identity with unique email and zero inherited reviews', () async {
    final d = await repository.saveDoctor(
      actor: admin,
      input: input(doctor, email: '  new@clinic.com ', name: '  New Doctor '),
      newDoctorId: 'new-doctor',
      newUserId: 'new-user',
    );
    expect(d.userId, 'new-user');
    expect(d.fullName, 'New Doctor');
    expect(d.email, 'new@clinic.com');
    expect(d.rating, 0);
    expect(d.totalReviews, 0);
    final auth = DemoAuthRepository(
      repository,
      now: () => now,
      newId: () => 'unused',
    );
    final signed = await auth.login(d.email, 'dummy123', UserRole.patient);
    expect(signed.id, d.userId);
    expect(signed.role, UserRole.doctor);
    await expectLater(
      repository.saveDoctor(
        actor: admin,
        input: input(doctor, email: d.email),
        newDoctorId: 'other',
        newUserId: 'other-user',
      ),
      fails(FailureCode.conflict),
    );
    await expectLater(
      repository.saveDoctor(
        actor: patient,
        input: input(doctor, email: 'p@clinic.com'),
        newDoctorId: 'p-doc',
        newUserId: 'p-user',
      ),
      fails(FailureCode.unauthorized),
    );
    await repository.removeDoctor(actor: admin, expected: d);
    await expectLater(
      auth.login(d.email, 'dummy123', UserRole.doctor),
      fails(FailureCode.notFound),
    );
  });
  test('doctor edits preserve identity, fee snapshots and reject stale/foreign edits', () async {
    final current = (await repository.load()).doctors.first;
    final updated = await repository.saveDoctor(
      actor: owner,
      expected: current,
      input: input(current, name: 'Updated Doctor', fee: 123.45),
    );
    expect(updated.userId, doctor.userId);
    expect(updated.rating, doctor.rating);
    expect((await repository.load()).appointments.first.fee, 350);
    await expectLater(
      repository.saveDoctor(
        actor: owner,
        expected: current,
        input: input(current),
      ),
      fails(FailureCode.conflict),
    );
    await expectLater(
      repository.saveDoctor(
        actor: patient,
        expected: updated,
        input: input(updated),
      ),
      fails(FailureCode.unauthorized),
    );
    await expectLater(
      repository.saveDoctor(
        actor: owner,
        expected: updated,
        input: input(updated, email: 'other@clinic.com'),
      ),
      fails(FailureCode.invalidInput),
    );
  });
  test('availability validates periods, preserves future reservations and can disable booking', () async {
    final current = (await repository.load()).doctors.first;
    await expectLater(
      repository.saveDoctor(
        actor: owner,
        expected: current,
        input: input(
          current,
          periods: const [
            AvailabilitySlot(
              day: DayOfWeek.monday,
              startTime: '09:00',
              endTime: '17:00',
            ),
          ],
        ),
      ),
      fails(FailureCode.conflict),
    );
    final disabled = await repository.saveDoctor(
      actor: owner,
      expected: current,
      input: input(current, available: false),
    );
    final snapshot = await repository.load();
    expect(
      AppointmentPolicy.availableSlots(
        snapshot,
        doctor: disabled,
        patientId: patient.id,
        date: DateTime(2026, 10, 6),
        now: now,
      ),
      isEmpty,
    );
    expect(snapshot.appointments, hasLength(8));
    final empty = input(current, available: true, periods: const []);
    expect(() => ProfilePolicy.doctor(empty), throwsA(isA<ClinicFailure>()));
    for (final period in [
      const AvailabilitySlot(
        day: DayOfWeek.monday,
        startTime: '24:00',
        endTime: '25:00',
      ),
      const AvailabilitySlot(
        day: DayOfWeek.monday,
        startTime: '17:00',
        endTime: '09:00',
      ),
      const AvailabilitySlot(
        day: DayOfWeek.monday,
        startTime: '09:00',
        endTime: '09:15',
      ),
    ]) {
      expect(
        () => ProfilePolicy.doctor(input(current, periods: [period])),
        throwsA(isA<ClinicFailure>()),
      );
    }
    expect(
      () => ProfilePolicy.doctor(
        input(
          current,
          periods: [current.availability.first, current.availability.first],
        ),
      ),
      throwsA(isA<ClinicFailure>()),
    );
    for (final fee in [-1.0, double.nan, 1.001]) {
      expect(
        () => ProfilePolicy.doctor(input(current, fee: fee)),
        throwsA(isA<ClinicFailure>()),
      );
    }
    expect(
      () => ProfilePolicy.doctor(input(current, years: -1)),
      throwsA(isA<ClinicFailure>()),
    );
  });
  test('profiles linked to clinic records cannot be deleted; unlinked patient can be removed', () async {
    await expectLater(
      repository.removePatient(actor: admin, expected: patient),
      fails(FailureCode.conflict),
    );
    await expectLater(
      repository.removeDoctor(
        actor: admin,
        expected: (await repository.load()).doctors.first,
      ),
      fails(FailureCode.conflict),
    );
    final unused = patient.copyWith(id: 'unused', email: 'unused@example.com');
    await repository.registerUser(unused);
    await repository.removePatient(actor: admin, expected: unused);
    expect(
      (await repository.load()).patients.any((p) => p.id == unused.id),
      isFalse,
    );
    expect((await repository.load()).appointments, hasLength(8));
    for (final name in ['', '  ', 'ab']) {
      expect(
        () => ProfilePolicy.contact(name, patient.phone),
        throwsA(isA<ClinicFailure>()),
      );
    }
  });
  test('competing edits cannot overwrite each other even at the same clock instant', () async {
    final current = (await repository.load()).doctors.first;
    final attempts = [
      repository.saveDoctor(
        actor: admin,
        expected: current,
        input: input(current, name: 'First Doctor'),
      ),
      repository.saveDoctor(
        actor: admin,
        expected: current,
        input: input(current, name: 'Second Doctor'),
      ),
    ];
    final outcomes = await Future.wait(
      attempts.map((f) async {
        try {
          await f;
          return true;
        } on ClinicFailure catch (e) {
          expect(e.code, FailureCode.conflict);
          return false;
        }
      }),
    );
    expect(outcomes.where((v) => v), hasLength(1));
    expect((await repository.load()).doctors.first.fullName, 'First Doctor');
  });
  test('running identity follows profile updates and deactivation clears visible reads', () async {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login('demo@mediflow.com', 'dummy123', UserRole.patient);
    await container.read(clinicViewModelProvider.notifier).refresh();
    final repo = container.read(clinicRepositoryProvider);
    final current = (await repo.load()).patients.first;
    final updated = await repo.savePatient(
      actor: current,
      expected: current,
      input: contact(current, name: 'Changed Patient'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authProvider).currentUser!.fullName,
      updated.fullName,
    );
    await repo.savePatient(
      actor: admin,
      expected: updated,
      input: contact(updated, active: false),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(appointmentsProvider), isEmpty);
    await container
        .read(authProvider.notifier)
        .login(current.email, 'dummy123', UserRole.patient);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });
  test('profile view model prevents duplicate actions and ignores disposed completions', () async {
    final mock = MockClinicRepository();
    final pending = Completer<ClinicUser>();
    final details = contact(patient, name: 'Updated Name');
    when(
      mock.savePatient(
        actor: anyNamed('actor'),
        expected: anyNamed('expected'),
        input: anyNamed('input'),
      ),
    ).thenAnswer((_) => pending.future);
    final model = ProfileViewModel(
      ManageProfiles(mock, () => 'new'),
      () => patient,
    );
    final update = model.patient(patient, details);
    expect(model.state.isSubmitting, isTrue);
    expect(await model.patient(patient, details), isFalse);
    model.dispose();
    pending.complete(patient);
    expect(await update, isFalse);
    verify(mock.savePatient(actor: patient, expected: patient, input: details))
        .called(1);
  });
}
