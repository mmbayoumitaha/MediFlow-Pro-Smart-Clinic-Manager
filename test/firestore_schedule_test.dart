import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/firestore_schedule.dart';

void main() {
  test('working periods normalize to the actual available half-hour grid', () {
    final original = [
      {
        'day': 'monday',
        'startTime': '09:15',
        'endTime': '17:45',
        'isActive': true,
      },
    ];
    final wire = FirestoreSchedule.toStorage(original);
    expect(wire['monday'], '${'0' * 19}${'1' * 16}${'0' * 13}');
    expect(wire['tuesday'], '0' * 48);
    expect(FirestoreSchedule.fromStorage(wire), [
      {
        'day': 'monday',
        'startTime': '09:30',
        'endTime': '17:30',
        'isActive': true,
      },
    ]);
    original.first['startTime'] = '12:00';
    expect(wire['monday'], '${'0' * 19}${'1' * 16}${'0' * 13}');
  });
  test('invalid times and malformed numeric bounds fail instead of normalizing into another slot', () {
    for (final value in ['24:00', '09:60', '9:00', '-1:00']) {
      expect(
        () => FirestoreSchedule.toStorage([
          {
            'day': 'monday',
            'startTime': value,
            'endTime': '17:00',
            'isActive': true,
          },
        ]),
        throwsFormatException,
      );
    }
    for (final value in [-1, 1440, 540.0, null]) {
      expect(
        () => FirestoreSchedule.fromStorage([
          {
            'day': 'monday',
            'startMinute': value,
            'endMinute': 1020,
            'isActive': true,
          },
        ]),
        throwsFormatException,
      );
    }
  });
  test('malformed weekly grids cannot expose invalid or overnight slots', () {
    final valid = FirestoreSchedule.toStorage([]);
    for (final week in [
      {...valid}..remove('monday'),
      {...valid, 'holiday': '0' * 48},
      {...valid, 'monday': '0' * 47},
      {...valid, 'monday': '${'0' * 47}2'},
      {...valid, 'monday': '${'0' * 47}1'},
      {...valid, 'monday': 0},
    ]) {
      expect(() => FirestoreSchedule.fromStorage(week), throwsFormatException);
    }
  });
}
