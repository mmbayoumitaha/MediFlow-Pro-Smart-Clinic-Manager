import 'dart:async';

import '../domain/app_enums.dart';
import '../domain/appointment_policy.dart';
import '../domain/appointment_lifecycle.dart';
import '../domain/clinic_failure.dart';
import '../domain/clinic_repository.dart';
import '../domain/clinic_snapshot.dart';
import '../domain/entities.dart';
import '../domain/billing_policy.dart';
import '../domain/profile_policy.dart';
import 'demo_fixtures.dart';

/// Isolated, session-only data. The entire fixture set shares one seed clock.
class DemoClinicRepository implements ClinicRepository {
  final _changes = StreamController<ClinicSnapshot>.broadcast(sync: true);
  late ClinicSnapshot _snapshot;
  bool _disposed = false;
  final DateTime Function() _now;

  DemoClinicRepository({required DateTime at, DateTime Function()? now})
    : _now = now ?? (() => at) {
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
    final existing = _snapshot.appointments.where(
      (a) => a.id == appointment.id,
    );
    if (existing.isNotEmpty) {
      if (AppointmentPolicy.sameRequest(existing.single, appointment)) return;
      throw const ClinicFailure(
        FailureCode.conflict,
        'This appointment already exists.',
      );
    }
    // No await between validation and publication: competing demo reservations
    // are serialized against the latest snapshot. Firebase must use a transaction.
    AppointmentPolicy.validate(_snapshot, appointment, _now());
    _publish(
      _snapshot.copyWith(
        appointments: [
          appointment.copyWith(
            patientName: _snapshot.patients
                .singleWhere((p) => p.id == appointment.patientId)
                .fullName,
            doctorName: _snapshot.doctors
                .singleWhere((d) => d.id == appointment.doctorId)
                .fullName,
          ),
          ..._snapshot.appointments,
        ],
      ),
    );
  }

  void _publish(ClinicSnapshot snapshot) {
    _snapshot = snapshot;
    _changes.add(snapshot);
  }

