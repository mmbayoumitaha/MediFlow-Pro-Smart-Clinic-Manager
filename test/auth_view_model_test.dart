import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/features/auth/domain/auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_use_cases.dart';
import 'package:mediflow/features/auth/presentation/auth_view_model.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final user = DemoFixtures.generatePatients(at: DateTime(2026, 10, 5)).first;
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(repository.logout()).thenAnswer((_) async {});
  });

  AuthViewModel createViewModel() => AuthViewModel(
    SignIn(repository),
    RegisterUser(repository),
    SignOut(repository),
  );

  test('sign-in normalizes email and rejects inactive accounts', () async {
    when(repository.login(any, any, any))
        .thenAnswer((_) async => user.copyWith(isActive: false));
    await expectLater(
      SignIn(repository)(' MARIAM@EMAIL.COM ', 'password123', UserRole.patient),
      throwsA(isA<ClinicFailure>()),
    );
    verify(
      repository.login('mariam@email.com', 'password123', UserRole.patient),
    ).called(1);
  });

  test('invalid sign-in input never reaches the repository', () async {
    await expectLater(
      SignIn(repository)('invalid', 'password123', UserRole.patient),
      throwsA(isA<ClinicFailure>()),
    );
    await expectLater(
      SignIn(repository)('valid@example.com', 'short', UserRole.patient),
      throwsA(isA<ClinicFailure>()),
    );
    verifyNever(repository.login(any, any, any));
  });

  test(
    'registration validates trimmed names, phones and admin provisioning',
    () async {
      for (final input in [
        const RegistrationInput(
          fullName: '   ',
          email: 'a@example.com',
          password: 'secret123',
          phone: '+201001234567',
          role: UserRole.patient,
        ),
        const RegistrationInput(
          fullName: 'Valid Name',
          email: 'a@example.com',
          password: 'secret123',
          phone: '--------',
          role: UserRole.patient,
        ),
        const RegistrationInput(
          fullName: 'Valid Name',
          email: 'a@example.com',
          password: 'secret123',
          phone: '+201001234567',
          role: UserRole.admin,
        ),
      ]) {
        await expectLater(
          RegisterUser(repository)(input),
          throwsA(isA<ClinicFailure>()),
        );
      }
      verifyNever(repository.register(any));
    },
  );

  test('registration sends normalized data to the repository', () async {
    when(repository.register(any)).thenAnswer((_) async => user);
    await RegisterUser(repository)(
      const RegistrationInput(
        fullName: '  Valid Name  ',
        email: ' NEW@EXAMPLE.COM ',
        password: 'secret123',
        phone: ' +201001234567 ',
        role: UserRole.patient,
      ),
    );
    final input =
        verify(repository.register(captureAny)).captured.single
            as RegistrationInput;
    expect(input.fullName, 'Valid Name');
    expect(input.email, 'new@example.com');
    expect(input.phone, '+201001234567');
  });

  test('view model exposes loading then authenticated state', () async {
    when(repository.login(any, any, any)).thenAnswer((_) async => user);
    final model = createViewModel();
    addTearDown(model.dispose);
    final states = <AuthState>[];
    model.addListener(states.add);
    await model.login('mariam@email.com', 'password123', UserRole.patient);
    expect(states.map((s) => s.isLoading), [false, true, false]);
    expect(model.state.currentUser, user);
    expect(model.state.isAuthenticated, isTrue);
  });

  test('auth repository failures expose a safe retry message', () async {
    when(repository.login(any, any, any))
        .thenThrow(Exception('internal credentials'));
    final model = createViewModel();
    addTearDown(model.dispose);
    await model.login('valid@example.com', 'password123', UserRole.patient);
    expect(model.state.isLoading, isFalse);
    expect(model.state.error, 'Could not sign in. Please try again.');
    expect(model.state.isAuthenticated, isFalse);
  });

  test(
    'duplicate requests are ignored and logout defeats late login',
    () async {
      final pending = Completer<ClinicUser>();
      when(repository.login(any, any, any)).thenAnswer((_) => pending.future);
      final model = createViewModel();
      addTearDown(model.dispose);
      final login = model.login(
        'valid@example.com',
        'password123',
        UserRole.patient,
      );
      await model.login('valid@example.com', 'password123', UserRole.patient);
      await model.logout();
      pending.complete(user);
      await login;
      expect(model.state.currentUser, isNull);
      expect(model.state.isAuthenticated, isFalse);
      verify(repository.login(any, any, any)).called(1);
      verify(repository.logout()).called(1);
    },
  );

  test('disposed auth view model ignores pending completions', () async {
    final pending = Completer<ClinicUser>();
    when(repository.login(any, any, any)).thenAnswer((_) => pending.future);
    final model = createViewModel();
    final login = model.login(
      'valid@example.com',
      'password123',
      UserRole.patient,
    );
    model.dispose();
    pending.complete(user);
    await login;
  });

  test(
    'logout failure clears identity and exposes a safe retry message',
    () async {
      when(repository.login(any, any, any)).thenAnswer((_) async => user);
      when(repository.logout()).thenThrow(Exception('internal session token'));
      final model = createViewModel();
      addTearDown(model.dispose);
      await model.login(user.email, 'dummy123', UserRole.patient);
      await model.logout();
      expect(model.state.currentUser, isNull);
      expect(model.state.isAuthenticated, isFalse);
      expect(
        model.state.error,
        'Could not finish signing out. Please try again.',
      );
    },
  );

  test('late logout failure does not clear a newer login', () async {
    final pending = Completer<void>();
    when(repository.login(any, any, any)).thenAnswer((_) async => user);
    when(repository.logout()).thenAnswer((_) => pending.future);
    final model = createViewModel();
    addTearDown(model.dispose);
    final logout = model.logout();
    await model.login(user.email, 'dummy123', UserRole.patient);
    pending.completeError(Exception('old session failure'));
    await logout;
    expect(model.state.currentUser, user);
    expect(model.state.isAuthenticated, isTrue);
    expect(model.state.error, isNull);
  });
}
