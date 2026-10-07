import 'app_enums.dart';
import 'billing_policy.dart';
import 'clinic_failure.dart';
import 'entities.dart';

class ContactInput {
  final String fullName;
  final String phone;
  final String? address;
  final bool isActive;
  const ContactInput({
    required this.fullName,
    required this.phone,
    this.address,
    this.isActive = true,
  });
}

class DoctorInput {
  final String fullName, email, phone;
  final String? bio;
  final MedicalSpecialty specialty;
  final double consultationFee;
  final int experienceYears;
  final List<AvailabilitySlot> availability;
  final bool isAvailable;
  DoctorInput({
    required this.fullName,
    required this.email,
    required this.phone,
    this.bio,
    required this.specialty,
    required this.consultationFee,
    required this.experienceYears,
    required List<AvailabilitySlot> availability,
    required this.isAvailable,
  }) : availability = List.unmodifiable(availability);
}

abstract final class ProfilePolicy {
  static void contact(String name, String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().length < 3 ||
        digits.length < 8 ||
        digits.length > 15 ||
        !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone.trim())) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Enter a full name and a valid phone number.',
      );
    }
  }

  static void admin(ClinicUser? actor) {
    if (actor == null || !actor.isActive || actor.role != UserRole.admin) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Only an active administrator can manage clinic profiles.',
      );
    }
  }

  static void active(ClinicUser? actor) {
    if (actor == null || !actor.isActive) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Sign in to edit a profile.',
      );
    }
  }

  static void doctor(DoctorInput input) {
    contact(input.fullName, input.phone);
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input.email.trim()) ||
        input.email.trim().toLowerCase() == 'demo@mediflow.com' ||
        input.experienceYears < 0 ||
        input.experienceYears > 80) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Enter a valid doctor email and experience (0–80 years).',
      );
    }
    BillingPolicy.cents(input.consultationFee);
    int minutes(String value) {
      if (!RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'Use working times in HH:mm format.',
        );
      }
      final parts = value.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }

    for (final slot in input.availability) {
      if (minutes(slot.endTime) - minutes(slot.startTime) < 30) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'Each working period must allow a 30-minute visit and end on the same day.',
        );
      }
    }
    for (final day in DayOfWeek.values) {
      final periods =
          input.availability.where((s) => s.day == day && s.isActive).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (var i = 1; i < periods.length; i++) {
        if (periods[i].startTime.compareTo(periods[i - 1].endTime) < 0) {
          throw const ClinicFailure(
            FailureCode.invalidInput,
            'Active working periods must not overlap.',
          );
        }
      }
    }
    if (input.isAvailable && !input.availability.any((s) => s.isActive)) {
      throw const ClinicFailure(
        FailureCode.invalidInput,
        'Add an active working period before enabling booking.',
      );
    }
  }

  static bool samePatient(ClinicUser a, ClinicUser b) =>
      a.id == b.id &&
      a.fullName == b.fullName &&
      a.phone == b.phone &&
      a.address == b.address &&
      a.isActive == b.isActive;
  static bool sameDoctor(Doctor a, Doctor b) =>
      a.id == b.id &&
      a.userId == b.userId &&
      a.fullName == b.fullName &&
      a.phone == b.phone &&
      a.email == b.email &&
      a.bio == b.bio &&
      a.specialty == b.specialty &&
      a.consultationFee == b.consultationFee &&
      a.experienceYears == b.experienceYears &&
      a.isAvailable == b.isAvailable &&
      sameAvailability(a.availability, b.availability);
  static bool sameAvailability(
    List<AvailabilitySlot> a,
    List<AvailabilitySlot> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].day != b[i].day ||
          a[i].startTime != b[i].startTime ||
          a[i].endTime != b[i].endTime ||
          a[i].isActive != b[i].isActive) {
        return false;
      }
    }
    return true;
  }
}
