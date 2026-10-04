import '../enums/app_enums.dart';

/// Core user model used across all roles.
class UserModel {
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

  const UserModel({
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

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      phone: map['phone'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.value == map['role'],
        orElse: () => UserRole.patient,
      ),
      avatarUrl: map['avatarUrl'] as String?,
      gender: map['gender'] != null
          ? Gender.values.firstWhere(
              (g) => g.value == map['gender'],
              orElse: () => Gender.male,
            )
          : null,
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth'] as String)
          : null,
      address: map['address'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.value,
      'avatarUrl': avatarUrl,
      'gender': gender?.value,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'address': address,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    Gender? gender,
    DateTime? dateOfBirth,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Doctor-specific profile extension.
class DoctorModel {
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

  const DoctorModel({
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
    this.availability = const [],
    this.isAvailable = true,
    required this.createdAt,
  });

  factory DoctorModel.fromMap(Map<String, dynamic> map) {
    return DoctorModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      specialty: MedicalSpecialty.values.firstWhere(
        (s) => s.value == map['specialty'],
        orElse: () => MedicalSpecialty.generalPractice,
      ),
      bio: map['bio'] as String?,
      consultationFee: (map['consultationFee'] as num?)?.toDouble() ?? 0.0,
      experienceYears: map['experienceYears'] as int? ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: map['totalReviews'] as int? ?? 0,
      availability:
          (map['availability'] as List<dynamic>?)
              ?.map((e) => AvailabilitySlot.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isAvailable: map['isAvailable'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'specialty': specialty.value,
      'bio': bio,
      'consultationFee': consultationFee,
      'experienceYears': experienceYears,
      'rating': rating,
      'totalReviews': totalReviews,
      'availability': availability.map((e) => e.toMap()).toList(),
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  DoctorModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    MedicalSpecialty? specialty,
    String? bio,
    double? consultationFee,
    int? experienceYears,
    double? rating,
    int? totalReviews,
    List<AvailabilitySlot>? availability,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      specialty: specialty ?? this.specialty,
      bio: bio ?? this.bio,
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

  factory AvailabilitySlot.fromMap(Map<String, dynamic> map) {
    return AvailabilitySlot(
      day: DayOfWeek.values.firstWhere(
        (d) => d.value == map['day'],
        orElse: () => DayOfWeek.monday,
      ),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day.value,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
    };
  }
}

/// Appointment model.
class AppointmentModel {
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

  const AppointmentModel({
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

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      patientName: map['patientName'] as String,
      doctorId: map['doctorId'] as String,
      doctorName: map['doctorName'] as String,
      specialty: MedicalSpecialty.values.firstWhere(
        (s) => s.value == map['specialty'],
        orElse: () => MedicalSpecialty.generalPractice,
      ),
      dateTime: DateTime.parse(map['dateTime'] as String),
      durationMinutes: map['durationMinutes'] as int? ?? 30,
      status: AppointmentStatus.values.firstWhere(
        (s) => s.value == map['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: map['notes'] as String?,
      reason: map['reason'] as String?,
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: PaymentStatus.values.firstWhere(
        (p) => p.value == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty.value,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'status': status.value,
      'notes': notes,
      'reason': reason,
      'fee': fee,
      'paymentStatus': paymentStatus.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    MedicalSpecialty? specialty,
    DateTime? dateTime,
    int? durationMinutes,
    AppointmentStatus? status,
    String? notes,
    String? reason,
    double? fee,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      reason: reason ?? this.reason,
      fee: fee ?? this.fee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Prescription model.
class PrescriptionModel {
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

  const PrescriptionModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.diagnosis,
    required this.medications,
    this.notes,
    required this.prescribedDate,
    required this.createdAt,
  });

  factory PrescriptionModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionModel(
      id: map['id'] as String,
      appointmentId: map['appointmentId'] as String,
      patientId: map['patientId'] as String,
      patientName: map['patientName'] as String,
      doctorId: map['doctorId'] as String,
      doctorName: map['doctorName'] as String,
      diagnosis: map['diagnosis'] as String,
      medications: (map['medications'] as List<dynamic>)
          .map((e) => MedicationItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: map['notes'] as String?,
      prescribedDate: DateTime.parse(map['prescribedDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'diagnosis': diagnosis,
      'medications': medications.map((e) => e.toMap()).toList(),
      'notes': notes,
      'prescribedDate': prescribedDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
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

  factory MedicationItem.fromMap(Map<String, dynamic> map) {
    return MedicationItem(
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      frequency: map['frequency'] as String,
      durationDays: map['durationDays'] as int,
      instructions: map['instructions'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'durationDays': durationDays,
      'instructions': instructions,
    };
  }
}

/// Invoice / billing model.
class InvoiceModel {
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

  const InvoiceModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.appointmentId,
    required this.items,
    required this.subtotal,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.total,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod,
    required this.issuedDate,
    this.paidDate,
    required this.createdAt,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      patientName: map['patientName'] as String,
      appointmentId: map['appointmentId'] as String?,
      items: (map['items'] as List<dynamic>)
          .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: (map['subtotal'] as num).toDouble(),
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      paymentStatus: PaymentStatus.values.firstWhere(
        (p) => p.value == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      paymentMethod: map['paymentMethod'] as String?,
      issuedDate: DateTime.parse(map['issuedDate'] as String),
      paidDate: map['paidDate'] != null
          ? DateTime.parse(map['paidDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'appointmentId': appointmentId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'paymentStatus': paymentStatus.value,
      'paymentMethod': paymentMethod,
      'issuedDate': issuedDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
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

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: map['description'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }
}

/// Medical report / test upload.
class MedicalReportModel {
  final String id;
  final String patientId;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileType; // pdf, image, etc.
  final String? uploadedBy; // doctorId or patientId
  final DateTime uploadDate;
  final DateTime createdAt;

  const MedicalReportModel({
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

  factory MedicalReportModel.fromMap(Map<String, dynamic> map) {
    return MedicalReportModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      fileUrl: map['fileUrl'] as String,
      fileType: map['fileType'] as String,
      uploadedBy: map['uploadedBy'] as String?,
      uploadDate: DateTime.parse(map['uploadDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploadDate': uploadDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
