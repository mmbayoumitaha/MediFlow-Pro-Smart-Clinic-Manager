import 'app_enums.dart';

const _unchanged = Object();

/// Core user model used across all roles.
class ClinicUser {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClinicUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ClinicUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    Object? avatarUrl = _unchanged,
    Object? gender = _unchanged,
    Object? dateOfBirth = _unchanged,
    Object? address = _unchanged,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClinicUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: identical(avatarUrl, _unchanged)
          ? this.avatarUrl
          : avatarUrl as String?,
      gender: identical(gender, _unchanged) ? this.gender : gender as Gender?,
      dateOfBirth: identical(dateOfBirth, _unchanged)
          ? this.dateOfBirth
          : dateOfBirth as DateTime?,
      address: identical(address, _unchanged)
          ? this.address
          : address as String?,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Doctor-specific profile extension.
class Doctor {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final MedicalSpecialty specialty;
  final String? bio;
  final double consultationFee;
  final int experienceYears;
  final double rating;
  final int totalReviews;
  final List<AvailabilitySlot> availability;
  final bool isAvailable;
  final DateTime createdAt;

  Doctor({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.specialty,
    this.bio,
    required this.consultationFee,
    required this.experienceYears,
    this.rating = 0.0,
    this.totalReviews = 0,
    List<AvailabilitySlot> availability = const [],
    this.isAvailable = true,
    required this.createdAt,
  }) : availability = List.unmodifiable(availability);

  Doctor copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    Object? avatarUrl = _unchanged,
    MedicalSpecialty? specialty,
    Object? bio = _unchanged,
    double? consultationFee,
    int? experienceYears,
    double? rating,
    int? totalReviews,
    List<AvailabilitySlot>? availability,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return Doctor(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: identical(avatarUrl, _unchanged)
          ? this.avatarUrl
          : avatarUrl as String?,
      specialty: specialty ?? this.specialty,
      bio: identical(bio, _unchanged) ? this.bio : bio as String?,
      consultationFee: consultationFee ?? this.consultationFee,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      availability: availability ?? this.availability,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Time slot for doctor availability.
class AvailabilitySlot {
  final DayOfWeek day;
  final String startTime; // "09:00"
  final String endTime; // "17:00"
  final bool isActive;

  const AvailabilitySlot({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });
}

/// Appointment model.
class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final MedicalSpecialty specialty;
  final DateTime dateTime;
  final int durationMinutes;
  final AppointmentStatus status;
  final String? notes;
  final String? reason;
  final double fee;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    this.durationMinutes = 30,
    required this.status,
    this.notes,
    this.reason,
    required this.fee,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    required this.updatedAt,
  });

  Appointment copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    MedicalSpecialty? specialty,
    DateTime? dateTime,
    int? durationMinutes,
    AppointmentStatus? status,
    Object? notes = _unchanged,
    Object? reason = _unchanged,
    double? fee,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      notes: identical(notes, _unchanged) ? this.notes : notes as String?,
      reason: identical(reason, _unchanged) ? this.reason : reason as String?,
      fee: fee ?? this.fee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Prescription model.
class Prescription {
  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String diagnosis;
  final List<MedicationItem> medications;
  final String? notes;
  final DateTime prescribedDate;
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.diagnosis,
    required List<MedicationItem> medications,
    this.notes,
    required this.prescribedDate,
    required this.createdAt,
  }) : medications = List.unmodifiable(medications);
}

/// Individual medication in a prescription.
class MedicationItem {
  final String name;
  final String dosage;
  final String frequency;
  final int durationDays;
  final String? instructions;

  const MedicationItem({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.durationDays,
    this.instructions,
  });
}

/// Invoice / billing model.
class Invoice {
  final String id;
  final String patientId;
  final String patientName;
  final String? appointmentId;
  final List<InvoiceItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final DateTime issuedDate;
  final DateTime? paidDate;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.appointmentId,
    required List<InvoiceItem> items,
    required this.subtotal,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.total,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod,
    required this.issuedDate,
    this.paidDate,
    required this.createdAt,
  }) : items = List.unmodifiable(items);

  Invoice copyWith({
    PaymentStatus? paymentStatus,
    Object? paymentMethod = _unchanged,
    Object? paidDate = _unchanged,
  }) => Invoice(
    id: id,
    patientId: patientId,
    patientName: patientName,
    appointmentId: appointmentId,
    items: items,
    subtotal: subtotal,
    tax: tax,
    discount: discount,
    total: total,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    paymentMethod: identical(paymentMethod, _unchanged)
        ? this.paymentMethod
        : paymentMethod as String?,
    issuedDate: issuedDate,
    paidDate: identical(paidDate, _unchanged)
        ? this.paidDate
        : paidDate as DateTime?,
    createdAt: createdAt,
  );
}

/// Individual line item in an invoice.
class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  const InvoiceItem({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    required this.total,
  });
}

/// Medical report / test upload.
class MedicalReport {
  final String id;
  final String patientId;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileType; // pdf, image, etc.
  final String? uploadedBy; // doctorId or patientId
  final DateTime uploadDate;
  final DateTime createdAt;

  const MedicalReport({
    required this.id,
    required this.patientId,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileType,
    this.uploadedBy,
    required this.uploadDate,
    required this.createdAt,
  });
}
