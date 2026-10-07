import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/appointment_lifecycle.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/clinic/domain/change_appointment_status.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/clinic_queries.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  final seed = DateTime(2026, 10, 5, 9);
  final at = DateTime(2026, 10, 6, 13, 30);
  final source = ClinicSnapshot(
    doctors: DemoFixtures.generateDoctors(),
    patients: DemoFixtures.generatePatients(at: seed),
    appointments: DemoFixtures.generateAppointments(at: seed),
  );
  final patient = source.patients.first;
  final doctor = patient.copyWith(
    id: source.doctors.first.userId,
    role: UserRole.doctor,
  );
  final admin = patient.copyWith(id: 'admin-001', role: UserRole.admin);
  Matcher failure(FailureCode code) =>
      isA<ClinicFailure>().having((e) => e.code, 'code', code);

  for (final actor in [patient, doctor, admin]) {
    test(
      '${actor.role.value} lifecycle covers every status before, at and after the visit',
      () {
        for (final status in AppointmentStatus.values) {
          final visit = source.appointments.first.copyWith(
            status: status,
            dateTime: at,
          );
          for (final time in [
            at.subtract(const Duration(minutes: 1)),
            at,
            at.add(const Duration(minutes: 30)),
          ]) {
            final isStaff = actor.role != UserRole.patient;
            final expected = <AppointmentStatus>{};
            if (status == AppointmentStatus.pending) {
              if (isStaff && !time.isAfter(at)) {
                expected.add(AppointmentStatus.confirmed);
              }
              if (isStaff || time.isBefore(at)) {
                expected.add(AppointmentStatus.cancelled);
              }
              if (isStaff &&
                  !time.isBefore(at.add(const Duration(minutes: 30)))) {
                expected.add(AppointmentStatus.noShow);
              }
            } else if (status == AppointmentStatus.confirmed) {
              if (isStaff && !time.isBefore(at)) {
                expected.add(AppointmentStatus.inProgress);
              }
              if (isStaff || time.isBefore(at)) {
                expected.add(AppointmentStatus.cancelled);
              }
              if (isStaff &&
                  !time.isBefore(at.add(const Duration(minutes: 30)))) {
                expected.add(AppointmentStatus.noShow);
              }
            } else if (status == AppointmentStatus.inProgress &&
                isStaff &&
                !time.isBefore(at)) {
              expected.add(AppointmentStatus.completed);
            }
            expect(
              AppointmentLifecycle.targets(source, actor, visit, time),
              unorderedEquals(expected),
              reason: '$status at $time',
            );
          }
        }
      },
    );
  }

  test('foreign, inactive, missing and ambiguous doctor accounts cannot mutate visits', () {
    final visit = source.appointments.first;
    for (final actor in [
      null,
      source.patients[1],
      patient.copyWith(isActive: false),
      doctor.copyWith(id: source.doctors[1].userId),
      doctor.copyWith(id: 'missing'),
    ]) {
      expect(AppointmentLifecycle.targets(source, actor, visit, seed), isEmpty);
    }
    final ambiguous = source.copyWith(
      doctors: [
        source.doctors.first,
        source.doctors.first.copyWith(id: 'duplicate'),
      ],
    );
    expect(
      AppointmentLifecycle.targets(ambiguous, doctor, visit, seed),
      isEmpty,
    );
    final inactivePatient = source.copyWith(
      patients: [patient.copyWith(isActive: false)],
    );
    expect(
      AppointmentLifecycle.targets(inactivePatient, patient, visit, seed),
      isEmpty,
    );
  });

  test('categories are exhaustive and disjoint across every status and time boundary', () {
    final cases = <Appointment>[];
    for (final status in AppointmentStatus.values) {
      for (final minute in [-1, 0, 1]) {
        cases.add(
          source.appointments.first.copyWith(
            id: '${status.value}-$minute',
            status: status,
            dateTime: at.add(Duration(minutes: minute)),
          ),
        );
      }
    }
    final upcoming = ClinicQueries.upcoming(cases, at);
    final history = ClinicQueries.past(cases, at);
    expect(
      upcoming
          .map((a) => a.id)
          .toSet()
          .intersection(history.map((a) => a.id).toSet()),
      isEmpty,
    );
    expect(
      [...upcoming, ...history].map((a) => a.id),
      unorderedEquals(cases.map((a) => a.id)),
    );
    expect(
      upcoming,
      hasLength(7),
    ); // Active visit, and pending/confirmed at or after now.
    expect(
      history.any(
        (a) =>
            a.status == AppointmentStatus.cancelled && a.dateTime.isAfter(at),
      ),
      isTrue,
    );
    expect(
      ClinicMetrics(ClinicSnapshot(appointments: cases), at).completed,
      hasLength(3),
    );
    expect(() => history.clear(), throwsUnsupportedError);
  });

  test('patient-to-doctor workflow confirms, starts and completes with canonical timestamps', () async {
    var clock = seed;
    final repo = DemoClinicRepository(at: seed, now: () => clock);
    addTearDown(repo.dispose);
    final visit = await BookAppointment(
      repo,
      now: () => clock,
      newId: () => 'workflow',
    )(patient: patient, doctorId: 'doc-001', dateTime: at);
    final before = await repo.load();
    final change = ChangeAppointmentStatus(repo);
    final confirmed = await change(
      actor: doctor,
      appointmentId: visit.id,
      expected: AppointmentStatus.pending,
      target: AppointmentStatus.confirmed,
    );
    expect(confirmed.updatedAt, clock);
    await expectLater(
      change(
        actor: doctor,
        appointmentId: visit.id,
        expected: confirmed.status,
        target: AppointmentStatus.inProgress,
      ),
      throwsA(failure(FailureCode.invalidInput)),
    );
    clock = at;
    final active = await change(
      actor: doctor,
      appointmentId: visit.id,
      expected: confirmed.status,
      target: AppointmentStatus.inProgress,
    );
    final completed = await change(
      actor: doctor,
      appointmentId: visit.id,
      expected: active.status,
      target: AppointmentStatus.completed,
    );
    expect(completed.updatedAt, at);
    final after = await repo.load();
    expect(
      ClinicQueries.upcoming(after.appointments, clock).contains(completed),
      isFalse,
    );
    expect(
      ClinicQueries.past(after.appointments, clock).contains(completed),
      isTrue,
    );
    expect(after.invoices, before.invoices);
    expect(completed.paymentStatus, visit.paymentStatus);
    expect(completed.fee, visit.fee);
    await expectLater(
      change(
        actor: admin,
        appointmentId: visit.id,
        expected: completed.status,
        target: AppointmentStatus.confirmed,
      ),
      throwsA(failure(FailureCode.invalidInput)),
    );
  });

  test('cancellation releases the slot, remains in history, and rejects another patient', () async {
    final repo = DemoClinicRepository(at: seed);
    addTearDown(repo.dispose);
    var ids = 0;
    final book = BookAppointment(
      repo,
      now: () => seed,
      newId: () => 'cancel-${++ids}',
    );
    final visit = await book(
      patient: patient,
      doctorId: 'doc-001',
      dateTime: at,
    );
    await expectLater(
      repo.changeAppointmentStatus(
        actor: source.patients[1],
        appointmentId: visit.id,
        expected: visit.status,
        target: AppointmentStatus.cancelled,
      ),
      throwsA(failure(FailureCode.unauthorized)),
    );
    final cancelled = await repo.changeAppointmentStatus(
      actor: patient,
      appointmentId: visit.id,
      expected: visit.status,
      target: AppointmentStatus.cancelled,
    );
    expect(
      ClinicQueries.past(
        (await repo.load()).appointments,
        seed,
      ).contains(cancelled),
      isTrue,
    );
    final replacement = await book(
      patient: source.patients[1],
      doctorId: 'doc-001',
      dateTime: at,
    );
    expect(replacement.id, isNot(visit.id));
    expect((await repo.load()).appointments, hasLength(10));
  });

  test(
    'no-show requires the scheduled end; patients cannot cancel at the start',
    () async {
      var clock = seed;
      final repo = DemoClinicRepository(at: seed, now: () => clock);
      addTearDown(repo.dispose);
      final visit = await BookAppointment(
        repo,
        now: () => clock,
        newId: () => 'no-show',
      )(patient: patient, doctorId: 'doc-001', dateTime: at);
      clock = at;
      await expectLater(
        repo.changeAppointmentStatus(
          actor: patient,
          appointmentId: visit.id,
          expected: visit.status,
          target: AppointmentStatus.cancelled,
        ),
        throwsA(failure(FailureCode.invalidInput)),
      );
      await expectLater(
        repo.changeAppointmentStatus(
          actor: doctor,
          appointmentId: visit.id,
          expected: visit.status,
          target: AppointmentStatus.noShow,
        ),
        throwsA(failure(FailureCode.invalidInput)),
      );
      clock = at.add(const Duration(minutes: 30));
      final changed = await repo.changeAppointmentStatus(
        actor: admin,
        appointmentId: visit.id,
        expected: visit.status,
        target: AppointmentStatus.noShow,
      );
      expect(changed.status, AppointmentStatus.noShow);
      expect(changed.updatedAt, clock);
    },
  );

  test('competing status updates reject stale state without altering the winning write', () async {
    final repo = DemoClinicRepository(at: seed);
    addTearDown(repo.dispose);
    final visit = await BookAppointment(
      repo,
      now: () => seed,
      newId: () => 'competing',
    )(patient: patient, doctorId: 'doc-001', dateTime: at);
    final outcomes = await Future.wait(
      [AppointmentStatus.confirmed, AppointmentStatus.cancelled].map((
        target,
      ) async {
        try {
          await repo.changeAppointmentStatus(
            actor: doctor,
            appointmentId: visit.id,
            expected: visit.status,
            target: target,
          );
          return true;
        } on ClinicFailure catch (error) {
          expect(error.code, FailureCode.conflict);
          return false;
        }
      }),
    );
    expect(outcomes, [true, false]);
    expect(
      (await repo.load()).appointments
          .singleWhere((a) => a.id == visit.id)
          .status,
      AppointmentStatus.confirmed,
    );
    await expectLater(
      repo.changeAppointmentStatus(
        actor: admin,
        appointmentId: 'missing',
        expected: visit.status,
        target: AppointmentStatus.cancelled,
      ),
      throwsA(failure(FailureCode.notFound)),
    );
  });
}