  @override
  Future<Appointment> changeAppointmentStatus({
    required ClinicUser actor,
    required String appointmentId,
    required AppointmentStatus expected,
    required AppointmentStatus target,
  }) async {
    _ensureOpen();
    final visits = _snapshot.appointments.where((a) => a.id == appointmentId);
    if (visits.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Appointment is unavailable.',
      );
    }
    final now = _now();
    final current = visits.single;
    AppointmentLifecycle.validate(
      _snapshot,
      actor,
      current,
      expected,
      target,
      now,
    );
    final updated = current.copyWith(status: target, updatedAt: now);
    _publish(
      _snapshot.copyWith(
        appointments: _snapshot.appointments
            .map((a) => a.id == appointmentId ? updated : a)
            .toList(),
      ),
    );
    return updated;
  }

  @override
  Future<Invoice> issueAppointmentInvoice({
    required ClinicUser actor,
    required String appointmentId,
    required String invoiceId,
  }) async {
    _ensureOpen();
    BillingPolicy.requireAdmin(actor);
    final existing = _snapshot.invoices.where(
      (i) => i.appointmentId == appointmentId,
    );
    if (existing.length == 1) return existing.single;
    if (existing.length > 1) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This visit has multiple invoices.',
      );
    }
    final visits = _snapshot.appointments.where((a) => a.id == appointmentId);
    if (visits.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Appointment is unavailable.',
      );
    }
    final visit = visits.single;
    if (visit.status != AppointmentStatus.completed ||
        visit.paymentStatus != PaymentStatus.unpaid) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Only an unpaid completed visit can receive a new invoice.',
      );
    }
    if (invoiceId.trim().isEmpty ||
        _snapshot.invoices.any((i) => i.id == invoiceId)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'Invoice ID is unavailable.',
      );
    }
    final now = _now();
    final invoice = Invoice(
      id: invoiceId,
      patientId: visit.patientId,
      patientName: visit.patientName,
      appointmentId: visit.id,
      items: [
        InvoiceItem(
          description: 'Consultation with ${visit.doctorName}',
          unitPrice: visit.fee,
          total: visit.fee,
        ),
      ],
      subtotal: visit.fee,
      total: visit.fee,
      issuedDate: now,
      createdAt: now,
    );
    BillingPolicy.validateInvoice(invoice, now);
    _publish(_snapshot.copyWith(invoices: [invoice, ..._snapshot.invoices]));
    return invoice;
  }

  @override
  Future<Invoice> recordInvoicePayment({
    required ClinicUser actor,
    required String invoiceId,
    required PaymentStatus expected,
    required PaymentStatus target,
    DemoPaymentMethod? method,
  }) async {
    _ensureOpen();
    BillingPolicy.requireAdmin(actor);
    final invoices = _snapshot.invoices.where((i) => i.id == invoiceId);
    if (invoices.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Invoice is unavailable.',
      );
    }
    final invoice = invoices.single;
    final now = _now();
    BillingPolicy.validateTransition(invoice, expected, target, method, now);
    if (invoice.appointmentId != null) {
      final visits = _snapshot.appointments.where(
        (a) => a.id == invoice.appointmentId,
      );
      final linkedInvoices = _snapshot.invoices.where(
        (i) => i.appointmentId == invoice.appointmentId,
      );
      if (visits.length != 1 ||
          visits.single.patientId != invoice.patientId ||
          linkedInvoices.length != 1) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'Invoice appointment linkage is invalid.',
        );
      }
    }
    final updated = invoice.copyWith(
      paymentStatus: target,
      paymentMethod: target == PaymentStatus.paid
          ? method!.name
          : invoice.paymentMethod,
      paidDate: target == PaymentStatus.paid ? now : invoice.paidDate,
    );
    _publish(
      _snapshot.copyWith(
        invoices: _snapshot.invoices
            .map((i) => i.id == invoiceId ? updated : i)
            .toList(),
        appointments: _snapshot.appointments
            .map(
              (a) => a.id == invoice.appointmentId
                  ? a.copyWith(paymentStatus: target, updatedAt: now)
                  : a,
            )
            .toList(),
      ),
    );
    return updated;
  }

  @override
  Future<ClinicUser> savePatient({
    required ClinicUser actor,
    required ClinicUser expected,
    required ContactInput input,
  }) async {
    _ensureOpen();
    ProfilePolicy.active(actor);
    final patients = _snapshot.patients.where((p) => p.id == expected.id);
    if (patients.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Patient is unavailable.',
      );
    }
    final patient = patients.single;
    final admin = actor.role == UserRole.admin;
    if (!admin &&
        (actor.role != UserRole.patient ||
            actor.id != patient.id ||
            !patient.isActive ||
            input.isActive != patient.isActive)) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'You cannot edit this patient.',
      );
    }
    if (!ProfilePolicy.samePatient(patient, expected)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This profile changed. Reopen the form.',
      );
    }
    ProfilePolicy.contact(input.fullName, input.phone);
    final updated = patient.copyWith(
      fullName: input.fullName.trim(),
      phone: input.phone.trim(),
      address: input.address?.trim().isEmpty == true
          ? null
          : input.address?.trim(),
      isActive: input.isActive,
      updatedAt: _now(),
    );
    _publish(
      _snapshot.copyWith(
        patients: _snapshot.patients
            .map((p) => p.id == patient.id ? updated : p)
            .toList(),
      ),
    );
    return updated;
  }

  @override
  Future<Doctor> saveDoctor({
    required ClinicUser actor,
    Doctor? expected,
    required DoctorInput input,
    String? newDoctorId,
    String? newUserId,
  }) async {
    _ensureOpen();
    ProfilePolicy.active(actor);
    final admin = actor.role == UserRole.admin;
    Doctor? current;
    if (expected == null) {
      ProfilePolicy.admin(actor);
      if (newDoctorId == null ||
          newDoctorId.trim().isEmpty ||
          newUserId == null ||
          newUserId.trim().isEmpty ||
          newDoctorId == newUserId ||
          newUserId == actor.id ||
          newDoctorId == actor.id ||
          newUserId == 'admin-001' ||
          newDoctorId == 'admin-001' ||
          _snapshot.doctors.any(
            (d) =>
                d.id == newDoctorId ||
                d.id == newUserId ||
                d.userId == newDoctorId ||
                d.userId == newUserId ||
                d.email.toLowerCase() == input.email.trim().toLowerCase(),
          ) ||
          _snapshot.patients.any(
            (p) =>
                p.id == newUserId ||
                p.id == newDoctorId ||
                p.email.toLowerCase() == input.email.trim().toLowerCase(),
          )) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'Doctor email or identity is unavailable.',
        );
      }
    } else {
      final profiles = _snapshot.doctors.where((d) => d.id == expected.id);
      if (profiles.length != 1) {
        throw const ClinicFailure(
          FailureCode.notFound,
          'Doctor is unavailable.',
        );
      }
      current = profiles.single;
      if (!admin &&
          (actor.role != UserRole.doctor ||
              current.userId != actor.id ||
              _snapshot.doctors.where((d) => d.userId == actor.id).length !=
                  1)) {
        throw const ClinicFailure(
          FailureCode.unauthorized,
          'You cannot edit this doctor.',
        );
      }
      if (!ProfilePolicy.sameDoctor(current, expected)) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'This profile changed. Reopen the form.',
        );
      }
      if (input.email.trim().toLowerCase() != current.email.toLowerCase()) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'The sign-in email cannot be changed here.',
        );
      }
    }
    ProfilePolicy.doctor(input);
    final updated = current == null
        ? Doctor(
            id: newDoctorId!,
            userId: newUserId!,
            fullName: input.fullName.trim(),
            email: input.email.trim().toLowerCase(),
            phone: input.phone.trim(),
            specialty: input.specialty,
            consultationFee: input.consultationFee,
            experienceYears: input.experienceYears,
            availability: input.availability,
            isAvailable: input.isAvailable,
            bio: input.bio?.trim(),
            createdAt: _now(),
          )
        : current.copyWith(
            fullName: input.fullName.trim(),
            phone: input.phone.trim(),
            specialty: input.specialty,
            consultationFee: input.consultationFee,
            experienceYears: input.experienceYears,
            availability: input.availability,
            isAvailable: input.isAvailable,
            bio: input.bio?.trim().isEmpty == true ? null : input.bio?.trim(),
          );
    if (current != null &&
        !ProfilePolicy.sameAvailability(
          current.availability,
          updated.availability,
        )) {
      final now = _now();
      for (final visit in _snapshot.appointments.where(
        (a) =>
            a.doctorId == current!.id &&
            AppointmentPolicy.reservesTime(a.status) &&
            !a.dateTime.isBefore(now),
      )) {
        if (!AppointmentPolicy.workingSlots(
              updated.copyWith(isAvailable: true),
              visit.dateTime,
            ).contains(visit.dateTime) ||
            visit.durationMinutes != AppointmentPolicy.durationMinutes) {
          throw const ClinicFailure(
            FailureCode.conflict,
            'Working periods must retain existing future reservations.',
          );
        }
      }
    }
    _publish(
      _snapshot.copyWith(
        doctors: current == null
            ? [..._snapshot.doctors, updated]
            : _snapshot.doctors
                  .map((d) => d.id == current!.id ? updated : d)
                  .toList(),
      ),
    );
    return updated;
  }

  @override
  Future<void> removePatient({
    required ClinicUser actor,
    required ClinicUser expected,
  }) async {
    _ensureOpen();
    ProfilePolicy.admin(actor);
    final patients = _snapshot.patients.where((p) => p.id == expected.id);
    if (patients.length != 1) {
      throw const ClinicFailure(
        FailureCode.notFound,
        'Patient is unavailable.',
      );
    }
    if (!ProfilePolicy.samePatient(patients.single, expected)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This profile changed. Reopen the form.',
      );
    }
    if (_snapshot.appointments.any((a) => a.patientId == expected.id) ||
        _snapshot.prescriptions.any((p) => p.patientId == expected.id) ||
        _snapshot.invoices.any((i) => i.patientId == expected.id)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This patient has clinic records. Deactivate the account instead of deleting it.',
      );
    }
    _publish(
      _snapshot.copyWith(
        patients: _snapshot.patients.where((p) => p.id != expected.id).toList(),
      ),
    );
  }

  @override
  Future<void> removeDoctor({
    required ClinicUser actor,
    required Doctor expected,
  }) async {
    _ensureOpen();
    ProfilePolicy.admin(actor);
    final doctors = _snapshot.doctors.where((d) => d.id == expected.id);
    if (doctors.length != 1) {
      throw const ClinicFailure(FailureCode.notFound, 'Doctor is unavailable.');
    }
    if (!ProfilePolicy.sameDoctor(doctors.single, expected)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This profile changed. Reopen the form.',
      );
    }
    if (_snapshot.appointments.any((a) => a.doctorId == expected.id) ||
        _snapshot.prescriptions.any((p) => p.doctorId == expected.id)) {
      throw const ClinicFailure(
        FailureCode.conflict,
        'This doctor has clinic records. Disable booking instead of deleting the profile.',
      );
    }
    _publish(
      _snapshot.copyWith(
        doctors: _snapshot.doctors.where((d) => d.id != expected.id).toList(),
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _changes.close();
  }
}
