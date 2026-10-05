import '../domain/app_enums.dart';
import '../domain/entities.dart';

/// Storage-schema conversion belongs to the data layer, not to domain entities.
abstract final class ClinicMapper {
  static ClinicUser userFromMap(Map<String, dynamic> map) =>
      _decode("user", () {
        return ClinicUser(
          id: map['id'] as String,
          email: map['email'] as String,
          fullName: map['fullName'] as String,
          phone: map['phone'] as String? ?? '',
          role: _enum<UserRole>(
            UserRole.values,
            map['role'],
            (value) => value.value,
          ),
          avatarUrl: map['avatarUrl'] as String?,
          gender: map['gender'] != null
              ? _enum<Gender>(
                  Gender.values,
                  map['gender'],
                  (value) => value.value,
                  fallback: Gender.male,
                )
              : null,
          dateOfBirth: map['dateOfBirth'] != null
              ? _date(map['dateOfBirth'], 'dateOfBirth')
              : null,
          address: map['address'] as String?,
          isActive: map['isActive'] as bool? ?? true,
          createdAt: _date(map['createdAt'], 'createdAt'),
          updatedAt: _date(map['updatedAt'], 'updatedAt'),
        );
      });

  static Map<String, dynamic> userToMap(ClinicUser value) {
    return {
      'id': value.id,
      'email': value.email,
      'fullName': value.fullName,
      'phone': value.phone,
      'role': value.role.value,
      'avatarUrl': value.avatarUrl,
      'gender': value.gender?.value,
      'dateOfBirth': value.dateOfBirth?.toIso8601String(),
      'address': value.address,
      'isActive': value.isActive,
      'createdAt': value.createdAt.toIso8601String(),
      'updatedAt': value.updatedAt.toIso8601String(),
    };
  }

  static Doctor doctorFromMap(Map<String, dynamic> map) =>
      _decode("doctor", () {
        return Doctor(
          id: map['id'] as String,
          userId: map['userId'] as String,
          fullName: map['fullName'] as String,
          email: map['email'] as String,
          phone: map['phone'] as String? ?? '',
          avatarUrl: map['avatarUrl'] as String?,
          specialty: _enum<MedicalSpecialty>(
            MedicalSpecialty.values,
            map['specialty'],
            (value) => value.value,
            fallback: MedicalSpecialty.generalPractice,
          ),
          bio: map['bio'] as String?,
          consultationFee: (map['consultationFee'] as num?)?.toDouble() ?? 0.0,
          experienceYears: map['experienceYears'] as int? ?? 0,
          rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
          totalReviews: map['totalReviews'] as int? ?? 0,
          availability:
              (map['availability'] as List<dynamic>?)
                  ?.map((e) => availabilityFromMap(e as Map<String, dynamic>))
                  .toList() ??
              [],
          isAvailable: map['isAvailable'] as bool? ?? true,
          createdAt: _date(map['createdAt'], 'createdAt'),
        );
      });

  static Map<String, dynamic> doctorToMap(Doctor value) {
    return {
      'id': value.id,
      'userId': value.userId,
      'fullName': value.fullName,
      'email': value.email,
      'phone': value.phone,
      'avatarUrl': value.avatarUrl,
      'specialty': value.specialty.value,
      'bio': value.bio,
      'consultationFee': value.consultationFee,
      'experienceYears': value.experienceYears,
      'rating': value.rating,
      'totalReviews': value.totalReviews,
      'availability': value.availability
          .map((e) => availabilityToMap(e))
          .toList(),
      'isAvailable': value.isAvailable,
      'createdAt': value.createdAt.toIso8601String(),
    };
  }

  static AvailabilitySlot availabilityFromMap(Map<String, dynamic> map) =>
      _decode("availability", () {
        return AvailabilitySlot(
          day: _enum<DayOfWeek>(
            DayOfWeek.values,
            map['day'],
            (value) => value.value,
            fallback: DayOfWeek.monday,
          ),
          startTime: map['startTime'] as String,
          endTime: map['endTime'] as String,
          isActive: map['isActive'] as bool? ?? true,
        );
      });

