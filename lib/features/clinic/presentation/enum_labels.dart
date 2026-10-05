import '../domain/app_enums.dart';

// Display text, colors and emoji are presentation metadata.

extension UserRoleLabels on UserRole {
  String get labelEn => switch (this) {
    UserRole.patient => 'Patient',
    UserRole.doctor => 'Doctor',
    UserRole.admin => 'Admin',
  };

  String get labelAr => switch (this) {
    UserRole.patient => 'مريض',
    UserRole.doctor => 'طبيب',
    UserRole.admin => 'مدير',
  };
}

extension AppointmentStatusLabels on AppointmentStatus {
  String get labelEn => switch (this) {
    AppointmentStatus.pending => 'Pending',
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.inProgress => 'In Progress',
    AppointmentStatus.completed => 'Completed',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.noShow => 'No Show',
  };

  String get labelAr => switch (this) {
    AppointmentStatus.pending => 'قيد الانتظار',
    AppointmentStatus.confirmed => 'مؤكد',
    AppointmentStatus.inProgress => 'جاري',
    AppointmentStatus.completed => 'مكتمل',
    AppointmentStatus.cancelled => 'ملغي',
    AppointmentStatus.noShow => 'لم يحضر',
  };

  int get colorValue => switch (this) {
    AppointmentStatus.pending => 0xFFF59E0B,
    AppointmentStatus.confirmed => 0xFF3B82F6,
    AppointmentStatus.inProgress => 0xFF8B5CF6,
    AppointmentStatus.completed => 0xFF10B981,
    AppointmentStatus.cancelled => 0xFFEF4444,
    AppointmentStatus.noShow => 0xFF64748B,
  };
}

extension MedicalSpecialtyLabels on MedicalSpecialty {
  String get labelEn => switch (this) {
    MedicalSpecialty.generalPractice => 'General Practice',
    MedicalSpecialty.cardiology => 'Cardiology',
    MedicalSpecialty.dermatology => 'Dermatology',
    MedicalSpecialty.neurology => 'Neurology',
    MedicalSpecialty.orthopedics => 'Orthopedics',
    MedicalSpecialty.pediatrics => 'Pediatrics',
    MedicalSpecialty.ophthalmology => 'Ophthalmology',
    MedicalSpecialty.dentistry => 'Dentistry',
    MedicalSpecialty.gynecology => 'Gynecology',
    MedicalSpecialty.urology => 'Urology',
    MedicalSpecialty.ent => 'ENT',
    MedicalSpecialty.psychiatry => 'Psychiatry',
    MedicalSpecialty.radiology => 'Radiology',
    MedicalSpecialty.laboratory => 'Laboratory',
  };

  String get labelAr => switch (this) {
    MedicalSpecialty.generalPractice => 'طب عام',
    MedicalSpecialty.cardiology => 'قلب',
    MedicalSpecialty.dermatology => 'جلدية',
    MedicalSpecialty.neurology => 'أعصاب',
    MedicalSpecialty.orthopedics => 'عظام',
    MedicalSpecialty.pediatrics => 'أطفال',
    MedicalSpecialty.ophthalmology => 'عيون',
    MedicalSpecialty.dentistry => 'أسنان',
    MedicalSpecialty.gynecology => 'نساء وتوليد',
    MedicalSpecialty.urology => 'مسالك بولية',
    MedicalSpecialty.ent => 'أنف أذن حنجرة',
    MedicalSpecialty.psychiatry => 'نفسية',
    MedicalSpecialty.radiology => 'أشعة',
    MedicalSpecialty.laboratory => 'مختبر',
  };

  String get emoji => switch (this) {
    MedicalSpecialty.generalPractice => '🩺',
    MedicalSpecialty.cardiology => '❤️',
    MedicalSpecialty.dermatology => '🧴',
    MedicalSpecialty.neurology => '🧠',
    MedicalSpecialty.orthopedics => '🦴',
    MedicalSpecialty.pediatrics => '👶',
    MedicalSpecialty.ophthalmology => '👁️',
    MedicalSpecialty.dentistry => '🦷',
    MedicalSpecialty.gynecology => '🤰',
    MedicalSpecialty.urology => '🏥',
    MedicalSpecialty.ent => '👂',
    MedicalSpecialty.psychiatry => '🧘',
    MedicalSpecialty.radiology => '📡',
    MedicalSpecialty.laboratory => '🔬',
  };
}

extension GenderLabels on Gender {
  String get labelEn => switch (this) {
    Gender.male => 'Male',
    Gender.female => 'Female',
  };

  String get labelAr => switch (this) {
    Gender.male => 'ذكر',
    Gender.female => 'أنثى',
  };
}

extension PaymentStatusLabels on PaymentStatus {
  String get labelEn => switch (this) {
    PaymentStatus.unpaid => 'Unpaid',
    PaymentStatus.paid => 'Paid',
    PaymentStatus.partial => 'Partial',
    PaymentStatus.refunded => 'Refunded',
  };

  String get labelAr => switch (this) {
    PaymentStatus.unpaid => 'غير مدفوع',
    PaymentStatus.paid => 'مدفوع',
    PaymentStatus.partial => 'جزئي',
    PaymentStatus.refunded => 'مسترد',
  };
}

extension DayOfWeekLabels on DayOfWeek {
  String get labelEn => switch (this) {
    DayOfWeek.monday => 'Monday',
    DayOfWeek.tuesday => 'Tuesday',
    DayOfWeek.wednesday => 'Wednesday',
    DayOfWeek.thursday => 'Thursday',
    DayOfWeek.friday => 'Friday',
    DayOfWeek.saturday => 'Saturday',
    DayOfWeek.sunday => 'Sunday',
  };

  String get labelAr => switch (this) {
    DayOfWeek.monday => 'الاثنين',
    DayOfWeek.tuesday => 'الثلاثاء',
    DayOfWeek.wednesday => 'الأربعاء',
    DayOfWeek.thursday => 'الخميس',
    DayOfWeek.friday => 'الجمعة',
    DayOfWeek.saturday => 'السبت',
    DayOfWeek.sunday => 'الأحد',
  };
}
