import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/auth/data/demo_auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_repository.dart';
import 'package:mediflow/features/auth/domain/auth_use_cases.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9);
  late DemoClinicRepository clinic;
  late DemoAuthRepository auth;
  late int sequence;

  setUp(() {
    sequence = 0;
    clinic = DemoClinicRepository(at: now);
    auth = DemoAuthRepository(
      clinic,
      now: () => now,
      newId: () => 'new-${++sequence}',
    );
  });
  tearDown(() => clinic.dispose());

  test(
    'repositories own isolated immutable snapshots and seed one clock',
    () async {
      final other = DemoClinicRepository(at: now);
      addTearDown(other.dispose);
      final initial = await clinic.load();
      expect(() => initial.appointments.clear(), throwsUnsupportedError);
      expect(() => initial.doctors.clear(), throwsUnsupportedError);
      expect(initial.patients.first.updatedAt, now);
      await clinic.bookAppointment(
        initial.appointments.first.copyWith(id: 'new-booking'),
      );
      expect((await clinic.load()).appointments, hasLength(9));
      expect(initial.appointments, hasLength(8));
      expect((await other.load()).appointments, hasLength(8));
    },
  );

  test(
    'watch delivers current snapshot followed by committed mutations',
    () async {
      final first = await clinic.load();
      final snapshots = clinic.watch().take(2).toList();
      await clinic.bookAppointment(
        first.appointments.first.copyWith(id: 'new-booking'),
      );
      final events = await snapshots;
      expect(events.first.appointments, hasLength(8));
      expect(events.last.appointments.first.id, 'new-booking');
      expect((await clinic.watch().first).appointments, hasLength(9));
    },
  );

  test('doctor demo identity uses the user ID linked by its profile', () async {
    final user = await auth.login(
      'demo@mediflow.com',
      'password123',
      UserRole.doctor,
    );
    final profile = (await clinic.load()).doctors.first;
    expect(user.id, profile.userId);
    expect(user.id, isNot(profile.id));
  });

  test(
    'patient registration adds a record and login restores that identity',
    () async {
      final user = await RegisterUser(auth)(
        const RegistrationInput(
          fullName: '  New Patient  ',
          email: ' NEW@EXAMPLE.COM ',
          password: 'secret123',
          phone: '+201001234567',
          role: UserRole.patient,
        ),
      );
      expect(user.fullName, 'New Patient');
      expect((await clinic.load()).patients.last.id, user.id);
      final restored = await auth.login(
        'new@example.com',
        'secret123',
        UserRole.admin,
      );
      expect(restored.id, user.id);
      expect(restored.role, UserRole.patient);
    },
  );

  test('doctor registration adds a matching unavailable profile', () async {
    final user = await RegisterUser(auth)(
      const RegistrationInput(
        fullName: 'New Doctor',
        email: 'doctor@example.com',
        password: 'secret123',
        phone: '+201001234567',
        role: UserRole.doctor,
      ),
    );
    final snapshot = await clinic.load();
    final profile = snapshot.doctors.last;
    expect(profile.userId, user.id);
    expect(profile.id, isNot(user.id));
    expect(profile.isAvailable, isFalse);
    expect(snapshot.patients, hasLength(5));
  });

  test(
    'duplicate registration fails without changing clinic records',
    () async {
      final initial = await clinic.load();
      await expectLater(
        RegisterUser(auth)(
          RegistrationInput(
            fullName: 'Duplicate User',
            email: initial.patients.first.email,
            password: 'secret123',
            phone: '+201001234567',
            role: UserRole.patient,
          ),
        ),
        throwsA(
          isA<ClinicFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.conflict,
          ),
        ),
      );
      expect((await clinic.load()).patients, initial.patients);
    },
  );

  test('appointments reject duplicate IDs and missing relationships', () async {
    final initial = await clinic.load();
    await expectLater(
      clinic.bookAppointment(initial.appointments.first),
      throwsA(
        isA<ClinicFailure>().having(
          (e) => e.code,
          'code',
          FailureCode.conflict,
        ),
      ),
    );
    await expectLater(
      clinic.bookAppointment(
        initial.appointments.first.copyWith(id: 'orphan', patientId: 'missing'),
      ),
      throwsA(
        isA<ClinicFailure>().having(
          (e) => e.code,
          'code',
          FailureCode.notFound,
        ),
      ),
    );
    expect((await clinic.load()).appointments, hasLength(8));
  });

  test(
    'closed demo repositories reject reads and report stream failure',
    () async {
      clinic.dispose();
      await expectLater(clinic.load(), throwsA(isA<ClinicFailure>()));
      await expectLater(
        clinic.watch(),
        emitsInOrder([emitsError(isA<ClinicFailure>()), emitsDone]),
      );
    },
  );
}
