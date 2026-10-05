enum UserRole {
  patient('patient'),
  doctor('doctor'),
  admin('admin');

  const UserRole(this.value);
  final String value;
}

enum AppointmentStatus {
  pending('pending'),
  confirmed('confirmed'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  noShow('no_show');

  const AppointmentStatus(this.value);
  final String value;
}

enum MedicalSpecialty {
  generalPractice('general_practice'),
  cardiology('cardiology'),
  dermatology('dermatology'),
  neurology('neurology'),
  orthopedics('orthopedics'),
  pediatrics('pediatrics'),
  ophthalmology('ophthalmology'),
  dentistry('dentistry'),
  gynecology('gynecology'),
  urology('urology'),
  ent('ent'),
  psychiatry('psychiatry'),
  radiology('radiology'),
  laboratory('laboratory');

  const MedicalSpecialty(this.value);
  final String value;
}

enum Gender {
  male('male'),
  female('female');

  const Gender(this.value);
  final String value;
}

enum PaymentStatus {
  unpaid('unpaid'),
  paid('paid'),
  partial('partial'),
  refunded('refunded');

  const PaymentStatus(this.value);
  final String value;
}

enum DayOfWeek {
  monday('monday'),
  tuesday('tuesday'),
  wednesday('wednesday'),
  thursday('thursday'),
  friday('friday'),
  saturday('saturday'),
  sunday('sunday');

  const DayOfWeek(this.value);
  final String value;
}
