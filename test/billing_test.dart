import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/data/clinic_mapper.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/features/clinic/domain/billing_policy.dart';
import 'package:mediflow/features/clinic/domain/billing_use_cases.dart';
import 'package:mediflow/features/clinic/domain/book_appointment.dart';
import 'package:mediflow/features/clinic/domain/clinic_analytics.dart';
import 'package:mediflow/features/clinic/domain/clinic_failure.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';
import 'package:mediflow/features/clinic/presentation/billing_view_model.dart';

import 'mocks/repositories.mocks.dart';

void main() {
  final seed = DateTime(2026, 10, 5, 9);
  var clock = seed;
  late DemoClinicRepository repository;
  final patient = DemoFixtures.generatePatients(at: seed).first;
  final admin = patient.copyWith(id: 'admin', role: UserRole.admin);
  final doctor = patient.copyWith(id: 'u-doc-001', role: UserRole.doctor);
  setUp(() {
    clock = seed;
    repository = DemoClinicRepository(at: seed, now: () => clock);
  });
  tearDown(() => repository.dispose());
  Matcher fails(FailureCode code) =>
      throwsA(isA<ClinicFailure>().having((e) => e.code, 'code', code));
  Future<Appointment> completed() async {
    final visit =
        await BookAppointment(
          repository,
          now: () => clock,
          newId: () => 'bill-visit',
        )(
          patient: patient,
          doctorId: 'doc-001',
          dateTime: DateTime(2026, 10, 6, 13, 30),
        );
    await repository.changeAppointmentStatus(
      actor: doctor,
      appointmentId: visit.id,
      expected: AppointmentStatus.pending,
      target: AppointmentStatus.confirmed,
    );
    clock = visit.dateTime;
    await repository.changeAppointmentStatus(
      actor: doctor,
      appointmentId: visit.id,
      expected: AppointmentStatus.confirmed,
      target: AppointmentStatus.inProgress,
    );
    return repository.changeAppointmentStatus(
      actor: doctor,
      appointmentId: visit.id,
      expected: AppointmentStatus.inProgress,
      target: AppointmentStatus.completed,
    );
  }

  test(
    'invoice copy supports clearing nullable values and storage round trips',
    () {
      final original = DemoFixtures.generateInvoices(at: seed).first;
      final cleared = original.copyWith(
        paymentStatus: PaymentStatus.unpaid,
        paymentMethod: null,
        paidDate: null,
      );
      expect(cleared.paidDate, isNull);
      expect(cleared.paymentMethod, isNull);
      expect(original.copyWith().paidDate, original.paidDate);
      expect(
        ClinicMapper.invoiceFromMap(ClinicMapper.invoiceToMap(cleared))
            .paymentStatus,
        PaymentStatus.unpaid,
      );
      expect(() => cleared.items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'patients, doctors and inactive admins cannot issue or alter invoices',
    () async {
      for (final actor in [patient, doctor, admin.copyWith(isActive: false)]) {
        await expectLater(
          repository.issueAppointmentInvoice(
            actor: actor,
            appointmentId: 'apt-001',
            invoiceId: 'new',
          ),
          fails(FailureCode.unauthorized),
        );
        await expectLater(
          repository.recordInvoicePayment(
            actor: actor,
            invoiceId: 'inv-002',
            expected: PaymentStatus.unpaid,
            target: PaymentStatus.paid,
            method: DemoPaymentMethod.cash,
          ),
          fails(FailureCode.unauthorized),
        );
      }
      expect((await repository.load()).invoices, hasLength(3));
    },
  );
  test(
    'one consultation invoice per completed visit, including competing retries',
    () async {
      final visit = await completed();
      final invoices = await Future.wait([
        repository.issueAppointmentInvoice(
          actor: admin,
          appointmentId: visit.id,
          invoiceId: 'new-one',
        ),
        repository.issueAppointmentInvoice(
          actor: admin,
          appointmentId: visit.id,
          invoiceId: 'new-two',
        ),
      ]);
      expect(invoices[0], same(invoices[1]));
      final invoice = invoices.first;
      expect(invoice.total, visit.fee);
      expect(invoice.subtotal, visit.fee);
      expect(invoice.tax, 0);
      expect(invoice.discount, 0);
      expect(invoice.issuedDate, clock);
      expect(invoice.paidDate, isNull);
      expect((await repository.load()).invoices, hasLength(4));
    },
  );
  test('missing, incomplete, already-paid visits and duplicate invoice IDs fail without mutation', () async {
    for (final id in ['missing', 'apt-004', 'apt-007']) {
      await expectLater(
        repository.issueAppointmentInvoice(
          actor: admin,
          appointmentId: id,
          invoiceId: 'new',
        ),
        throwsA(isA<ClinicFailure>()),
      );
    }
    final visit = await completed();
    await expectLater(
      repository.issueAppointmentInvoice(
        actor: admin,
        appointmentId: visit.id,
        invoiceId: 'inv-001',
      ),
      fails(FailureCode.conflict),
    );
    expect((await repository.load()).invoices, hasLength(3));
  });
  test('settlement and full refund atomically update invoice, linked visit and analytics', () async {
    final visit = await completed();
    final invoice = await repository.issueAppointmentInvoice(
      actor: admin,
      appointmentId: visit.id,
      invoiceId: 'new',
    );
    final before = await repository.load();
    final updates = <bool>[];
    final subscription = repository.watch().listen((s) {
      final i = s.invoices.singleWhere((i) => i.id == 'new');
      final a = s.appointments.singleWhere((a) => a.id == visit.id);
      updates.add(i.paymentStatus == a.paymentStatus);
    });
    await Future<void>.delayed(Duration.zero);
    final paid = await repository.recordInvoicePayment(
      actor: admin,
      invoiceId: invoice.id,
      expected: PaymentStatus.unpaid,
      target: PaymentStatus.paid,
      method: DemoPaymentMethod.bankTransfer,
    );
    expect(paid.paidDate, clock);
    expect(paid.paymentMethod, 'bankTransfer');
    expect(
      ClinicAnalytics(await repository.load(), clock).paidInvoiceTotal,
      1083 + visit.fee,
    );
    final refund = await repository.recordInvoicePayment(
      actor: admin,
      invoiceId: invoice.id,
      expected: PaymentStatus.paid,
      target: PaymentStatus.refunded,
    );
    expect(refund.paidDate, paid.paidDate);
    final after = await repository.load();
    expect(ClinicAnalytics(after, clock).paidInvoiceTotal, 1083);
    expect(
      after.appointments.singleWhere((a) => a.id == visit.id).status,
      AppointmentStatus.completed,
    );
    expect(after.prescriptions, before.prescriptions);
    expect(updates, everyElement(isTrue));
    await subscription.cancel();
  });
  test('competing settlement commands have one winner; stale retries cannot double-record', () async {
    final commands = List.generate(
      2,
      (_) => repository.recordInvoicePayment(
        actor: admin,
        invoiceId: 'inv-002',
        expected: PaymentStatus.unpaid,
        target: PaymentStatus.paid,
        method: DemoPaymentMethod.cash,
      ),
    );
    final outcomes = await Future.wait(
      commands.map((f) async {
        try {
          await f;
          return true;
        } on ClinicFailure catch (e) {
          expect(e.code, FailureCode.conflict);
          return false;
        }
      }),
    );
    expect(outcomes.where((ok) => ok), hasLength(1));
    expect(
      ClinicAnalytics(await repository.load(), clock).paidInvoiceTotal,
      1767,
    );
    await expectLater(
      repository.recordInvoicePayment(
        actor: admin,
        invoiceId: 'missing',
        expected: PaymentStatus.unpaid,
        target: PaymentStatus.paid,
        method: DemoPaymentMethod.cash,
      ),
      fails(FailureCode.notFound),
    );
    await expectLater(
      repository.recordInvoicePayment(
        actor: admin,
        invoiceId: 'inv-002',
        expected: PaymentStatus.paid,
        target: PaymentStatus.unpaid,
      ),
      fails(FailureCode.invalidInput),
    );
  });
  test('invoice arithmetic, monetary precision and transition policy reject malformed data', () {
    final original = DemoFixtures.generateInvoices(at: seed).first;
    for (final amount in [-1.0, .001, double.nan, double.infinity, 1e308]) {
      expect(() => BillingPolicy.cents(amount), throwsA(isA<ClinicFailure>()));
    }
    expect(BillingPolicy.cents(.1 + .2), 30);
    final invalid = Invoice(
      id: 'bad',
      patientId: 'p',
      patientName: 'P',
      items: const [
        InvoiceItem(description: 'Fee', quantity: 2, unitPrice: 10, total: 10),
      ],
      subtotal: 10,
      total: 10,
      issuedDate: seed,
      createdAt: seed,
    );
    expect(
      () => BillingPolicy.validateInvoice(invalid, seed),
      throwsA(isA<ClinicFailure>()),
    );
    for (final status in PaymentStatus.values) {
      final invoice = original.copyWith(paymentStatus: status);
      for (final target in PaymentStatus.values) {
        final legal =
            (target == PaymentStatus.paid &&
                (status == PaymentStatus.unpaid ||
                    status == PaymentStatus.partial)) ||
            (target == PaymentStatus.refunded && status == PaymentStatus.paid);
        if (legal) {
          BillingPolicy.validateTransition(
            invoice,
            status,
            target,
            DemoPaymentMethod.cash,
            seed,
          );
        } else {
          expect(
            () => BillingPolicy.validateTransition(
              invoice,
              status,
              target,
              DemoPaymentMethod.cash,
              seed,
            ),
            throwsA(isA<ClinicFailure>()),
          );
        }
      }
    }
    expect(
      () => BillingPolicy.validateTransition(
        original.copyWith(paymentStatus: PaymentStatus.unpaid),
        PaymentStatus.unpaid,
        PaymentStatus.paid,
        null,
        seed,
      ),
      throwsA(isA<ClinicFailure>()),
    );
  });
  test('billing view model locks submissions and passes current actor and expected status', () async {
    final mock = MockClinicRepository();
    final invoice = DemoFixtures.generateInvoices(at: seed)[1];
    final pending = Completer<Invoice>();
    when(
      mock.recordInvoicePayment(
        actor: anyNamed('actor'),
        invoiceId: anyNamed('invoiceId'),
        expected: anyNamed('expected'),
        target: anyNamed('target'),
        method: anyNamed('method'),
      ),
    ).thenAnswer((_) => pending.future);
    final model = BillingViewModel(
      IssueAppointmentInvoice(mock, () => 'new'),
      RecordInvoicePayment(mock),
      () => admin,
    );
    addTearDown(model.dispose);
    final result = model.record(
      invoice,
      PaymentStatus.paid,
      method: DemoPaymentMethod.card,
    );
    expect(model.state.busyId, invoice.id);
    expect(await model.issue('visit'), isFalse);
    pending.complete(invoice.copyWith(paymentStatus: PaymentStatus.paid));
    expect(await result, isTrue);
    expect(model.state.busyId, isNull);
    verify(
      mock.recordInvoicePayment(
        actor: admin,
        invoiceId: invoice.id,
        expected: PaymentStatus.unpaid,
        target: PaymentStatus.paid,
        method: DemoPaymentMethod.card,
      ),
    ).called(1);
  });
  test(
    'billing use cases reject unauthorized actors before repository access',
    () async {
      final mock = MockClinicRepository();
      for (final actor in [null, patient, admin.copyWith(isActive: false)]) {
        expect(
          () => IssueAppointmentInvoice(mock, () => 'new')(
            actor: actor,
            appointmentId: 'visit',
          ),
          throwsA(isA<ClinicFailure>()),
        );
        expect(
          () => RecordInvoicePayment(mock)(
            actor: actor,
            invoiceId: 'inv',
            expected: PaymentStatus.unpaid,
            target: PaymentStatus.paid,
          ),
          throwsA(isA<ClinicFailure>()),
        );
      }
      verifyZeroInteractions(mock);
    },
  );
  test(
    'billing errors are safe and disposal ignores a late completion',
    () async {
      final mock = MockClinicRepository();
      final invoice = DemoFixtures.generateInvoices(at: seed).first;
      when(
        mock.issueAppointmentInvoice(
          actor: anyNamed('actor'),
          appointmentId: anyNamed('appointmentId'),
          invoiceId: anyNamed('invoiceId'),
        ),
      ).thenThrow(Exception('internal path'));
      final model = BillingViewModel(
        IssueAppointmentInvoice(mock, () => 'new'),
        RecordInvoicePayment(mock),
        () => admin,
      );
      expect(await model.issue('visit'), isFalse);
      expect(model.state.error, 'Billing could not be updated. Try again.');
      final pending = Completer<Invoice>();
      when(
        mock.issueAppointmentInvoice(
          actor: anyNamed('actor'),
          appointmentId: anyNamed('appointmentId'),
          invoiceId: anyNamed('invoiceId'),
        ),
      ).thenAnswer((_) => pending.future);
      final result = model.issue('visit');
      model.dispose();
      pending.complete(invoice);
      expect(await result, isFalse);
    },
  );
}