  static Map<String, dynamic> availabilityToMap(AvailabilitySlot value) {
    return {
      'day': value.day.value,
      'startTime': value.startTime,
      'endTime': value.endTime,
      'isActive': value.isActive,
    };
  }

  static Appointment appointmentFromMap(Map<String, dynamic> map) =>
      _decode("appointment", () {
        return Appointment(
          id: map['id'] as String,
          patientId: map['patientId'] as String,
          patientName: map['patientName'] as String,
          doctorId: map['doctorId'] as String,
          doctorName: map['doctorName'] as String,
          specialty: _enum<MedicalSpecialty>(
            MedicalSpecialty.values,
            map['specialty'],
            (value) => value.value,
            fallback: MedicalSpecialty.generalPractice,
          ),
          dateTime: _date(map['dateTime'], 'dateTime'),
          durationMinutes: map['durationMinutes'] as int? ?? 30,
          status: _enum<AppointmentStatus>(
            AppointmentStatus.values,
            map['status'],
            (value) => value.value,
            fallback: AppointmentStatus.pending,
          ),
          notes: map['notes'] as String?,
          reason: map['reason'] as String?,
          fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
          paymentStatus: _enum<PaymentStatus>(
            PaymentStatus.values,
            map['paymentStatus'],
            (value) => value.value,
            fallback: PaymentStatus.unpaid,
          ),
          createdAt: _date(map['createdAt'], 'createdAt'),
          updatedAt: _date(map['updatedAt'], 'updatedAt'),
        );
      });

  static Map<String, dynamic> appointmentToMap(Appointment value) {
    return {
      'id': value.id,
      'patientId': value.patientId,
      'patientName': value.patientName,
      'doctorId': value.doctorId,
      'doctorName': value.doctorName,
      'specialty': value.specialty.value,
      'dateTime': value.dateTime.toIso8601String(),
      'durationMinutes': value.durationMinutes,
      'status': value.status.value,
      'notes': value.notes,
      'reason': value.reason,
      'fee': value.fee,
      'paymentStatus': value.paymentStatus.value,
      'createdAt': value.createdAt.toIso8601String(),
      'updatedAt': value.updatedAt.toIso8601String(),
    };
  }

  static Prescription prescriptionFromMap(Map<String, dynamic> map) =>
      _decode("prescription", () {
        return Prescription(
          id: map['id'] as String,
          appointmentId: map['appointmentId'] as String,
          patientId: map['patientId'] as String,
          patientName: map['patientName'] as String,
          doctorId: map['doctorId'] as String,
          doctorName: map['doctorName'] as String,
          diagnosis: map['diagnosis'] as String,
          medications: (map['medications'] as List<dynamic>)
              .map((e) => medicationFromMap(e as Map<String, dynamic>))
              .toList(),
          notes: map['notes'] as String?,
          prescribedDate: _date(map['prescribedDate'], 'prescribedDate'),
          createdAt: _date(map['createdAt'], 'createdAt'),
        );
      });

  static Map<String, dynamic> prescriptionToMap(Prescription value) {
    return {
      'id': value.id,
      'appointmentId': value.appointmentId,
      'patientId': value.patientId,
      'patientName': value.patientName,
      'doctorId': value.doctorId,
      'doctorName': value.doctorName,
      'diagnosis': value.diagnosis,
      'medications': value.medications.map((e) => medicationToMap(e)).toList(),
      'notes': value.notes,
      'prescribedDate': value.prescribedDate.toIso8601String(),
      'createdAt': value.createdAt.toIso8601String(),
    };
  }

  static MedicationItem medicationFromMap(Map<String, dynamic> map) =>
      _decode("medication", () {
        return MedicationItem(
          name: map['name'] as String,
          dosage: map['dosage'] as String,
          frequency: map['frequency'] as String,
          durationDays: map['durationDays'] as int,
          instructions: map['instructions'] as String?,
        );
      });

  static Map<String, dynamic> medicationToMap(MedicationItem value) {
    return {
      'name': value.name,
      'dosage': value.dosage,
      'frequency': value.frequency,
      'durationDays': value.durationDays,
      'instructions': value.instructions,
    };
  }

