/// A weekly 30-minute grid keeps every schedule safe to decode and rules cheap.
/// Domain/presentation receive the actual bookable HH:mm periods.
abstract final class FirestoreSchedule {
  static const days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static int _minute(String text) {
    if (!RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(text)) {
      throw const FormatException('Invalid clinic working time.');
    }
    final parts = text.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  static String _text(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  static Map<String, String> toStorage(List<dynamic> rows) {
    final bits = {for (final day in days) day: List.filled(48, '0')};
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final day = row['day'] as String;
      final start = _minute(row['startTime'] as String),
          end = _minute(row['endTime'] as String);
      if (!bits.containsKey(day) ||
          end - start < 30 ||
          row['isActive'] is! bool) {
        throw const FormatException('Invalid clinic working period.');
      }
      if (row['isActive'] != true) continue;
      for (
        var index = (start + 29) ~/ 30;
        index < 47 && (index + 1) * 30 <= end;
        index++
      ) {
        bits[day]![index] = '1';
      }
    }
    return bits.map((day, values) => MapEntry(day, values.join()));
  }

  static List<Map<String, dynamic>> fromStorage(Object? raw) {
    if (raw is Map) {
      if (raw.length != 7 || !days.every(raw.containsKey)) {
        throw const FormatException('Invalid clinic week.');
      }
      final periods = <Map<String, dynamic>>[];
      for (final day in days) {
        final bitmap = raw[day];
        if (bitmap is! String || !RegExp(r'^[01]{47}0$').hasMatch(bitmap)) {
          throw const FormatException('Invalid clinic schedule.');
        }
        var index = 0;
        while (index < 48) {
          if (bitmap[index] == '0') {
            index++;
            continue;
          }
          final start = index;
          while (index < 48 && bitmap[index] == '1') {
            index++;
          }
          periods.add({
            'day': day,
            'startTime': _text(start * 30),
            'endTime': _text(index * 30),
            'isActive': true,
          });
        }
      }
      return periods;
    }
    // Read previous schemas for historical fixtures; new writes use the grid.
    if (raw is! List) {
      throw const FormatException('Invalid clinic working periods.');
    }
    return raw.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      if (!row.containsKey('startMinute') && !row.containsKey('endMinute')) {
        return row;
      }
      final start = row['startMinute'], end = row['endMinute'];
      if (start is! int ||
          end is! int ||
          start < 0 ||
          end > 1439 ||
          end - start < 30) {
        throw const FormatException('Invalid clinic working minute.');
      }
      return {
        'day': row['day'],
        'startTime': _text(start),
        'endTime': _text(end),
        'isActive': row['isActive'],
      };
    }).toList();
  }
}
