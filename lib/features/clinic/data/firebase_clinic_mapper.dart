import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/clinic_clock.dart';
import '../domain/app_enums.dart';
import '../domain/entities.dart';
import 'clinic_mapper.dart';

class FirebaseClinicMapper {
  final ClinicClock clock;
  const FirebaseClinicMapper(this.clock);

  Map<String, dynamic> _map(String id, Map<String, dynamic> data) {
    Object? normalize(Object? value) {
      if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
      if (value is List) return value.map(normalize).toList();
      if (value is Map) {
        return value.map(
          (key, item) => MapEntry(key as String, normalize(item)),
        );
      }
      return value;
    }

    final map = {...normalize(data) as Map<String, dynamic>, 'id': id};
    for (final key in [
      'createdAt',
      'updatedAt',
      'dateTime',
      'issuedDate',
      'prescribedDate',
      'paidDate',
    ]) {
      final value = map[key];
      if (value != null &&
          (value is! String ||
              !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value))) {
        throw FormatException('Backend $key requires an explicit instant.');
      }
    }
    return map;
  }

  void _enum(Map<String, dynamic> map, String key, Iterable<String> values) {
    if (!values.contains(map[key])) {
      throw FormatException('Invalid clinic $key.');
    }
  }

  ClinicUser user(String id, Map<String, dynamic> data) {
    final map = _map(id, data);
    _enum(map, 'role', UserRole.values.map((e) => e.value));
    if (map['isActive'] is! bool) {
      throw const FormatException('Invalid clinic account activity.');
    }
    final user = ClinicMapper.userFromMap(map);
    return user.copyWith(
      createdAt: clock.inClinic(user.createdAt),
      updatedAt: clock.inClinic(user.updatedAt),
      dateOfBirth: user.dateOfBirth == null
          ? null
          : user.dateOfBirth!.isUtc
          ? clock.inClinic(user.dateOfBirth!)
          : user.dateOfBirth,
    );
  }

  Doctor doctor(String id, Map<String, dynamic> data) {
    final map = _map(id, data);
    _enum(map, 'specialty', MedicalSpecialty.values.map((e) => e.value));
    for (final period in map['availability'] as List<dynamic>? ?? []) {
      _enum(
        period as Map<String, dynamic>,
        'day',
        DayOfWeek.values.map((e) => e.value),
      );
    }
    final doctor = ClinicMapper.doctorFromMap(map);
    return doctor.copyWith(createdAt: clock.inClinic(doctor.createdAt));
  }

  Appointment appointment(String id, Map<String, dynamic> data) {
    final map = _map(id, data);
    _enum(map, 'specialty', MedicalSpecialty.values.map((e) => e.value));
    _enum(map, 'status', AppointmentStatus.values.map((e) => e.value));
    _enum(map, 'paymentStatus', PaymentStatus.values.map((e) => e.value));
    final appointment = ClinicMapper.appointmentFromMap(map);
    return appointment.copyWith(
      dateTime: clock.inClinic(appointment.dateTime),
      createdAt: clock.inClinic(appointment.createdAt),
      updatedAt: clock.inClinic(appointment.updatedAt),
    );
  }

  Invoice invoice(String id, Map<String, dynamic> data) {
    final map = _map(id, data);
    _enum(map, 'paymentStatus', PaymentStatus.values.map((e) => e.value));
    final invoice = ClinicMapper.invoiceFromMap(map);
    return Invoice(
      id: invoice.id,
      patientId: invoice.patientId,
      patientName: invoice.patientName,
      appointmentId: invoice.appointmentId,
      items: invoice.items,
      subtotal: invoice.subtotal,
      tax: invoice.tax,
      discount: invoice.discount,
      total: invoice.total,
      paymentStatus: invoice.paymentStatus,
      paymentMethod: invoice.paymentMethod,
      issuedDate: clock.inClinic(invoice.issuedDate),
      paidDate: invoice.paidDate == null
          ? null
          : clock.inClinic(invoice.paidDate!),
      createdAt: clock.inClinic(invoice.createdAt),
    );
  }

  Prescription prescription(String id, Map<String, dynamic> data) {
    final value = ClinicMapper.prescriptionFromMap(_map(id, data));
    return Prescription(
      id: value.id,
      patientId: value.patientId,
      patientName: value.patientName,
      doctorId: value.doctorId,
      doctorName: value.doctorName,
      appointmentId: value.appointmentId,
      diagnosis: value.diagnosis,
      medications: value.medications,
      notes: value.notes,
      prescribedDate: clock.inClinic(value.prescribedDate),
      createdAt: clock.inClinic(value.createdAt),
    );
  }
}
