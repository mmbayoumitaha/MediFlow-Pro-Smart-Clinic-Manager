/// All user role types in MediFlow Pro.
enum UserRole {
  patient('patient', 'Patient', 'مريض'),
  doctor('doctor', 'Doctor', 'طبيب'),
  admin('admin', 'Admin', 'مدير');

  const UserRole(this.value, this.labelEn, this.labelAr);
  final String value;
  final String labelEn;
  final String labelAr;
}

/// Appointment status lifecycle.
enum AppointmentStatus {
  pending('pending', 'Pending', 'قيد الانتظار', 0xFFF59E0B),
  confirmed('confirmed', 'Confirmed', 'مؤكد', 0xFF3B82F6),
  inProgress('in_progress', 'In Progress', 'جاري', 0xFF8B5CF6),
  completed('completed', 'Completed', 'مكتمل', 0xFF10B981),
  cancelled('cancelled', 'Cancelled', 'ملغي', 0xFFEF4444),
  noShow('no_show', 'No Show', 'لم يحضر', 0xFF64748B);

  const AppointmentStatus(this.value, this.labelEn, this.labelAr, this.colorValue);
  final String value;
  final String labelEn;
  final String labelAr;
  final int colorValue;
}

/// Medical specialties.
enum MedicalSpecialty {
  generalPractice('general_practice', 'General Practice', 'طب عام', '🩺'),
  cardiology('cardiology', 'Cardiology', 'قلب', '❤️'),
  dermatology('dermatology', 'Dermatology', 'جلدية', '🧴'),
  neurology('neurology', 'Neurology', 'أعصاب', '🧠'),
  orthopedics('orthopedics', 'Orthopedics', 'عظام', '🦴'),
  pediatrics('pediatrics', 'Pediatrics', 'أطفال', '👶'),
  ophthalmology('ophthalmology', 'Ophthalmology', 'عيون', '👁️'),
  dentistry('dentistry', 'Dentistry', 'أسنان', '🦷'),
  gynecology('gynecology', 'Gynecology', 'نساء وتوليد', '🤰'),
  urology('urology', 'Urology', 'مسالك بولية', '🏥'),
  ent('ent', 'ENT', 'أنف أذن حنجرة', '👂'),
  psychiatry('psychiatry', 'Psychiatry', 'نفسية', '🧘'),
  radiology('radiology', 'Radiology', 'أشعة', '📡'),
  laboratory('laboratory', 'Laboratory', 'مختبر', '🔬');

  const MedicalSpecialty(this.value, this.labelEn, this.labelAr, this.emoji);
  final String value;
  final String labelEn;
  final String labelAr;
  final String emoji;
}

/// Gender enum.
enum Gender {
  male('male', 'Male', 'ذكر'),
  female('female', 'Female', 'أنثى');

  const Gender(this.value, this.labelEn, this.labelAr);
  final String value;
  final String labelEn;
  final String labelAr;
}

/// Payment status.
enum PaymentStatus {
  unpaid('unpaid', 'Unpaid', 'غير مدفوع'),
  paid('paid', 'Paid', 'مدفوع'),
  partial('partial', 'Partial', 'جزئي'),
  refunded('refunded', 'Refunded', 'مسترد');

  const PaymentStatus(this.value, this.labelEn, this.labelAr);
  final String value;
  final String labelEn;
  final String labelAr;
}

/// Day of week for availability.
enum DayOfWeek {
  monday('monday', 'Monday', 'الاثنين'),
  tuesday('tuesday', 'Tuesday', 'الثلاثاء'),
  wednesday('wednesday', 'Wednesday', 'الأربعاء'),
  thursday('thursday', 'Thursday', 'الخميس'),
  friday('friday', 'Friday', 'الجمعة'),
  saturday('saturday', 'Saturday', 'السبت'),
  sunday('sunday', 'Sunday', 'الأحد');

  const DayOfWeek(this.value, this.labelEn, this.labelAr);
  final String value;
  final String labelEn;
  final String labelAr;
}
