import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';
import 'package:mediflow/features/clinic/data/clinic_mapper.dart';
import 'package:mediflow/features/clinic/data/demo_clinic_repository.dart';
import 'package:mediflow/features/clinic/data/firebase_clinic_mapper.dart';

void main() {
  final clock = ClinicClock(), mapper = FirebaseClinicMapper(ClinicClock());
  late DemoClinicRepository repository;
  setUp(() => repository = DemoClinicRepository(at: DateTime(2026, 10, 12, 8)));
  tearDown(() => repository.dispose());
  Map<String, dynamic> timestamps(Map<String, dynamic> map) => map.map(
    (key, value) => MapEntry(
      key,
      value is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)
          ? Timestamp.fromDate(DateTime.parse(value))
          : value,
    ),
  );

  test('Firestore Timestamp and callable UTC strings retain the same instant and clinic display', () async {
    final snapshot = await repository.load(),
        source = snapshot.appointments.first;
    final map = timestamps(ClinicMapper.appointmentToMap(source));
    final stamp = Timestamp.fromDate(DateTime.utc(2026, 10, 12, 6, 30));
    map['dateTime'] = stamp;
    final firestore = mapper.appointment(source.id, map);
    final callable = mapper.appointment(source.id, {
      ...map,
      'dateTime': stamp.toDate().toUtc().toIso8601String(),
    });
    expect(
      firestore.dateTime.millisecondsSinceEpoch,
      stamp.millisecondsSinceEpoch,
    );
    expect(firestore.dateTime.hour, 9);
    expect(firestore.dateTime.minute, 30);
    expect(firestore.dateTime, callable.dateTime);
    expect(firestore.dateTime.isUtc, isFalse);
    expect(firestore.fee, source.fee);
    expect(firestore.status, source.status);
  });
  test(
    'all active storage entities map timestamps and use trusted document IDs',
    () async {
      final snapshot = await repository.load();
      final patient = snapshot.patients.first;
      final user = mapper.user(
        'trusted-user',
        timestamps(ClinicMapper.userToMap(patient)),
      );
      expect(user.id, 'trusted-user');
      expect(user.role, patient.role);
      expect(user.createdAt, clock.inClinic(patient.createdAt));
      expect(user.updatedAt, clock.inClinic(patient.updatedAt));
      final doctor = snapshot.doctors.first;
      final mappedDoctor = mapper.doctor(
        doctor.id,
        timestamps(ClinicMapper.doctorToMap(doctor)),
      );
      expect(mappedDoctor.userId, doctor.userId);
      expect(mappedDoctor.createdAt, clock.inClinic(doctor.createdAt));
      expect(mappedDoctor.availability.length, doctor.availability.length);
      for (final value in snapshot.invoices) {
        final invoice = mapper.invoice(
          value.id,
          timestamps(ClinicMapper.invoiceToMap(value)),
        );
        expect(invoice.total, value.total);
        expect(invoice.issuedDate, clock.inClinic(value.issuedDate));
        expect(
          invoice.paidDate,
          value.paidDate == null ? null : clock.inClinic(value.paidDate!),
        );
        expect(invoice.items.length, value.items.length);
      }
      for (final value in snapshot.prescriptions) {
        final prescription = mapper.prescription(
          value.id,
          timestamps(ClinicMapper.prescriptionToMap(value)),
        );
        expect(prescription.medications.length, value.medications.length);
        expect(
          prescription.prescribedDate,
          clock.inClinic(value.prescribedDate),
        );
      }
    },
  );
  test('backend mapping fails on unknown roles/statuses instead of inventing defaults', () async {
    final snapshot = await repository.load();
    final user = timestamps(ClinicMapper.userToMap(snapshot.patients.first));
    expect(
      () => mapper.user('user', {...user, 'role': 'owner'}),
      throwsFormatException,
    );
    expect(
      () => mapper.user('user', {...user, 'isActive': 'true'}),
      throwsFormatException,
    );
    final doctor = timestamps(ClinicMapper.doctorToMap(snapshot.doctors.first));
    expect(
      () => mapper.doctor('doctor', {...doctor, 'specialty': 'unknown'}),
      throwsFormatException,
    );
    final visit = timestamps(
      ClinicMapper.appointmentToMap(snapshot.appointments.first),
    );
    for (final key in ['specialty', 'status', 'paymentStatus']) {
      expect(
        () => mapper.appointment('appointment', {...visit, key: 'unknown'}),
        throwsFormatException,
      );
    }
    expect(
      () => mapper.appointment('appointment', {...visit, 'dateTime': 123}),
      throwsFormatException,
    );
    expect(
      () => mapper.appointment('appointment', {
        ...visit,
        'dateTime': '2026-10-12T09:00:00',
      }),
      throwsFormatException,
    );
  });
}
