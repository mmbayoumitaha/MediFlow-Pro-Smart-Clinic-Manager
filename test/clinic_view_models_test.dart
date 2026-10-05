import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/clinic_queries.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/presentation/booking_view_model.dart';
import 'package:mediflow/features/clinic/presentation/clinic_view_model.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  final snapshot = ClinicSnapshot(
    doctors: DemoFixtures.generateDoctors(),
    patients: DemoFixtures.generatePatients(at: now),
    appointments: DemoFixtures.generateAppointments(at: now),
    invoices: DemoFixtures.generateInvoices(at: now),
  );
  late MockClinicRepository repository;

  setUp(() {
    repository = MockClinicRepository();
    when(repository.load()).thenAnswer((_) async => snapshot);
    when(repository.bookAppointment(any)).thenAnswer((_) async {});
  });

  BookAppointment booking() => BookAppointment(
    repository,
    now: () => now,
    newId: () => 'new-appointment',
  );

  test(
    'booking uses current doctor data, selected time and injected clock/ID',
    () async {
      final updated = snapshot.copyWith(
        doctors: [snapshot.doctors.first.copyWith(consultationFee: 125)],
      );
      when(repository.load()).thenAnswer((_) async => updated);
      final selected = DateTime(2026, 10, 6, 13, 30);
      final result = await booking()(
        patient: snapshot.patients.first,
        doctorId: updated.doctors.first.id,
        dateTime: selected,
        reason: '  Consultation  ',
      );
      expect(result.dateTime, selected);
      expect(result.id, 'new-appointment');
      expect(result.createdAt, now);
      expect(result.fee, 125);
      expect(result.reason, 'Consultation');
      final persisted =
          verify(repository.bookAppointment(captureAny)).captured.single
              as Appointment;
      expect(persisted, same(result));
    },
  );

  test(
    'booking rejects missing, inactive and non-patient identities',
    () async {
      for (final user in [
        null,
        snapshot.patients.first.copyWith(isActive: false),
        snapshot.patients.first.copyWith(role: UserRole.admin),
      ]) {
        await expectLater(
          booking()(
            patient: user,
            doctorId: 'doc-001',
            dateTime: now.add(const Duration(days: 1)),
          ),
          throwsA(
            isA<ClinicFailure>().having(
              (e) => e.code,
              'code',
              FailureCode.unauthorized,
            ),
          ),
        );
      }
      verifyNever(repository.load());
      verifyNever(repository.bookAppointment(any));
    },
  );

  test(
    'booking rejects past dates and missing or unavailable doctors',
    () async {
      await expectLater(
        booking()(
          patient: snapshot.patients.first,
          doctorId: 'missing',
          dateTime: now.add(const Duration(days: 1)),
        ),
        throwsA(
          isA<ClinicFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.notFound,
          ),
        ),
      );
      await expectLater(
        booking()(
          patient: snapshot.patients.first,
          doctorId: 'doc-001',
          dateTime: now,
        ),
        throwsA(
          isA<ClinicFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.invalidInput,
          ),
        ),
      );
      when(repository.load()).thenAnswer(
        (_) async => snapshot.copyWith(
          doctors: [snapshot.doctors.first.copyWith(isAvailable: false)],
        ),
      );
      await expectLater(
        booking()(
          patient: snapshot.patients.first,
          doctorId: 'doc-001',
          dateTime: now.add(const Duration(days: 1)),
        ),
        throwsA(
          isA<ClinicFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.unavailable,
          ),
        ),
      );
      verifyNever(repository.bookAppointment(any));
    },
  );

  test('booking view model blocks duplicate submission until persistence completes', () async {
    final pending = Completer<void>();
    when(repository.bookAppointment(any)).thenAnswer((_) => pending.future);
    final model = BookingViewModel(booking(), () => snapshot.patients.first);
    addTearDown(model.dispose);
    final first = model.book(
      doctorId: 'doc-001',
      dateTime: now.add(const Duration(days: 1)),
      reason: '   ',
    );
    expect(model.state.isSubmitting, isTrue);
    expect(
      await model.book(
        doctorId: 'doc-001',
        dateTime: now.add(const Duration(days: 1)),
      ),
      isFalse,
    );
    pending.complete();
    expect(await first, isTrue);
    expect(model.state.appointment!.reason, isNull);
    expect(model.state.isSubmitting, isFalse);
    verify(repository.bookAppointment(any)).called(1);
  });

  test('booking errors are visible and disposal ignores a late response', () async {
    when(repository.bookAppointment(any)).thenThrow(
      const ClinicFailure(FailureCode.conflict, 'Reservation failed.'),
    );
    final model = BookingViewModel(booking(), () => snapshot.patients.first);
    expect(
      await model.book(
        doctorId: 'doc-001',
        dateTime: now.add(const Duration(days: 1)),
      ),
      isFalse,
    );
    expect(model.state.error, 'Reservation failed.');
    final pending = Completer<void>();
    when(repository.bookAppointment(any)).thenAnswer((_) => pending.future);
    final request = model.book(
      doctorId: 'doc-001',
      dateTime: now.add(const Duration(days: 1)),
    );
    // Allow the use case to reach the pending write before disposing the view.
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    pending.complete();
    expect(await request, isFalse);
  });

  test('clinic view model handles loading, stream errors and retry', () async {
    final stream = StreamController<ClinicSnapshot>.broadcast(sync: true);
    when(repository.watch()).thenAnswer((_) => stream.stream);
    final model = ClinicViewModel(repository);
    addTearDown(() async {
      model.dispose();
      await stream.close();
    });
    expect(model.state, isA<AsyncLoading<ClinicSnapshot>>());
    stream.add(snapshot);
    expect(model.state.valueOrNull, same(snapshot));
    stream.addError(StateError('lost connection'), StackTrace.current);
    expect(model.state.hasError, isTrue);
    expect(model.state.valueOrNull, same(snapshot));
    await model.refresh();
    expect(model.state.hasError, isFalse);
    expect(model.state.valueOrNull, same(snapshot));
    verify(repository.load()).called(1);
  });

  test('a stale refresh cannot overwrite a newer repository event', () async {
    final stream = StreamController<ClinicSnapshot>.broadcast(sync: true);
    when(repository.watch()).thenAnswer((_) => stream.stream);
    final pending = Completer<ClinicSnapshot>();
    when(repository.load()).thenAnswer((_) => pending.future);
    final model = ClinicViewModel(repository);
    addTearDown(() async {
      model.dispose();
      await stream.close();
    });
    stream.add(snapshot);
    final refresh = model.refresh();
    expect(model.state.isLoading, isTrue);
    expect(model.state.valueOrNull, same(snapshot));
    final newer = snapshot.copyWith(appointments: []);
    stream.add(newer);
    pending.complete(snapshot);
    await refresh;
    expect(model.state.valueOrNull, same(newer));
  });

  test(
    'load failures retain prior data and disposed models cancel subscriptions',
    () async {
      final stream = StreamController<ClinicSnapshot>.broadcast(sync: true);
      when(repository.watch()).thenAnswer((_) => stream.stream);
      when(repository.load()).thenThrow(StateError('load failed'));
      final model = ClinicViewModel(repository);
      stream.add(snapshot);
      await model.refresh();
      expect(model.state.hasError, isTrue);
      expect(model.state.valueOrNull, same(snapshot));
      model.dispose();
      expect(stream.hasListener, isFalse);
      await stream.close();
    },
  );

  test('queries sort copies, filter names/specialties and expose immutable results', () {
    final original = snapshot.appointments.map((a) => a.id).toList();
    final schedule = ClinicQueries.schedule(snapshot.appointments);
    expect(schedule.first.dateTime.isBefore(schedule.last.dateTime), isTrue);
    expect(snapshot.appointments.map((a) => a.id), original);
    expect(() => schedule.clear(), throwsUnsupportedError);
    expect(
      ClinicQueries.doctors(snapshot.doctors, null, '  AHMED  ').single.id,
      'doc-001',
    );
    expect(
      ClinicQueries.doctors(
        snapshot.doctors,
        MedicalSpecialty.gynecology,
        '',
      ).single.id,
      'doc-006',
    );
    expect(ClinicQueries.dateOptions(now).first, DateTime(2026, 10, 6));
    expect(ClinicMetrics(snapshot, now).paidInvoiceRevenue, 1083);
  });
}