  static Invoice invoiceFromMap(Map<String, dynamic> map) =>
      _decode("invoice", () {
        return Invoice(
          id: map['id'] as String,
          patientId: map['patientId'] as String,
          patientName: map['patientName'] as String,
          appointmentId: map['appointmentId'] as String?,
          items: (map['items'] as List<dynamic>)
              .map((e) => invoiceItemFromMap(e as Map<String, dynamic>))
              .toList(),
          subtotal: (map['subtotal'] as num).toDouble(),
          tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
          discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
          total: (map['total'] as num).toDouble(),
          paymentStatus: _enum<PaymentStatus>(
            PaymentStatus.values,
            map['paymentStatus'],
            (value) => value.value,
            fallback: PaymentStatus.unpaid,
          ),
          paymentMethod: map['paymentMethod'] as String?,
          issuedDate: _date(map['issuedDate'], 'issuedDate'),
          paidDate: map['paidDate'] != null
              ? _date(map['paidDate'], 'paidDate')
              : null,
          createdAt: _date(map['createdAt'], 'createdAt'),
        );
      });

  static Map<String, dynamic> invoiceToMap(Invoice value) {
    return {
      'id': value.id,
      'patientId': value.patientId,
      'patientName': value.patientName,
      'appointmentId': value.appointmentId,
      'items': value.items.map((e) => invoiceItemToMap(e)).toList(),
      'subtotal': value.subtotal,
      'tax': value.tax,
      'discount': value.discount,
      'total': value.total,
      'paymentStatus': value.paymentStatus.value,
      'paymentMethod': value.paymentMethod,
      'issuedDate': value.issuedDate.toIso8601String(),
      'paidDate': value.paidDate?.toIso8601String(),
      'createdAt': value.createdAt.toIso8601String(),
    };
  }

  static InvoiceItem invoiceItemFromMap(Map<String, dynamic> map) =>
      _decode("invoiceItem", () {
        return InvoiceItem(
          description: map['description'] as String,
          quantity: map['quantity'] as int? ?? 1,
          unitPrice: (map['unitPrice'] as num).toDouble(),
          total: (map['total'] as num).toDouble(),
        );
      });

  static Map<String, dynamic> invoiceItemToMap(InvoiceItem value) {
    return {
      'description': value.description,
      'quantity': value.quantity,
      'unitPrice': value.unitPrice,
      'total': value.total,
    };
  }

  static MedicalReport reportFromMap(Map<String, dynamic> map) =>
      _decode("report", () {
        return MedicalReport(
          id: map['id'] as String,
          patientId: map['patientId'] as String,
          title: map['title'] as String,
          description: map['description'] as String?,
          fileUrl: map['fileUrl'] as String,
          fileType: map['fileType'] as String,
          uploadedBy: map['uploadedBy'] as String?,
          uploadDate: _date(map['uploadDate'], 'uploadDate'),
          createdAt: _date(map['createdAt'], 'createdAt'),
        );
      });

  static Map<String, dynamic> reportToMap(MedicalReport value) {
    return {
      'id': value.id,
      'patientId': value.patientId,
      'title': value.title,
      'description': value.description,
      'fileUrl': value.fileUrl,
      'fileType': value.fileType,
      'uploadedBy': value.uploadedBy,
      'uploadDate': value.uploadDate.toIso8601String(),
      'createdAt': value.createdAt.toIso8601String(),
    };
  }

  static T _decode<T>(String record, T Function() decode) {
    try {
      return decode();
    } on TypeError catch (error) {
      throw FormatException('Invalid $record record: $error');
    }
  }

  static DateTime _date(Object? value, String field) {
    if (value is DateTime) return value;
    if (value is String) {
      final date = DateTime.tryParse(value);
      if (date != null) return date;
    }
    throw FormatException('Invalid date field: $field');
  }

  static T _enum<T>(
    List<T> values,
    Object? raw,
    String Function(T) key, {
    T? fallback,
  }) {
    if (raw == null && fallback != null) return fallback;
    for (final value in values) {
      if (key(value) == raw) return value;
    }
    throw FormatException('Unknown enum value: $raw');
  }
}
