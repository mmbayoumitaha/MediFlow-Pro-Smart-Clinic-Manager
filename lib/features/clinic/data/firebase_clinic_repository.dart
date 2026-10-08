import 'dart:async';

import '../../../core/firebase/clinic_clock.dart';
import '../../../core/firebase/clinic_commands.dart';
import '../../../core/firebase/firebase_failure.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/app_enums.dart';
import '../domain/authoritative_reservations.dart';
import '../domain/billing_policy.dart';
import '../domain/clinic_failure.dart';
import '../domain/clinic_repository.dart';
import '../domain/clinic_snapshot.dart';
import '../domain/entities.dart';
import '../domain/profile_policy.dart';
import 'clinic_mapper.dart';
import 'firebase_clinic_mapper.dart';
import 'firebase_clinic_records.dart';

class FirebaseClinicRepository
    implements ClinicRepository, AuthoritativeReservations {
  final ClinicRecords records;
  final ClinicCommands commands;
  final FirebaseClinicMapper mapper;
  final ClinicClock clock;
  late final StreamSubscription<AuthSession> _session;
  StreamSubscription<ClinicSnapshot>? _records;
  final _events = StreamController<ClinicSnapshot>.broadcast(sync: true);
  ClinicSnapshot _snapshot = ClinicSnapshot();
  ClinicUser? _user;
  ClinicFailure? _error;
  StackTrace? _errorStack;
  int _generation = 0;
  bool _closed = false, _hasSnapshot = false, _readFailed = false;
  FirebaseClinicRepository(
    AuthSessionSource sessions,
    this.records,
    this.commands,
    this.mapper,
    this.clock,
  ) {
    _session = sessions.watchSession().listen(
      _switchIdentity,
      onError: (Object error, StackTrace stack) {
        _switchIdentity(const AuthSession());
        if (!_closed) _failReads(error, stack);
      },
    );
  }
  void _switchIdentity(AuthSession session) {
    if (_closed) return;
    final user = session.isRestoring || session.user?.isActive != true
        ? null
        : session.user;
    final unchanged =
        user != null && user.id == _user?.id && user.role == _user?.role;
    _user = user;
    if (unchanged) return;
    final generation = ++_generation;
    if (_records != null) unawaited(_records!.cancel());
    _records = null;
    _snapshot = ClinicSnapshot();
    _hasSnapshot = user == null;
    _readFailed = false;
    _error = null;
    _errorStack = null;
    // Clear any old subscriber immediately; new authenticated subscribers wait
    // for their own server-confirmed scope before receiving a snapshot.
    _events.add(_snapshot);
    if (user == null) return;
    try {
      _records = records
          .watch(user)
          .listen(
            (snapshot) {
              if (_closed || generation != _generation) return;
              _snapshot = snapshot;
              _hasSnapshot = true;
              _error = null;
              _errorStack = null;
              _events.add(snapshot);
            },
            onError: (Object error, StackTrace stack) {
              if (_closed || generation != _generation) return;
              _failReads(error, stack);
            },
          );
    } catch (error, stack) {
      _failReads(error, stack);
    }
  }

  void _failReads(Object error, StackTrace stack) {
    _snapshot = ClinicSnapshot();
    _hasSnapshot = true;
    _readFailed = true;
    _error = firebaseFailure(error);
    _errorStack = stack;
    // Clear the view model's previous data before reporting revoked access.
    _events.add(_snapshot);
    _events.addError(_error!, stack);
  }

  ClinicUser _actor([ClinicUser? expected]) {
    final user = _user;
    if (_closed ||
        user == null ||
        !user.isActive ||
        (expected != null &&
            (expected.id != user.id || expected.role != user.role))) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Sign in again to use the current clinic account.',
      );
    }
    return user;
  }

  void _guard(int generation) {
    if (_closed || generation != _generation) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Your clinic session changed.',
      );
    }
  }

  @override
  Future<ClinicSnapshot> load() async {
    if (_readFailed) _restartReads();
    final user = _actor(), generation = _generation;
    try {
      final snapshot = await records.read(user);
      _guard(generation);
      return snapshot;
    } catch (error, stack) {
      _guard(generation);
      _failReads(error, stack);
      throw firebaseFailure(error);
    }
  }

  @override
  Stream<ClinicSnapshot> watch() => Stream.multi((controller) {
    if (_closed) {
      controller.close();
      return;
    }
    if (_hasSnapshot) controller.add(_snapshot);
    if (_error != null) controller.addError(_error!, _errorStack);
    final subscription = _events.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);
  Future<Map<String, dynamic>> _command(
    String name,
    Map<String, dynamic> data, [
    ClinicUser? actor,
  ]) async {
    final user = _actor(actor), generation = _generation;
    try {
      final result = await commands.call(name, data, expectedUid: user.id);
      _guard(generation);
      return result;
    } catch (error) {
      _guard(generation);
      throw firebaseFailure(error);
    }
  }

  @override
  Future<List<DateTime>> availableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    final result = await _command('availableSlots', {
      'doctorId': doctorId,
      'date': clock.dateKey(date),
    });
    if (result['zone'] != ClinicClock.zone || result['startMillis'] is! List) {
      throw const ClinicFailure(
        FailureCode.unavailable,
        'Clinic availability could not be read.',
      );
    }
    return (result['startMillis'] as List).map((value) {
      if (value is! num || !value.isFinite || value != value.toInt()) {
        throw const ClinicFailure(
          FailureCode.unavailable,
          'Clinic availability could not be read.',
        );
      }
      return clock.fromMilliseconds(value.toInt());
    }).toList();
  }

  @override
  Future<Appointment> reserve(Appointment request) async {
    if (_actor().id != request.patientId) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Book only from your own patient account.',
      );
    }
    final result = await _command('bookAppointment', {
      'requestId': request.id,
      'doctorId': request.doctorId,
      'startMillis': request.dateTime.millisecondsSinceEpoch,
      'expectedFee': request.fee,
      'expectedSpecialty': request.specialty.value,
      'reason': request.reason ?? '',
    });
    return mapper.appointment(result['id'] as String, result);
  }

  @override
  Future<void> bookAppointment(Appointment appointment) async {
    await reserve(appointment);
  }

  @override
  Future<void> registerUser(ClinicUser user, {Doctor? doctor}) => Future.error(
    const ClinicFailure(
      FailureCode.unauthorized,
      'Clinic enrollment is handled by the authentication service.',
    ),
  );
  @override
  Future<Appointment> changeAppointmentStatus({
    required ClinicUser actor,
    required String appointmentId,
    required AppointmentStatus expected,
    required AppointmentStatus target,
  }) async {
    final result = await _command('changeAppointmentStatus', {
      'appointmentId': appointmentId,
      'expectedStatus': expected.value,
      'targetStatus': target.value,
    }, actor);
    return mapper.appointment(result['id'] as String, result);
  }

  @override
  Future<Invoice> issueAppointmentInvoice({
    required ClinicUser actor,
    required String appointmentId,
    required String invoiceId,
  }) async {
    final result = await _command('issueAppointmentInvoice', {
      'appointmentId': appointmentId,
      'invoiceId': invoiceId,
    }, actor);
    return mapper.invoice(result['id'] as String, result);
  }

  @override
  Future<Invoice> recordInvoicePayment({
    required ClinicUser actor,
    required String invoiceId,
    required PaymentStatus expected,
    required PaymentStatus target,
    DemoPaymentMethod? method,
  }) async {
    final result = await _command('recordInvoicePayment', {
      'invoiceId': invoiceId,
      'expectedPayment': expected.value,
      'targetPayment': target.value,
      'method': method?.name,
    }, actor);
    return mapper.invoice(result['id'] as String, result);
  }

  Map<String, dynamic> _patientExpected(ClinicUser user) => {
    'id': user.id,
    'fullName': user.fullName,
    'phone': user.phone,
    'address': user.address,
    'isActive': user.isActive,
  };
  Map<String, dynamic> _doctorExpected(Doctor doctor) {
    final map = ClinicMapper.doctorToMap(doctor);
    return {
      for (final key in [
        'id',
        'userId',
        'fullName',
        'email',
        'phone',
        'bio',
        'specialty',
        'consultationFee',
        'experienceYears',
        'isAvailable',
        'availability',
      ])
        key: map[key],
    };
  }

  @override
  Future<ClinicUser> savePatient({
    required ClinicUser actor,
    required ClinicUser expected,
    required ContactInput input,
  }) async {
    final result = await _command('savePatient', {
      'expected': _patientExpected(expected),
      'contact': {
        'fullName': input.fullName,
        'phone': input.phone,
        'address': input.address,
        'isActive': input.isActive,
      },
    }, actor);
    return mapper.user(result['id'] as String, result);
  }

  @override
  Future<Doctor> saveDoctor({
    required ClinicUser actor,
    Doctor? expected,
    required DoctorInput input,
    String? newDoctorId,
    String? newUserId,
  }) async {
    final result = await _command('saveDoctor', {
      'expected': expected == null ? null : _doctorExpected(expected),
      'newDoctorId': newDoctorId,
      'newUserId': newUserId,
      'profile': {
        'fullName': input.fullName,
        'email': input.email,
        'phone': input.phone,
        'bio': input.bio,
        'specialty': input.specialty.value,
        'consultationFee': input.consultationFee,
        'experienceYears': input.experienceYears,
        'availability': input.availability
            .map(ClinicMapper.availabilityToMap)
            .toList(),
        'isAvailable': input.isAvailable,
      },
    }, actor);
    return mapper.doctor(result['id'] as String, result);
  }

  @override
  Future<void> removePatient({
    required ClinicUser actor,
    required ClinicUser expected,
  }) async {
    await _command('removePatient', {
      'expected': _patientExpected(expected),
    }, actor);
  }

  @override
  Future<void> removeDoctor({
    required ClinicUser actor,
    required Doctor expected,
  }) async {
    await _command('removeDoctor', {
      'expected': _doctorExpected(expected),
    }, actor);
  }

  /// Restart failed query subscriptions when the user explicitly refreshes.
  void _restartReads() {
    final user = _user;
    _user = null;
    _switchIdentity(AuthSession(user: user));
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _user = null;
    _snapshot = ClinicSnapshot();
    unawaited(_session.cancel());
    if (_records != null) unawaited(_records!.cancel());
    unawaited(_events.close());
  }
}
