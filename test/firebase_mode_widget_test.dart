import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/core/config/backend_configuration.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/auth/domain/auth_session.dart';
import 'package:mediflow/features/auth/presentation/password_recovery_view_model.dart';
import 'package:mediflow/features/auth/domain/auth_use_cases.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/authoritative_reservations.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/clinic_snapshot.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/main.dart';
import 'package:mediflow/routes/app_router.dart';

import 'mocks/repositories.mocks.dart';

class SessionAuth extends MockAuthRepository
    implements AuthSessionSource, PasswordRecovery {
  final sessions = StreamController<AuthSession>.broadcast(sync: true);
  Future<void> Function(String)? recovering;
  final emails = <String>[];
  @override
  Stream<AuthSession> watchSession() => sessions.stream;
  @override
  Future<void> resetPassword(String email) async {
    emails.add(email);
    await recovering?.call(email);
  }
}

class RemoteClinic extends MockClinicRepository
    implements AuthoritativeReservations {
  Future<List<DateTime>> Function()? slots;
  int reads = 0;
  @override
  Future<List<DateTime>> availableSlots({
    required String doctorId,
    required DateTime date,
  }) {
    reads++;
    return slots!();
  }

  @override
  Future<Appointment> reserve(Appointment request) async => request;
}

void main() {
  final clock = ClinicClock();
  final now = clock.inClinic(DateTime.utc(2026, 10, 5, 6));
  final patient = DemoFixtures.generatePatients(at: now).first;
  final configuration = BackendConfiguration.fromDefines({
    'BACKEND_MODE': 'firebase',
    'FIREBASE_EMULATORS': 'true',
    'FIREBASE_PROJECT_ID': 'demo-mediflow',
    'FIREBASE_API_KEY': 'fictional',
    'FIREBASE_APP_ID': 'fictional-app',
    'FIREBASE_MESSAGING_SENDER_ID': '123',
  });
  late SessionAuth auth;
  late RemoteClinic clinic;
  late ProviderContainer container;
  setUp(() {
    auth = SessionAuth();
    clinic = RemoteClinic();
    final snapshot = ClinicSnapshot(
      patients: [patient],
      doctors: DemoFixtures.generateDoctors(),
    );
    when(clinic.watch()).thenAnswer((_) => Stream.value(snapshot));
    when(clinic.load()).thenAnswer((_) async => snapshot);
    container = ProviderContainer(
      overrides: [
        backendConfigurationProvider.overrideWithValue(configuration),
        clockProvider.overrideWithValue(() => now),
        authRepositoryProvider.overrideWithValue(auth),
        clinicRepositoryProvider.overrideWithValue(clinic),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await auth.sessions.close();
  });
  Future<void> open(WidgetTester tester, String path) async {
    container.read(routerProvider).go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediFlowApp(),
      ),
    );
    auth.sessions.add(const AuthSession());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Firebase sign-in hides demo roles/reset, starts empty and offers patient-only registration',
    (tester) async {
      await open(tester, '/login');
      expect(find.text('Demo role'), findsNothing);
      expect(find.text('Reset demo'), findsNothing);
      expect(
        find.text(
          'Local emulator · Fictional data\nClinic time: Africa/Cairo.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      expect(
        () => container.read(resetDemoProvider)(),
        throwsA(isA<ClinicFailure>()),
      );
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Create a patient account'), findsOneWidget);
      expect(find.text('Doctor'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'password recovery validates email and uses normalized address with generic feedback',
    (tester) async {
      await open(tester, '/login');
      final reset = find.text('Reset password');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(auth.emails, isEmpty);
      await tester.enterText(
        find.byType(TextFormField).first,
        ' Patient@Example.Test ',
      );
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(auth.emails, ['patient@example.test']);
      expect(
        find.text(
          'If this address can receive a reset, check its inbox for a password reset link.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  test('recovery blocks duplicate submissions and ignores completion after disposal', () async {
    final pending = Completer<void>();
    auth.recovering = (_) => pending.future;
    final model = PasswordRecoveryViewModel(RequestPasswordReset(auth));
    final first = model.send('doctor@example.test');
    await model.send('other@example.test');
    expect(auth.emails, ['doctor@example.test']);
    expect(model.state.isSubmitting, isTrue);
    model.dispose();
    pending.complete();
    await first;
  });
  testWidgets(
    'trusted session selects the portal and booking waits for server availability and supports retry',
    (tester) async {
      await open(tester, '/login');
      auth.sessions.add(AuthSession(user: patient));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/patient',
      );
      final pending = Completer<List<DateTime>>();
      clinic.slots = () => pending.future;
      container.read(routerProvider).go('/patient/book?doctorId=doc-001');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 6))));
      await tester.pump();
      final book = find.widgetWithText(FilledButton, 'Confirm Booking');
      expect(tester.widget<FilledButton>(book).onPressed, isNull);
      pending.completeError(
        const ClinicFailure(
          FailureCode.unavailable,
          'Availability unavailable.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Availability unavailable.'), findsOneWidget);
      final at = clock.inClinic(DateTime.utc(2026, 10, 6, 10, 30));
      clinic.slots = () async => [at];
      await tester.ensureVisible(find.text('Retry availability'));
      await tester.tap(find.text('Retry availability'));
      await tester.pumpAndSettle();
      final slot = find.widgetWithText(ChoiceChip, '01:30 PM');
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(book).onPressed, isNotNull);
      expect(
        find.text('All appointment times use Africa/Cairo.'),
        findsOneWidget,
      );
      expect(clinic.reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'startup configuration failure stays on an explicit error screen',
    (tester) async {
      await tester.pumpWidget(
        const StartupFailureApp(
          message: 'Provide FIREBASE_PROJECT_ID in your local Firebase configuration.',
        ),
      );
      expect(find.text('Clinic configuration required'), findsOneWidget);
      expect(find.text('Demo role'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    },
  );

  test('new payments use the current evaluation time between presentation clock ticks', () async {
    var current = now;
    final stream = StreamController<ClinicSnapshot>.broadcast(sync: true);
    when(clinic.watch()).thenAnswer((_) => stream.stream);
    final live = ProviderContainer(
      overrides: [
        backendConfigurationProvider.overrideWithValue(configuration),
        authRepositoryProvider.overrideWithValue(auth),
        clinicRepositoryProvider.overrideWithValue(clinic),
        clockProvider.overrideWithValue(() => current),
        liveClockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(() async {
      live.dispose();
      await stream.close();
    });
    live.read(authProvider);
    auth.sessions.add(
      AuthSession(user: patient.copyWith(role: UserRole.admin)),
    );
    live.read(clinicAnalyticsProvider);
    stream.add(ClinicSnapshot());
    await Future<void>.delayed(Duration.zero);
    current = now.add(const Duration(seconds: 5));
    final invoice = Invoice(
      id: 'new-payment',
      patientId: patient.id,
      patientName: patient.fullName,
      items: const [],
      subtotal: 80.25,
      total: 80.25,
      paymentStatus: PaymentStatus.paid,
      paidDate: current,
      issuedDate: now,
      createdAt: now,
    );
    stream.add(ClinicSnapshot(invoices: [invoice]));
    await Future<void>.delayed(Duration.zero);
    expect(live.read(clinicTimeProvider), now);
    expect(live.read(clinicAnalyticsProvider).paidInvoiceTotal, 80.25);
    expect(live.read(clinicMetricsProvider).paidInvoiceRevenue, 80.25);
  });

  for (final role in UserRole.values) {
    testWidgets(
      'rapid ${role.value} restoration cannot mount the same portal navigator twice',
      (tester) async {
        final user = patient.copyWith(
          role: role,
          id: role == UserRole.doctor ? 'u-doc-001' : patient.id,
        );
        await open(tester, '/login');
        auth.sessions.add(AuthSession(user: user));
        await tester.pumpAndSettle();
        container.read(routerProvider).go('/${role.value}');
        await tester.pumpAndSettle();
        auth.sessions.add(const AuthSession(isRestoring: true));
        await tester.pump(const Duration(milliseconds: 20));
        auth.sessions.add(AuthSession(user: user));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/${role.value}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      },
    );
  }
}
