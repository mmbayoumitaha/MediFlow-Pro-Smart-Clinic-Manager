import 'dart:async';

import '../../../core/firebase/clinic_commands.dart';
import '../../../core/firebase/firebase_failure.dart';
import '../../clinic/domain/app_enums.dart';
import '../../clinic/domain/clinic_failure.dart';
import '../../clinic/domain/entities.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'firebase_auth_gateway.dart';

class FirebaseAuthRepository
    implements AuthRepository, AuthSessionSource, PasswordRecovery {
  final FirebaseIdentityGateway identity;
  final FirebaseProfileGateway profiles;
  final ClinicCommands commands;
  final _events = StreamController<AuthSession>.broadcast(sync: true);
  late final StreamSubscription<String?> _identity;
  StreamSubscription<ClinicUser?>? _profile;
  AuthSession _session = const AuthSession(isRestoring: true);
  Future<void> _queue = Future.value();
  int _generation = 0, _pending = 0;
  bool _closed = false, _signedOut = false;

  FirebaseAuthRepository(this.identity, this.profiles, this.commands) {
    _identity = identity.watchIdentity().listen(
      _identityChanged,
      onError: (Object error) => _invalidate(firebaseFailure(error).message),
    );
  }
  @override
  Stream<AuthSession> watchSession() => Stream.multi((controller) {
    if (_closed) {
      controller.close();
      return;
    }
    controller.add(_session);
    final subscription = _events.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void _publish(AuthSession session) {
    if (_closed) return;
    _session = session;
    _events.add(session);
  }

  void _guard(int generation, [String? uid]) {
    if (_closed ||
        generation != _generation ||
        (uid != null && identity.currentUid != uid)) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'This authentication operation was cancelled.',
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _stopProfile() {
    final subscription = _profile;
    _profile = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _identityChanged(String? uid) {
    if (_closed || _pending > 0 || uid != identity.currentUid) return;
    if (_signedOut && uid != null) {
      unawaited(identity.signOut().catchError((Object _) {}));
      return;
    }
    final generation = ++_generation;
    _stopProfile();
    if (uid == null) {
      _publish(AuthSession(error: _signedOut ? _session.error : null));
      return;
    }
    _publish(const AuthSession(isRestoring: true));
    unawaited(_restore(generation, uid));
  }

  ClinicUser _active(ClinicUser? user, String uid) {
    if (user == null || user.id != uid || !user.isActive) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Your clinic account is unavailable. Complete patient registration or contact the clinic.',
      );
    }
    return user;
  }

  Future<void> _restore(int generation, String uid) async {
    try {
      final user = await profiles.read(uid);
      _guard(generation, uid);
      _publish(AuthSession(user: _active(user, uid)));
      _observeProfile(generation, uid);
    } catch (error) {
      if (!_closed && generation == _generation) {
        _invalidate(firebaseFailure(error).message);
      }
    }
  }

  void _observeProfile(int generation, String uid) {
    _stopProfile();
    _profile = profiles
        .watch(uid)
        .listen(
          (user) {
            if (_closed ||
                generation != _generation ||
                identity.currentUid != uid) {
              return;
            }
            try {
              _publish(AuthSession(user: _active(user, uid)));
            } catch (error) {
              _invalidate(firebaseFailure(error).message);
            }
          },
          onError: (Object error) {
            if (!_closed && generation == _generation) {
              _invalidate(firebaseFailure(error).message);
            }
          },
        );
  }

  void _invalidate(String message) {
    if (_closed) return;
    _generation++;
    _signedOut = true;
    _stopProfile();
    _publish(AuthSession(error: message));
    unawaited(_enqueue(() => identity.signOut()).catchError((Object _) {}));
  }

  Future<ClinicUser> _authenticate(
    Future<String> Function() credentials, {
    RegistrationInput? registration,
  }) {
    final generation = ++_generation;
    _signedOut = false;
    _pending++;
    return _enqueue(() async {
      _guard(generation);
      _stopProfile();
      _publish(const AuthSession(isRestoring: true));
      try {
        final uid = await credentials();
        _guard(generation, uid);
        if (registration != null) {
          await commands.call('completePatientRegistration', {
            'fullName': registration.fullName,
            'phone': registration.phone,
          }, expectedUid: uid);
          _guard(generation, uid);
        }
        final user = await profiles.read(uid);
        _guard(generation, uid);
        final active = _active(user, uid);
        _publish(AuthSession(user: active));
        _observeProfile(generation, uid);
        return active;
      } catch (error) {
        final failure = firebaseFailure(error);
        if (!_closed && generation == _generation) {
          _signedOut = true;
          try {
            await identity.signOut();
          } catch (_) {}
          _publish(AuthSession(error: failure.message));
        }
        throw failure;
      }
    }).whenComplete(() => _pending--);
  }

  @override
  Future<ClinicUser> login(String email, String password, UserRole demoRole) =>
      _authenticate(() => identity.signIn(email, password));
  @override
  Future<ClinicUser> register(RegistrationInput input) {
    if (input.role != UserRole.patient) {
      return Future.error(
        const ClinicFailure(
          FailureCode.unauthorized,
          'Doctor accounts are provisioned by the clinic administrator.',
        ),
      );
    }
    return _authenticate(
      () => identity.createPatientIdentity(input.email, input.password),
      registration: input,
    );
  }

  @override
  Future<void> logout() {
    _generation++;
    _signedOut = true;
    _stopProfile();
    _publish(const AuthSession());
    _pending++;
    return _enqueue(() => identity.signOut())
        .catchError((Object error) {
          final failure = firebaseFailure(error);
          _publish(AuthSession(error: failure.message));
          throw failure;
        })
        .whenComplete(() => _pending--);
  }

  @override
  Future<void> resetPassword(String email) => identity.resetPassword(email);
  void dispose() {
    if (_closed) return;
    _closed = true;
    _session = const AuthSession();
    _generation++;
    _stopProfile();
    unawaited(_identity.cancel());
    unawaited(_events.close());
  }
}
