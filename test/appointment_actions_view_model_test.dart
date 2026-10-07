import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/change_appointment_status.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/presentation/appointment_actions_view_model.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final visit = DemoFixtures.generateAppointments().first;
  final user = DemoFixtures.generatePatients().first;
  late MockClinicRepository repository;
  setUp(() => repository = MockClinicRepository());
  void stub(Future<Appointment> Function() answer) => when(
    repository.changeAppointmentStatus(
      actor: anyNamed('actor'),
      appointmentId: anyNamed('appointmentId'),
      expected: anyNamed('expected'),
      target: anyNamed('target'),
    ),
  ).thenAnswer((_) => answer());

  test('missing/inactive actors never reach the repository', () async {
    for (final actor in [null, user.copyWith(isActive: false)]) {
      final model = AppointmentActionsViewModel(
        ChangeAppointmentStatus(repository),
        () => actor,
      );
      expect(await model.change(visit, AppointmentStatus.cancelled), isFalse);
      expect(model.state.error, 'Sign in to change an appointment.');
      model.dispose();
    }
    verifyZeroInteractions(repository);
  });
  test('commands preserve expected status, lock repeated submissions and clear busy state', () async {
    final pending = Completer<Appointment>();
    stub(() => pending.future);
    final model = AppointmentActionsViewModel(
      ChangeAppointmentStatus(repository),
      () => user,
    );
    addTearDown(model.dispose);
    final change = model.change(visit, AppointmentStatus.cancelled);
    expect(model.state.busyId, visit.id);
    expect(await model.change(visit, AppointmentStatus.cancelled), isFalse);
    pending.complete(visit.copyWith(status: AppointmentStatus.cancelled));
    expect(await change, isTrue);
    expect(model.state.busyId, isNull);
    verify(
      repository.changeAppointmentStatus(
        actor: user,
        appointmentId: visit.id,
        expected: visit.status,
        target: AppointmentStatus.cancelled,
      ),
    ).called(1);
  });
  test('conflict errors stay actionable and unexpected failures hide internal details', () async {
    stub(
      () => Future.error(
        const ClinicFailure(FailureCode.conflict, 'Refresh and retry.'),
      ),
    );
    final model = AppointmentActionsViewModel(
      ChangeAppointmentStatus(repository),
      () => user,
    );
    addTearDown(model.dispose);
    expect(await model.change(visit, AppointmentStatus.cancelled), isFalse);
    expect(model.state.error, 'Refresh and retry.');
    stub(() => Future.error(Exception('internal server path')));
    expect(await model.change(visit, AppointmentStatus.cancelled), isFalse);
    expect(
      model.state.error,
      'Could not update the appointment. Please try again.',
    );
  });
  test('disposed view model ignores an old status completion', () async {
    final pending = Completer<Appointment>();
    stub(() => pending.future);
    final model = AppointmentActionsViewModel(
      ChangeAppointmentStatus(repository),
      () => user,
    );
    final change = model.change(visit, AppointmentStatus.cancelled);
    model.dispose();
    pending.complete(visit);
    expect(await change, isFalse);
  });
}
