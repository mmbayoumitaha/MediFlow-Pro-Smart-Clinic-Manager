import 'dart:async';

import '../domain/app_enums.dart';
import '../domain/clinic_failure.dart';
import '../domain/clinic_repository.dart';
import '../domain/clinic_snapshot.dart';
import '../domain/entities.dart';
import 'demo_fixtures.dart';

/// Isolated, session-only data. The entire fixture set shares one seed clock.
class DemoClinicRepository implements ClinicRepository {
  final _changes = StreamController<ClinicSnapshot>.broadcast(sync: true);
  late ClinicSnapshot _snapshot;
  bool _disposed = false;

  DemoClinicRepository({required DateTime at}) {
    _snapshot = ClinicSnapshot(
      doctors: DemoFixtures.generateDoctors(),
      patients: DemoFixtures.generatePatients(at: at),
      appointments: DemoFixtures.generateAppointments(at: at),
      prescriptions: DemoFixtures.generatePrescriptions(at: at),
      invoices: DemoFixtures.generateInvoices(at: at),
    );
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'Demo session is closed.',
      );
    }
  }

  @override
  Future<ClinicSnapshot> load() async {
    _ensureOpen();
    return _snapshot;
  }

  @override
  Stream<ClinicSnapshot> watch() => Stream.multi((controller) {
    if (_disposed) {
      controller.addError(
        const ClinicFailure(FailureCode.unavailable, 'Demo session is closed.'),
      );
      controller.close();
      return;
    }
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_snapshot);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> registerUser(ClinicUser user, {Doctor? doctor}) async {
    _ensureOpen();
    final duplicate =
        _snapshot.patients.any(
          (p) =>
              p.id == user.id ||
              p.email.toLowerCase() == user.email.toLowerCase(),
        ) ||
        _snapshot.doctors.any(
          (d) =>
              d.userId == user.id ||
              d.email.toLowerCase() == user.email.toLowerCase(),
        );
    if (duplicate) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'A demo account already uses this email or ID.',
      );
    }
    if (user.role == UserRole.patient && doctor == null) {
      _publish(_snapshot.copyWith(patients: [..._snapshot.patients, user]));
    } else if (user.role == UserRole.doctor &&
        doctor != null &&
        doctor.userId == user.id &&
        doctor.email == user.email &&
        !_snapshot.doctors.any((d) => d.id == doctor.id)) {
      _publish(_snapshot.copyWith(doctors: [..._snapshot.doctors, doctor]));
    } else {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Registration requires a matching patient or doctor profile.',
      );
    }
  }

  @override
  Future<void> bookAppointment(Appointment appointment) async {
    _ensureOpen();
    if (_snapshot.appointments.any((a) => a.id == appointment.id)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This appointment already exists.',
      );
    }
    if (!_snapshot.patients.any((p) => p.id == appointment.patientId) ||
        !_snapshot.doctors.any((d) => d.id == appointment.doctorId)) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Patient or doctor no longer exists.',
      );
    }
    _publish(
      _snapshot.copyWith(
        appointments: [appointment, ..._snapshot.appointments],
      ),
    );
  }

  void _publish(ClinicSnapshot snapshot) {
    _snapshot = snapshot;
    _changes.add(snapshot);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _changes.close();
  }
}
