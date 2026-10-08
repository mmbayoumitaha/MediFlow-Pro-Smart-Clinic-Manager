import 'package:timezone/data/latest.dart' as database;
import 'package:timezone/timezone.dart' as tz;

/// Backend domain dates retain their real instant and render in clinic time.
/// Calendar selections (year/month/day) are sent separately as date strings.
class ClinicClock {
  static const zone = 'Africa/Cairo';
  final tz.Location location;

  factory ClinicClock() {
    database.initializeTimeZones();
    return ClinicClock._(tz.getLocation(zone));
  }
  const ClinicClock._(this.location);
  DateTime now() => inClinic(DateTime.now());
  DateTime inClinic(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), location);
  DateTime fromMilliseconds(int milliseconds) =>
      tz.TZDateTime.fromMillisecondsSinceEpoch(location, milliseconds);
  String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
