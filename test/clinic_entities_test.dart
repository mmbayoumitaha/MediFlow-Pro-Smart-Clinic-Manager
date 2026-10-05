import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/entities.dart';

void main() {
  final at = DateTime(2026, 10, 5, 9);

  test('nullable copyWith updates distinguish omission from clearing', () {
    final user = DemoFixtures.generatePatients(at: at).first
        .copyWith(avatarUrl: 'demo://avatar');
    expect(user.copyWith().avatarUrl, 'demo://avatar');
    final cleared = user.copyWith(
      avatarUrl: null,
      gender: null,
      dateOfBirth: null,
      address: null,
    );
    expect(cleared.avatarUrl, isNull);
    expect(cleared.gender, isNull);
    expect(cleared.dateOfBirth, isNull);
    expect(cleared.address, isNull);
    expect(user.address, isNotNull);
    expect(user.copyWith(id: null).id, user.id);

    final doctor = DemoFixtures.generateDoctors().first;
    expect(doctor.copyWith().bio, doctor.bio);
    expect(doctor.copyWith(bio: null).bio, isNull);

    final appointment = DemoFixtures.generateAppointments(at: at).first
        .copyWith(notes: 'demo notes');
    expect(appointment.copyWith().notes, 'demo notes');
    expect(appointment.copyWith(notes: null, reason: null).notes, isNull);
    expect(appointment.copyWith(reason: null).reason, isNull);
  });

  test('doctor availability takes an immutable defensive copy', () {
    final doctor = DemoFixtures.generateDoctors().first;
    final input = List<AvailabilitySlot>.of(doctor.availability);
    final copy = doctor.copyWith(availability: input);
    input.clear();
    expect(copy.availability, hasLength(3));
    expect(() => copy.availability.clear(), throwsUnsupportedError);
  });

  test('prescription medications and invoice items cannot be mutated', () {
    final prescription = DemoFixtures.generatePrescriptions(at: at).first;
    final medicationInput = List<MedicationItem>.of(prescription.medications);
    final copy = Prescription(
      id: prescription.id,
      appointmentId: prescription.appointmentId,
      patientId: prescription.patientId,
      patientName: prescription.patientName,
      doctorId: prescription.doctorId,
      doctorName: prescription.doctorName,
      diagnosis: prescription.diagnosis,
      medications: medicationInput,
      prescribedDate: at,
      createdAt: at,
    );
    medicationInput.clear();
    expect(copy.medications, isNotEmpty);
    expect(() => copy.medications.clear(), throwsUnsupportedError);

    final invoice = DemoFixtures.generateInvoices(at: at).first;
    expect(() => invoice.items.clear(), throwsUnsupportedError);
  });

  test('separate fixture generations share no mutable doctor list', () {
    final first = DemoFixtures.generateDoctors();
    first.clear();
    expect(DemoFixtures.generateDoctors(), hasLength(6));
    expect(
      DemoFixtures.generateAppointments(at: at).first.createdAt,
      at.subtract(const Duration(days: 3)),
    );
  });
}
