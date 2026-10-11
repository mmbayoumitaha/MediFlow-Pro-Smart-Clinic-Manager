import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/firebase/clinic_calendar.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';

void main() {
  test('first clinic initialization covers the UTC/Cairo year boundary', () {
    final clock = ClinicClock();
    final instant = DateTime.utc(2025, 12, 31, 22, 30);
    final calendar = ClinicCalendar(clock);
    expect(clock.inClinic(instant).year, 2026);
    expect(calendar.requiredYears(instant), {2025, 2026, 2027});
    expect(calendar.requiredYears(DateTime.utc(2025, 12, 31, 20)), {
      2025,
      2026,
    });
    for (final year in calendar.requiredYears(instant)) {
      final values = calendar.transitions(year);
      expect(values['dstStart']!.year, year);
      expect(values['dstEnd']!.year, year);
    }
  });
  test('trusted Cairo calendar encodes the actual 2026 DST boundaries', () {
    final clock = ClinicClock();
    final values = ClinicCalendar(clock).transitions(2026);
    expect(values['dstStart'], DateTime.utc(2026, 4, 23, 22));
    expect(values['dstEnd'], DateTime.utc(2026, 10, 29, 21));
    for (final entry in values.entries) {
      final at = entry.value;
      final before = clock.inClinic(at.subtract(const Duration(seconds: 1)));
      final after = clock.inClinic(at);
      expect(
        before.timeZoneOffset,
        entry.key == 'dstStart'
            ? const Duration(hours: 2)
            : const Duration(hours: 3),
      );
      expect(
        after.timeZoneOffset,
        entry.key == 'dstStart'
            ? const Duration(hours: 3)
            : const Duration(hours: 2),
      );
    }
  });
  test(
    'calendar metadata covers the following year without reusing old DST dates',
    () {
      final values = ClinicCalendar(ClinicClock()).transitions(2027);
      expect(values['dstStart'], DateTime.utc(2027, 4, 29, 22));
      expect(values['dstEnd'], DateTime.utc(2027, 10, 28, 21));
    },
  );
}
