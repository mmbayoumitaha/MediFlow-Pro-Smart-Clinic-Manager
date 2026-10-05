import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/clinic_mapper.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  final at = DateTime(2026, 10, 5, 9);

  test('storage round trips preserve users and optional profile fields', () {
    for (final user in DemoFixtures.generatePatients(at: at)) {
      final map = ClinicMapper.userToMap(user);
      expect(ClinicMapper.userToMap(ClinicMapper.userFromMap(map)), map);
    }
  });

  test('storage round trips preserve doctors and nested availability', () {
    for (final doctor in DemoFixtures.generateDoctors()) {
      final map = ClinicMapper.doctorToMap(doctor);
      expect(ClinicMapper.doctorToMap(ClinicMapper.doctorFromMap(map)), map);
    }
  });

  test('storage round trips preserve appointment dates, statuses and fees', () {
    for (final appointment in DemoFixtures.generateAppointments(at: at)) {
      final map = ClinicMapper.appointmentToMap(appointment);
      expect(
        ClinicMapper.appointmentToMap(ClinicMapper.appointmentFromMap(map)),
        map,
      );
    }
  });

  test('storage round trips preserve prescriptions and medication details', () {
    for (final prescription in DemoFixtures.generatePrescriptions(at: at)) {
      final map = ClinicMapper.prescriptionToMap(prescription);
      expect(
        ClinicMapper.prescriptionToMap(ClinicMapper.prescriptionFromMap(map)),
        map,
      );
    }
  });

  test(
    'storage round trips preserve invoices, optional paid dates and items',
    () {
      for (final invoice in DemoFixtures.generateInvoices(at: at)) {
        final map = ClinicMapper.invoiceToMap(invoice);
        expect(
          ClinicMapper.invoiceToMap(ClinicMapper.invoiceFromMap(map)),
          map,
        );
      }
    },
  );

  test(
    'medical report mapping preserves optional uploader and description',
    () {
      final report = MedicalReport(
        id: 'report-1',
        patientId: 'pat-001',
        title: 'Demo report',
        description: 'Synthetic attachment',
        uploadedBy: 'doc-001',
        fileUrl: 'demo://report-1',
        fileType: 'pdf',
        uploadDate: at,
        createdAt: at,
      );
      final map = ClinicMapper.reportToMap(report);
      expect(ClinicMapper.reportToMap(ClinicMapper.reportFromMap(map)), map);
    },
  );

  test('user mapping refuses missing or unknown roles', () {
    final map = ClinicMapper.userToMap(
      DemoFixtures.generatePatients(at: at).first,
    );
    expect(
      () => ClinicMapper.userFromMap({...map, 'role': 'super_admin'}),
      throwsFormatException,
    );
    map.remove('role');
    expect(() => ClinicMapper.userFromMap(map), throwsFormatException);
  });

  test('mapping rejects invalid enums, dates and nested record shapes', () {
    final map = ClinicMapper.appointmentToMap(
      DemoFixtures.generateAppointments(at: at).first,
    );
    expect(
      () => ClinicMapper.appointmentFromMap({...map, 'status': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => ClinicMapper.appointmentFromMap({...map, 'dateTime': 'not-a-date'}),
      throwsFormatException,
    );
    final invoice = ClinicMapper.invoiceToMap(
      DemoFixtures.generateInvoices(at: at).first,
    );
    expect(
      () => ClinicMapper.invoiceFromMap({
        ...invoice,
        'items': ['malformed'],
      }),
      throwsFormatException,
    );
  });

  test('storage adapter accepts DateTime values without losing timezone', () {
    final user = DemoFixtures.generatePatients(at: at).first;
    final utc = DateTime.utc(2026, 10, 5, 8);
    final mapped = ClinicMapper.userFromMap({
      ...ClinicMapper.userToMap(user),
      'createdAt': utc,
      'updatedAt': utc.toIso8601String(),
    });
    expect(mapped.createdAt, utc);
    expect(mapped.createdAt.isUtc, isTrue);
    expect(mapped.updatedAt, utc);
  });
}
