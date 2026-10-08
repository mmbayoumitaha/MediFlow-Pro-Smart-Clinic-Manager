import 'entities.dart';

/// A remote authority validates conflicts against records the caller cannot
/// read. The demo instead validates its complete synthetic snapshot locally.
abstract interface class AuthoritativeReservations {
  Future<Appointment> reserve(Appointment request);
  Future<List<DateTime>> availableSlots({
    required String doctorId,
    required DateTime date,
  });
}
