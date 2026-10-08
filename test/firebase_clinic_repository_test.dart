import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';
import 'package:mediflow/core/firebase/clinic_commands.dart';
import 'package:mediflow/features/auth/domain/auth_session.dart';
import 'package:mediflow/features/clinic/data/clinic_mapper.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/data/firebase_clinic_mapper.dart';
import 'package:mediflow/features/clinic/data/firebase_clinic_records.dart';
import 'package:mediflow/features/clinic/data/firebase_clinic_repository.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/presentation/clinic_view_model.dart';

class SessionsFake implements AuthSessionSource {
  final events = StreamController<AuthSession>.broadcast(sync: true);
  @override
  Stream<AuthSession> watchSession() => events.stream;
  void publish(ClinicUser? user) => events.add(AuthSession(user: user));
}

class RecordsFake implements ClinicRecords {
  final streams = <String, List<StreamController<ClinicSnapshot>>>{};
  final actors = <ClinicUser>[];
  Future<ClinicSnapshot> Function(ClinicUser)? reading;
  ClinicSnapshot snapshot = ClinicSnapshot();
  @override
  Future<ClinicSnapshot> read(ClinicUser user) async =>
      reading == null ? snapshot : reading!(user);
  @override
  Stream<ClinicSnapshot> watch(ClinicUser user) {
    actors.add(user);
    final controller = StreamController<ClinicSnapshot>.broadcast(sync: true);
    streams.putIfAbsent(user.id, () => []).add(controller);
    return controller.stream;
  }

  StreamController<ClinicSnapshot> stream(String id) => streams[id]!.last;
  Future<void> close() async {
    for (final list in streams.values) {
      for (final controller in list) {
        await controller.close();
      }
    }
  }
}

