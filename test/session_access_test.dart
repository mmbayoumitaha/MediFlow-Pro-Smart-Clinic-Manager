import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  test(
    'reset ignores an old refresh and reconnects to the new repository stream',
    () async {
      final oldRepository = MockClinicRepository();
      final freshRepository = MockClinicRepository();
      final oldStream = StreamController<ClinicSnapshot>.broadcast(sync: true);
      final newStream = StreamController<ClinicSnapshot>.broadcast(sync: true);
      final pending = Completer<ClinicSnapshot>();
      when(oldRepository.watch()).thenAnswer((_) => oldStream.stream);
      when(oldRepository.load()).thenAnswer((_) => pending.future);
      when(freshRepository.watch()).thenAnswer((_) => newStream.stream);
      var creations = 0;
      final container = ProviderContainer(
        overrides: [
          clinicRepositoryProvider.overrideWith(
            (ref) => creations++ == 0 ? oldRepository : freshRepository,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await oldStream.close();
        await newStream.close();
      });
      final subscription = container.listen(clinicViewModelProvider, (_, _) {});
      addTearDown(subscription.close);
      final refresh = container
          .read(clinicViewModelProvider.notifier)
          .refresh();
      container.read(resetDemoProvider)();
      expect(container.read(clinicViewModelProvider).isLoading, isTrue);
      final fresh = ClinicSnapshot(patients: DemoFixtures.generatePatients());
      newStream.add(fresh);
      pending.complete(ClinicSnapshot());
      await refresh;
      expect(container.read(clinicViewModelProvider).value, same(fresh));
      expect(oldStream.hasListener, isFalse);
      expect(newStream.hasListener, isTrue);
      expect(container.read(patientsProvider), isEmpty);
    },
  );
  test('demo reset drops registrations, writes and session, then reseeds the clock', () async {
    var now = DateTime(2026, 10, 6, 9);
    var id = 0;
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(() => 'session-${++id}'),
      ],
    );
    addTearDown(container.dispose);
    final oldRepository = container.read(clinicRepositoryProvider);
    final auth = container.read(authProvider.notifier);
    await auth.register(
      'Demo Person',
      'new@example.com',
      'dummy123',
      '+201001234567',
      UserRole.patient,
    );
    await container.read(clinicViewModelProvider.notifier).refresh();
    final booking = container.listen(bookingProvider, (_, _) {});
    addTearDown(booking.close);
    expect(
      await container
          .read(bookingProvider.notifier)
          .book(
            doctorId: 'doc-001',
            dateTime: now.add(const Duration(days: 1)),
          ),
      isTrue,
    );
    await auth.logout();
    await auth.login('new@example.com', 'another-dummy', UserRole.admin);
    expect(container.read(authProvider).currentUser!.role, UserRole.patient);
    expect(container.read(appointmentsProvider), hasLength(1));
    expect((await oldRepository.load()).appointments, hasLength(9));
    now = now.add(const Duration(days: 2));
    container.read(resetDemoProvider)();
    expect(container.read(authProvider).currentUser, isNull);
    expect(container.read(appointmentsProvider), isEmpty);
    expect(container.read(bookingProvider).appointment, isNull);
    final fresh = container.read(clinicRepositoryProvider);
    expect(fresh, isNot(same(oldRepository)));
    final snapshot = await fresh.load();
    expect(snapshot.patients, hasLength(5));
    expect(snapshot.appointments, hasLength(8));
    expect(snapshot.patients.first.updatedAt, now);
    await expectLater(oldRepository.load(), throwsException);
    await container
        .read(authProvider.notifier)
        .login('new@example.com', 'dummy123', UserRole.patient);
    expect(container.read(authProvider).currentUser, isNull);
    expect(
      container.read(authProvider).error,
      contains('registered demo account'),
    );
    // Reset remains safe if requested again from the logged-out screen.
    container.read(resetDemoProvider)();
    expect(
      (await container.read(clinicRepositoryProvider).load()).appointments,
      hasLength(8),
    );
  });

  test('reset during pending login ignores the old completion', () async {
    final repository = MockAuthRepository();
    final pending = Completer<ClinicUser>();
    when(repository.login(any, any, any)).thenAnswer((_) => pending.future);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final login = container
        .read(authProvider.notifier)
        .login('demo@mediflow.com', 'dummy123', UserRole.patient);
    expect(container.read(authProvider).isLoading, isTrue);
    container.read(resetDemoProvider)();
    pending.complete(DemoFixtures.generatePatients().first);
    await login;
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).isLoading, isFalse);
    expect(container.read(appointmentsProvider), isEmpty);
  });
  test(
    'account switches and logout synchronously rescope every read provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 9)),
        ],
      );
      addTearDown(container.dispose);
      // Establish the stream before login; anonymous reads remain empty.
      expect(container.read(appointmentsProvider), isEmpty);
      await container.read(clinicViewModelProvider.notifier).refresh();
      final auth = container.read(authProvider.notifier);
      await auth.login('mariam@email.com', 'password123', UserRole.admin);
      expect(container.read(authProvider).currentUser!.role, UserRole.patient);
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-001',
        'apt-004',
      ]);
      expect(container.read(invoicesProvider).map((i) => i.id), ['inv-001']);
      expect(container.read(clinicMetricsProvider).paidInvoiceRevenue, 570);
      expect(container.read(clinicMetricsProvider).completed, isEmpty);
      container.read(searchQueryProvider.notifier).state = 'Ahmed';
      container.read(selectedSpecialtyProvider.notifier).state =
          MedicalSpecialty.cardiology;
      await auth.logout();
      expect(container.read(appointmentsProvider), isEmpty);
      expect(container.read(patientsProvider), isEmpty);
      expect(container.read(invoicesProvider), isEmpty);
      expect(container.read(doctorsProvider), isEmpty);
      expect(container.read(clinicMetricsProvider).paidInvoiceRevenue, 0);
      expect(container.read(clinicMetricsProvider).today, isEmpty);
      expect(container.read(searchQueryProvider), '');
      expect(container.read(selectedSpecialtyProvider), isNull);
      await auth.login('layla@email.com', 'password123', UserRole.admin);
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-003',
        'apt-008',
      ]);
      expect(container.read(prescriptionsProvider).map((p) => p.id), [
        'presc-001',
      ]);
      expect(container.read(invoicesProvider), isEmpty);
      expect(container.read(clinicMetricsProvider).completed, hasLength(1));
      expect(container.read(clinicMetricsProvider).paidInvoiceRevenue, 0);
      await auth.logout();
      await auth.login('sara@mediflow.com', 'password123', UserRole.patient);
      expect(container.read(doctorsProvider).single.id, 'doc-002');
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-004',
        'apt-008',
      ]);
      expect(container.read(patientsProvider).map((p) => p.id), [
        'pat-001',
        'pat-003',
      ]);
      expect(container.read(invoicesProvider), isEmpty);
      expect(container.read(clinicMetricsProvider).completed, isEmpty);
      await auth.logout();
      await auth.login('demo@mediflow.com', 'password123', UserRole.admin);
      expect(container.read(appointmentsProvider), hasLength(8));
      expect(container.read(patientsProvider), hasLength(5));
      expect(container.read(invoicesProvider), hasLength(3));
      expect(container.read(clinicMetricsProvider).paidInvoiceRevenue, 1083);
      expect(container.read(clinicMetricsProvider).completed, hasLength(3));
    },
  );
}
