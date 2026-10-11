import 'clinic_clock.dart';

/// Trusted operator calendar metadata for Firestore's Cairo-time checks.
/// Egypt's supported standard/daylight offsets are explicit, never device time.
class ClinicCalendar {
  final ClinicClock clock;
  const ClinicCalendar(this.clock);

  Map<String, DateTime> transitions(int year) {
    final first = DateTime.utc(year);
    final end = DateTime.utc(year + 1);
    var previous = clock.inClinic(first).timeZoneOffset.inMinutes;
    final changes = <DateTime>[];
    for (
      var instant = first.add(const Duration(hours: 1));
      instant.isBefore(end);
      instant = instant.add(const Duration(hours: 1))
    ) {
      final offset = clock.inClinic(instant).timeZoneOffset.inMinutes;
      if (offset != previous) {
        if (!((previous == 120 && offset == 180) ||
            (previous == 180 && offset == 120))) {
          throw StateError('Unsupported clinic timezone transition.');
        }
        changes.add(instant);
        previous = offset;
      }
    }
    if (changes.length != 2 ||
        clock.inClinic(first).timeZoneOffset.inMinutes != 120 ||
        clock.inClinic(changes.first).timeZoneOffset.inMinutes != 180 ||
        clock.inClinic(changes.last).timeZoneOffset.inMinutes != 120) {
      throw StateError('Update the trusted clinic calendar before booking.');
    }
    return {'dstStart': changes.first, 'dstEnd': changes.last};
  }
}