class CommandsFake implements ClinicCommands {
  final calls = <({String name, Map<String, dynamic> data, String uid})>[];
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? action;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  }) async {
    calls.add((name: name, data: data, uid: expectedUid));
    return action == null ? {} : action!(name, data);
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  final clock = ClinicClock();
  final now = clock.inClinic(DateTime.utc(2026, 10, 5, 6));
  final patient = DemoFixtures.generatePatients(at: now).first;
  final doctor = DemoFixtures.generateDoctors().first;
  final other = patient.copyWith(id: 'other', fullName: 'Other Patient');
  late SessionsFake sessions;
  late RecordsFake records;
  late CommandsFake commands;
  late FirebaseClinicRepository repository;
  late ClinicViewModel model;
  final scoped = ClinicSnapshot(patients: [patient], doctors: [doctor]);
  setUp(() async {
    sessions = SessionsFake();
    records = RecordsFake();
    commands = CommandsFake();
    repository = FirebaseClinicRepository(
      sessions,
      records,
      commands,
      FirebaseClinicMapper(clock),
      clock,
    );
    model = ClinicViewModel(repository);
    sessions.publish(patient);
    records.snapshot = scoped;
    records.stream(patient.id).add(scoped);
    await flush();
  });
  tearDown(() async {
    model.dispose();
    repository.dispose();
    await sessions.events.close();
    await records.close();
  });
  test('account changes clear previous records and reject an old read and write acknowledgement', () async {
    final read = Completer<ClinicSnapshot>(),
        write = Completer<Map<String, dynamic>>();
    records.reading = (_) => read.future;
    commands.action = (_, _) => write.future;
    final oldRead = repository.load();
    final readExpectation = expectLater(oldRead, throwsA(isA<ClinicFailure>()));
    final oldWrite = repository.availableSlots(doctorId: doctor.id, date: now);
    final writeExpectation = expectLater(
      oldWrite,
      throwsA(isA<ClinicFailure>()),
    );
    expect(commands.calls.single.uid, patient.id);
    sessions.publish(other);
    await flush();
    expect(model.state.valueOrNull!.patients, isEmpty);
    records.stream(patient.id).add(scoped);
    read.complete(scoped);
    write.complete({'zone': ClinicClock.zone, 'startMillis': []});
    await readExpectation;
    await writeExpectation;
    await flush();
    expect(model.state.valueOrNull!.patients, isEmpty);
    final next = ClinicSnapshot(patients: [other]);
    records.stream(other.id).add(next);
    await flush();
    expect(model.state.valueOrNull!.patients.single.id, other.id);
    sessions.publish(null);
    await flush();
    expect(model.state.valueOrNull!.patients, isEmpty);
    await expectLater(repository.load(), throwsA(isA<ClinicFailure>()));
  });
  test('same-account contact changes preserve reads; role changes start a new scope', () async {
    sessions.publish(patient.copyWith(fullName: 'Updated Patient'));
    expect(records.actors, hasLength(1));
    sessions.publish(patient.copyWith(role: UserRole.doctor));
    await flush();
    expect(records.actors.map((user) => user.role), [
      UserRole.patient,
      UserRole.doctor,
    ]);
    expect(model.state.valueOrNull!.patients, isEmpty);
    expect(records.stream(patient.id).hasListener, isTrue);
  });
  test('query errors remove previously visible records and refresh restarts subscriptions', () async {
    records.stream(patient.id).addError(StateError('private database details'));
    await flush();
    expect(model.state.hasError, isTrue);
    expect(model.state.valueOrNull!.patients, isEmpty);
    expect(
      model.state.error.toString(),
      isNot(contains('private database details')),
    );
    final later = ClinicViewModel(repository);
    await flush();
    expect(later.state.hasError, isTrue);
    expect(later.state.valueOrNull!.patients, isEmpty);
    later.dispose();
    await model.refresh();
    expect(records.actors, hasLength(2));
    records.stream(patient.id).add(scoped);
    await flush();
    expect(model.state.hasError, isFalse);
    expect(model.state.valueOrNull!.patients.single.id, patient.id);
  });
  test(
    'failed server reads and session errors also clear data and fail closed',
    () async {
      records.reading = (_) => Future.error(StateError('read access lost'));
      await model.refresh();
      await flush();
      expect(model.state.hasError, isTrue);
      expect(model.state.valueOrNull!.patients, isEmpty);
      records.stream(patient.id).add(scoped);
      await flush();
      sessions.events.addError(StateError('identity stream failed'));
      await flush();
      expect(model.state.hasError, isTrue);
      expect(model.state.valueOrNull!.patients, isEmpty);
      await expectLater(
        repository.availableSlots(doctorId: doctor.id, date: now),
        throwsA(isA<ClinicFailure>()),
      );
      expect(commands.calls, isEmpty);
    },
  );
  test('availability sends calendar dates and preserves clinic instants, with malformed results rejected', () async {
    final instant = DateTime.utc(2026, 10, 6, 8).millisecondsSinceEpoch;
    commands.action = (_, _) async => {
      'zone': ClinicClock.zone,
      'startMillis': [instant.toDouble()],
    };
    final slots = await repository.availableSlots(
      doctorId: doctor.id,
      date: DateTime(2026, 10, 6),
    );
    expect(commands.calls.single.data, {
      'doctorId': doctor.id,
      'date': '2026-10-06',
    });
    expect(slots.single.millisecondsSinceEpoch, instant);
    expect(slots.single.hour, 11);
    for (final invalid in [
      {
        'zone': 'UTC',
        'startMillis': [instant],
      },
      {
        'zone': ClinicClock.zone,
        'startMillis': [instant + 0.5],
      },
    ]) {
      commands.action = (_, _) async => invalid;
      await expectLater(
        repository.availableSlots(doctorId: doctor.id, date: now),
        throwsA(isA<ClinicFailure>()),
      );
    }
  });
  test('booking trusts server slot validation and returns canonical data, including an existing-ID retry', () async {
    // Only the server sees other patients' reservations. A device calendar at
    // 01:00 is deliberately outside local working periods; UTC epoch is sent.
    final at = DateTime.utc(2026, 10, 6, 1);
    late Appointment canonical;
    commands.action = (name, data) async {
      expect(name, 'bookAppointment');
      expect(data['startMillis'], at.millisecondsSinceEpoch);
      expect(data['expectedFee'], doctor.consultationFee);
      canonical = Appointment(
        id: data['requestId'] as String,
        patientId: patient.id,
        patientName: 'Trusted Server Name',
        doctorId: doctor.id,
        doctorName: doctor.fullName,
        specialty: doctor.specialty,
        dateTime: at,
        status: AppointmentStatus.confirmed,
        fee: doctor.consultationFee,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      );
      return ClinicMapper.appointmentToMap(canonical);
    };
    final book = BookAppointment(
      repository,
      now: () => now,
      newId: () => 'request',
    );
    final result = await book(
      patient: patient,
      doctorId: doctor.id,
      dateTime: at,
    );
    expect(result.patientName, 'Trusted Server Name');
    expect(result.status, AppointmentStatus.confirmed);
    records.snapshot = scoped.copyWith(appointments: [canonical]);
    expect(
      (await book(
        patient: patient,
        doctorId: doctor.id,
        dateTime: at,
        requestId: 'request',
      )).status,
      AppointmentStatus.confirmed,
    );
    expect(commands.calls.map((call) => call.data['requestId']), [
      'request',
      'request',
    ]);
    await expectLater(
      repository.reserve(canonical.copyWith(patientId: other.id)),
      throwsA(isA<ClinicFailure>()),
    );
  });
  test(
    'mutations bind actor identity and disposal cancels all sources',
    () async {
      await expectLater(
        repository.changeAppointmentStatus(
          actor: other,
          appointmentId: 'visit',
          expected: AppointmentStatus.pending,
          target: AppointmentStatus.confirmed,
        ),
        throwsA(isA<ClinicFailure>()),
      );
      expect(commands.calls, isEmpty);
      repository.dispose();
      await flush();
      expect(sessions.events.hasListener, isFalse);
      expect(records.stream(patient.id).hasListener, isFalse);
      await expectLater(repository.load(), throwsA(isA<ClinicFailure>()));
      expect(await repository.watch().toList(), isEmpty);
    },
  );
}
