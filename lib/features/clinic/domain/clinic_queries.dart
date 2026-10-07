import 'app_enums.dart';
import 'clinic_snapshot.dart';
import 'entities.dart';

abstract final class ClinicQueries {
  static List<DateTime> dateOptions(DateTime now) => List.unmodifiable(
    List.generate(
      14,
      (index) => DateTime(now.year, now.month, now.day + index + 1),
    ),
  );

  static List<Doctor> doctors(
    List<Doctor> input,
    MedicalSpecialty? specialty,
    String query,
  ) {
    final search = query.trim().toLowerCase();
    return List.unmodifiable(
      input.where(
        (doctor) =>
            (specialty == null || doctor.specialty == specialty) &&
            (doctor.fullName.toLowerCase().contains(search) ||
                doctor.specialty.value.replaceAll('_', ' ').contains(search)),
      ),
    );
  }

  static List<Appointment> schedule(List<Appointment> input) =>
      List.unmodifiable(
        List<Appointment>.of(input)
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      );

  static bool isUpcoming(Appointment a, DateTime now) =>
      a.status == AppointmentStatus.inProgress ||
      ((a.status == AppointmentStatus.pending ||
              a.status == AppointmentStatus.confirmed) &&
          !a.dateTime.isBefore(now));
  static List<Appointment> upcoming(List<Appointment> input, DateTime now) =>
      schedule(input.where((a) => isUpcoming(a, now)).toList());

  static List<Appointment> past(List<Appointment> input, DateTime now) =>
      List.unmodifiable(
        input.where((a) => !isUpcoming(a, now)).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
      );
}

/// Shared calculations are domain behavior, rather than widget build logic.
class ClinicMetrics {
  final List<Appointment> today;
  final List<Appointment> pending;
  final List<Appointment> completed;
  final double paidInvoiceRevenue;
  final double completedAppointmentFees;

  ClinicMetrics(ClinicSnapshot snapshot, DateTime now)
    : today = List.unmodifiable(
        snapshot.appointments.where(
          (a) =>
              a.dateTime.year == now.year &&
              a.dateTime.month == now.month &&
              a.dateTime.day == now.day,
        ),
      ),
      pending = List.unmodifiable(
        snapshot.appointments.where(
          (a) => a.status == AppointmentStatus.pending,
        ),
      ),
      completed = List.unmodifiable(
        snapshot.appointments.where(
          (a) => a.status == AppointmentStatus.completed,
        ),
      ),
      paidInvoiceRevenue = snapshot.invoices
          .where((i) => i.paymentStatus == PaymentStatus.paid)
          .fold(0, (sum, invoice) => sum + invoice.total),
      completedAppointmentFees = snapshot.appointments
          .where((a) => a.status == AppointmentStatus.completed)
          .fold(0, (sum, appointment) => sum + appointment.fee);
}
