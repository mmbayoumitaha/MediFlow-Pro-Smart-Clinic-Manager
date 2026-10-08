import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/firebase/clinic_commands.dart';
import 'package:mediflow/features/auth/data/firebase_auth_gateway.dart';
import 'package:mediflow/features/auth/data/firebase_auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_session.dart';
import 'package:mediflow/features/auth/domain/auth_use_cases.dart';
import 'package:mediflow/features/auth/presentation/auth_view_model.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

ClinicUser person(
  String id, {
  UserRole role = UserRole.patient,
  bool active = true,
  String name = 'Patient Name',
}) => ClinicUser(
  id: id,
  email: '$id@example.test',
  fullName: name,
  phone: '+201000000000',
  role: role,
  isActive: active,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

class IdentityFake implements FirebaseIdentityGateway {
  String? uid;
  final events = StreamController<String?>.broadcast(sync: true);
  Future<String> Function(String, String)? signingIn;
  int created = 0, signedOut = 0;
  String? resetEmail;
  @override
  String? get currentUid => uid;
  @override
  Stream<String?> watchIdentity() => Stream.multi((controller) {
    controller.add(uid);
    final sub = events.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
  @override
  Future<String> signIn(String email, String password) async {
    uid = signingIn == null
        ? email.split('@').first
        : await signingIn!(email, password);
    events.add(uid);
    return uid!;
  }

  @override
  Future<String> createPatientIdentity(String email, String password) {
    created++;
    return signIn(email, password);
  }

  @override
  Future<void> signOut() async {
    signedOut++;
    uid = null;
    events.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    resetEmail = email;
  }
}

class ProfilesFake implements FirebaseProfileGateway {
  final records = <String, ClinicUser?>{};
  final streams = <String, StreamController<ClinicUser?>>{};
  Future<ClinicUser?> Function(String)? reading;
  @override
  Future<ClinicUser?> read(String uid) async =>
      reading == null ? records[uid] : await reading!(uid);
  @override
  Stream<ClinicUser?> watch(String uid) => streams
      .putIfAbsent(uid, () => StreamController.broadcast(sync: true))
      .stream;
  void publish(String uid, ClinicUser? user) {
    records[uid] = user;
    streams[uid]?.add(user);
  }

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

class CommandsFake implements ClinicCommands {
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>, String)?
  action;
  final calls = <(String, Map<String, dynamic>, String)>[];
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  }) async {
    calls.add((name, data, expectedUid));
    return action == null ? {} : await action!(name, data, expectedUid);
  }
}

class DeferredSessionAuth implements AuthRepository, AuthSessionSource {
  final result = Completer<ClinicUser>();
  final events = StreamController<AuthSession>.broadcast(sync: true);
  @override
  Future<ClinicUser> login(String email, String password, UserRole demoRole) =>
      result.future;
  @override
  Future<ClinicUser> register(RegistrationInput input) => result.future;
  @override
  Future<void> logout() async {}
  @override
  Stream<AuthSession> watchSession() => events.stream;
}

void main() {
  late IdentityFake identity;
  late ProfilesFake profiles;
  late CommandsFake commands;
  late FirebaseAuthRepository repository;
  late List<AuthSession> sessions;
  late StreamSubscription<AuthSession> subscription;
  setUp(() async {
    identity = IdentityFake();
    profiles = ProfilesFake();
    commands = CommandsFake();
    repository = FirebaseAuthRepository(identity, profiles, commands);
    sessions = [];
    subscription = repository.watchSession().listen(sessions.add);
    await flush();
  });
  tearDown(() async {
    await subscription.cancel();
    repository.dispose();
    await identity.events.close();
    await profiles.close();
  });
  test('login uses the trusted role, ignores role selectors, and watches profile/deactivation', () async {
    profiles.records['doctor'] = person('doctor', role: UserRole.doctor);
    final user = await repository.login(
      'doctor@example.test',
      'password',
      UserRole.admin,
    );
    await flush();
    expect(user.role, UserRole.doctor);
    expect(sessions.last.user!.role, UserRole.doctor);
    profiles.publish('doctor', user.copyWith(fullName: 'Updated Doctor'));
    await flush();
    expect(sessions.last.user!.fullName, 'Updated Doctor');
    profiles.publish('doctor', user.copyWith(isActive: false));
    await flush();
    await flush();
    expect(sessions.last.user, isNull);
    expect(sessions.last.error, isNotNull);
    expect(identity.currentUid, isNull);
  });
  test(
    'missing, inactive and mismatched server identities fail closed',
    () async {
      for (final profile in [
        null,
        person('patient', active: false),
        person('foreign'),
      ]) {
        profiles.records['patient'] = profile;
        await expectLater(
          repository.login(
            'patient@example.test',
            'password',
            UserRole.patient,
          ),
          throwsA(isA<ClinicFailure>()),
        );
        await flush();
        expect(sessions.last.user, isNull);
        expect(identity.currentUid, isNull);
      }
    },
  );
  test('logout during slow sign-in cannot restore an old session; next login runs after sign-out', () async {
    final pending = Completer<String>();
    identity.signingIn = (email, _) =>
        email.startsWith('old') ? pending.future : Future.value('new');
    profiles.records['old'] = person('old');
    profiles.records['new'] = person('new');
    final old = repository.login(
      'old@example.test',
      'password',
      UserRole.patient,
    );
    final rejected = expectLater(old, throwsA(isA<ClinicFailure>()));
    await flush();
    final logout = repository.logout();
    final next = repository.login(
      'new@example.test',
      'password',
      UserRole.admin,
    );
    pending.complete('old');
    await rejected;
    await logout;
    expect((await next).id, 'new');
    await flush();
    expect(identity.currentUid, 'new');
    expect(sessions.last.user!.id, 'new');
    expect(sessions.where((session) => session.user?.id == 'old'), isEmpty);
  });
  test(
    'a stale restoration or old profile stream cannot overwrite a new identity',
    () async {
      final pending = Completer<ClinicUser?>();
      profiles.reading = (uid) =>
          uid == 'old' ? pending.future : Future.value(person(uid));
      identity.uid = 'old';
      identity.events.add('old');
      await flush();
      await repository.login('new@example.test', 'password', UserRole.patient);
      pending.complete(person('old'));
      await flush();
      expect(sessions.last.user!.id, 'new');
      profiles.publish('old', person('old', role: UserRole.admin));
      await flush();
      expect(sessions.last.user!.id, 'new');
    },
  );
  test('registration sends contact only, rejects staff signup before Auth creation and recovers a lost acknowledgement', () async {
    const input = RegistrationInput(
      fullName: 'Patient Name',
      email: 'patient@example.test',
      password: 'password',
      phone: '+201000000000',
      role: UserRole.patient,
    );
    await expectLater(
      repository.register(
        const RegistrationInput(
          fullName: 'Doctor Name',
          email: 'doctor@example.test',
          password: 'password',
          phone: '+201000000000',
          role: UserRole.doctor,
        ),
      ),
      throwsA(isA<ClinicFailure>()),
    );
    expect(identity.created, 0);
    var attempts = 0;
    commands.action = (_, data, uid) async {
      profiles.records[uid] = person(uid);
      if (attempts++ == 0) {
        throw const ClinicFailure(FailureCode.unavailable, 'Lost response');
      }
      return {};
    };
    await expectLater(
      repository.register(input),
      throwsA(isA<ClinicFailure>()),
    );
    expect(identity.currentUid, isNull);
    expect((await repository.register(input)).role, UserRole.patient);
    expect(commands.calls.last.$2.keys, unorderedEquals(['fullName', 'phone']));
    expect(commands.calls.last.$3, 'patient');
  });
  test('server profile loss and stream errors revoke access and disposal ignores late responses', () async {
    profiles.records['patient'] = person('patient');
    await repository.login(
      'patient@example.test',
      'password',
      UserRole.patient,
    );
    profiles.streams['patient']!.addError(
      const ClinicFailure(FailureCode.unavailable, 'Profile stream failed'),
    );
    await flush();
    await flush();
    expect(sessions.last.user, isNull);
    final pending = Completer<ClinicUser?>();
    profiles.reading = (_) => pending.future;
    final login = repository.login(
      'patient@example.test',
      'password',
      UserRole.patient,
    );
    final rejected = expectLater(login, throwsA(isA<ClinicFailure>()));
    await flush();
    repository.dispose();
    pending.complete(person('patient'));
    await rejected;
  });
  test('view model follows trusted session events and password recovery validates/normalizes email', () async {
    final model = AuthViewModel(
      SignIn(repository),
      RegisterUser(repository),
      SignOut(repository),
      sessions: repository,
    );
    await flush();
    expect(model.state.currentUser, isNull);
    profiles.records['patient'] = person('patient');
    await model.login('patient@example.test', 'password', UserRole.admin);
    await flush();
    expect(model.state.currentUser!.role, UserRole.patient);
    profiles.publish('patient', person('patient', role: UserRole.doctor));
    await flush();
    expect(model.state.currentUser!.role, UserRole.doctor);
    await RequestPasswordReset(repository)('  Patient@Example.Test ');
    expect(identity.resetEmail, 'patient@example.test');
    expect(
      () => RequestPasswordReset(repository)('not-email'),
      throwsA(isA<ClinicFailure>()),
    );
    model.dispose();
    profiles.publish('patient', null);
    await flush();
  });
  test(
    'a same-UID role event wins over an older pending sign-in result',
    () async {
      final source = DeferredSessionAuth();
      final model = AuthViewModel(
        SignIn(source),
        RegisterUser(source),
        SignOut(source),
        sessions: source,
      );
      source.events.add(const AuthSession());
      final login = model.login(
        'patient@example.test',
        'password',
        UserRole.patient,
      );
      source.events.add(
        AuthSession(user: person('patient', role: UserRole.doctor)),
      );
      source.result.complete(person('patient'));
      await login;
      expect(model.state.currentUser!.role, UserRole.doctor);
      model.dispose();
      await source.events.close();
    },
  );
}
