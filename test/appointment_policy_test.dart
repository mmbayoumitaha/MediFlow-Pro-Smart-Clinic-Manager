import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/appointment_policy.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  final doctor = DemoFixtures.generateDoctors().first;
  final tuesday = DateTime(2026, 10, 6);
  final source = ClinicSnapshot(
    doctors: DemoFixtures.generateDoctors(),
    patients: DemoFixtures.generatePatients(at: now),
    appointments: DemoFixtures.generateAppointments(at: now),
  );
  Matcher failure(FailureCode code) =>
      isA<ClinicFailure>().having((e) => e.code, 'code', code);

  test('working periods define aligned 30-minute slots with inclusive closing boundary', () {
    final slots = AppointmentPolicy.workingSlots(doctor, tuesday);
    expect(slots, hasLength(12));
    expect(slots.first, DateTime(2026, 10, 6, 9));
    expect(slots.last, DateTime(2026, 10, 6, 14, 30));
    expect(slots.contains(DateTime(2026, 10, 6, 12)), isTrue);
    expect(
      AppointmentPolicy.workingSlots(doctor, DateTime(2026, 10, 7)),
      isEmpty,
    );
    expect(
      AppointmentPolicy.workingSlots(
        doctor.copyWith(isAvailable: false),
        tuesday,
      ),
      isEmpty,
    );
    expect(
      AppointmentPolicy.workingSlots(doctor, DateTime.utc(2026, 10, 6)),
      isEmpty,
    );
    expect(() => slots.clear(), throwsUnsupportedError);
  });

  test('inactive, malformed, reversed and overnight periods fail closed; overlaps deduplicate', () {
    final custom = doctor.copyWith(
      availability: [
        const AvailabilitySlot(
          day: DayOfWeek.tuesday,
          startTime: '09:15',
          endTime: '10:10',
        ),
        const AvailabilitySlot(
          day: DayOfWeek.tuesday,
          startTime: '09:15',
          endTime: '09:45',
        ),
        const AvailabilitySlot(
          day: DayOfWeek.tuesday,
          startTime: '11:00',
          endTime: '12:00',
          isActive: false,
        ),
        for (final pair in [
          ('bad', '12:00'),
          ('24:00', '25:00'),
          ('09:60', '12:00'),
          ('12:00', '11:00'),
          ('23:00', '01:00'),
        ])
          AvailabilitySlot(
            day: DayOfWeek.tuesday,
            startTime: pair.$1,
            endTime: pair.$2,
          ),
      ],
    );
    expect(AppointmentPolicy.workingSlots(custom, tuesday), [
      DateTime(2026, 10, 6, 9, 15),
    ]);
    final midnight = doctor.copyWith(
      availability: [
        const AvailabilitySlot(
          day: DayOfWeek.tuesday,
          startTime: '00:00',
          endTime: '01:00',
        ),
      ],
    );
    expect(AppointmentPolicy.workingSlots(midnight, tuesday), [
      tuesday,
      DateTime(2026, 10, 6, 0, 30),
    ]);
  });

  test('only future slots remain; doctor and patient conflicts both hide intervals', () {
    final slots = AppointmentPolicy.availableSlots(
      source,
      doctor: doctor,
      patientId: 'pat-003',
      date: tuesday,
      now: DateTime(2026, 10, 6, 9),
    );
    expect(slots.contains(DateTime(2026, 10, 6, 9)), isFalse);
    expect(slots.contains(DateTime(2026, 10, 6, 9, 30)), isTrue);
    expect(slots.contains(DateTime(2026, 10, 6, 11)), isFalse);
    final other = source.doctors.singleWhere((d) => d.id == 'doc-004');
    final patientSlots = AppointmentPolicy.availableSlots(
      source,
      doctor: other,
      patientId: 'pat-001',
      date: tuesday,
      now: now,
    );
    expect(patientSlots.contains(DateTime(2026, 10, 6, 11)), isFalse);
    expect(patientSlots.contains(DateTime(2026, 10, 6, 11, 30)), isTrue);
  });

  test('interval overlap handles partial intersections, exact adjacency and every status', () {
    final at = DateTime(2026, 10, 6, 13, 30);
    for (final status in AppointmentStatus.values) {
      final appointment = source.appointments.first.copyWith(
        dateTime: at.add(const Duration(minutes: 15)),
        status: status,
      );
      expect(
        AppointmentPolicy.hasConflict(
          [appointment],
          doctorId: doctor.id,
          patientId: 'pat-005',
          at: at,
        ),
        AppointmentPolicy.reservesTime(status),
      );
    }
    expect(
      AppointmentPolicy.overlaps(
        at,
        30,
        at.add(const Duration(minutes: 30)),
        30,
      ),
      isFalse,
    );
    expect(
      AppointmentPolicy.overlaps(
        at,
        30,
        at.subtract(const Duration(minutes: 30)),
        30,
      ),
      isFalse,
    );
    expect(
      AppointmentPolicy.overlaps(
        at,
        30,
        at.subtract(const Duration(minutes: 15)),
        30,
      ),
      isTrue,
    );
  });

  test('repository validates current patient, duration, time, fee and availability', () async {
    final repo = DemoClinicRepository(at: now);
    addTearDown(repo.dispose);
    final candidate = source.appointments.first.copyWith(
      id: 'invalid',
      status: AppointmentStatus.pending,
      dateTime: DateTime(2026, 10, 6, 13, 30),
    );
    for (final request in [
      candidate.copyWith(durationMinutes: 0),
      candidate.copyWith(durationMinutes: 60),
      candidate.copyWith(dateTime: DateTime(2026, 10, 6, 14, 45)),
      candidate.copyWith(dateTime: DateTime(2026, 10, 6, 15)),
      candidate.copyWith(dateTime: DateTime(2026, 10, 6, 13, 30, 1)),
      candidate.copyWith(dateTime: now),
      candidate.copyWith(dateTime: DateTime(2026, 10, 7, 9)),
      candidate.copyWith(status: AppointmentStatus.completed),
    ]) {
      await expectLater(
        repo.bookAppointment(request),
        throwsA(failure(FailureCode.invalidInput)),
      );
    }
    await expectLater(
      repo.bookAppointment(candidate.copyWith(fee: 1)),
      throwsA(failure(FailureCode.conflict)),
    );
    await repo.registerUser(
      source.patients.first.copyWith(
        id: 'inactive',
        email: 'inactive@example.com',
        isActive: false,
      ),
    );
    await expectLater(
      repo.bookAppointment(candidate.copyWith(patientId: 'inactive')),
      throwsA(failure(FailureCode.unauthorized)),
    );
    expect((await repo.load()).appointments, hasLength(8));
  });

  test('repository rejects doctor conflicts and same-patient appointments with another doctor', () async {
    final repo = DemoClinicRepository(at: now);
    addTearDown(repo.dispose);
    final occupied = source.appointments.first.copyWith(
      id: 'doctor-conflict',
      status: AppointmentStatus.pending,
      patientId: 'pat-002',
    );
    await expectLater(
      repo.bookAppointment(occupied),
      throwsA(failure(FailureCode.conflict)),
    );
    final other = source.doctors.singleWhere((d) => d.id == 'doc-004');
    await expectLater(
      repo.bookAppointment(
        occupied.copyWith(
          id: 'patient-conflict',
          patientId: 'pat-001',
          doctorId: other.id,
          specialty: other.specialty,
          fee: other.consultationFee,
        ),
      ),
      throwsA(failure(FailureCode.conflict)),
    );
    expect((await repo.load()).appointments, hasLength(8));
  });

  test(
    'competing demo reservations are atomic and identical retry publishes once',
    () async {
      final repo = DemoClinicRepository(at: now);
      addTearDown(repo.dispose);
      final first = source.appointments.first.copyWith(
        id: 'first',
        status: AppointmentStatus.pending,
        dateTime: DateTime(2026, 10, 6, 13, 30),
      );
      final second = first.copyWith(id: 'second', patientId: 'pat-002');
      final outcomes = await Future.wait(
        [first, second].map((a) async {
          try {
            await repo.bookAppointment(a);
            return true;
          } on ClinicFailure catch (e) {
            expect(e.code, FailureCode.conflict);
            return false;
          }
        }),
      );
      expect(outcomes, [true, false]);
      final beforeRetry = await repo.load();
      await repo.bookAppointment(
        first.copyWith(createdAt: now.add(const Duration(minutes: 1))),
      );
      expect(await repo.load(), same(beforeRetry));
      await expectLater(
        repo.bookAppointment(first.copyWith(reason: 'changed payload')),
        throwsA(failure(FailureCode.conflict)),
      );
      expect((await repo.load()).appointments, hasLength(9));
    },
  );

  test('retry ID acknowledges the original record and never crosses patient identity', () async {
    var clock = now;
    final repo = DemoClinicRepository(at: now, now: () => clock);
    addTearDown(repo.dispose);
    var ids = 0;
    final book = BookAppointment(
      repo,
      now: () => clock,
      newId: () => 'generated-${++ids}',
    );
    final patient = source.patients.first;
    final at = DateTime(2026, 10, 6, 13, 30);
    final first = await book(
      patient: patient,
      doctorId: doctor.id,
      dateTime: at,
      requestId: 'retry-key',
      reason: '  Checkup  ',
    );
    clock = DateTime(2026, 10, 7);
    final retry = await book(
      patient: patient,
      doctorId: doctor.id,
      dateTime: at,
      requestId: 'retry-key',
      reason: 'Checkup',
    );
    expect(retry.createdAt, first.createdAt);
    expect((await repo.load()).appointments, hasLength(9));
    await expectLater(
      book(
        patient: source.patients[1],
        doctorId: doctor.id,
        dateTime: at,
        requestId: 'retry-key',
        reason: 'Checkup',
      ),
      throwsA(failure(FailureCode.conflict)),
    );
    expect(ids, 0);
  });
}
