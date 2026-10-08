import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/config/backend_configuration.dart';
import 'package:mediflow/core/firebase/clinic_clock.dart';

void main() {
  final emulator =
      (jsonDecode(File('config/firebase.emulator.json').readAsStringSync())
              as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as String));
  test('default demo needs no backend config, and Firebase options alone cannot enable it', () {
    expect(BackendConfiguration.fromDefines({}).isDemo, isTrue);
    expect(
      BackendConfiguration.fromDefines({...emulator, 'BACKEND_MODE': 'demo'})
          .isDemo,
      isTrue,
    );
  });
  test('committed emulator configuration is explicitly isolated from live projects', () {
    final config = BackendConfiguration.fromDefines(emulator);
    expect(config.mode, BackendMode.firebase);
    expect(config.useEmulators, isTrue);
    expect(config.projectId, 'demo-mediflow');
    expect(config.emulatorHost, '127.0.0.1');
    for (final mutation in [
      {'BACKEND_MODE': 'typo'},
      {'FIREBASE_EMULATORS': 'yes'},
      {'FIREBASE_EMULATORS': 'false'},
      {'FIREBASE_PROJECT_ID': 'real-project'},
      {'FIREBASE_EMULATOR_HOST': 'http://localhost:9099'},
      {'FIREBASE_APP_ID': ''},
    ]) {
      expect(
        () => BackendConfiguration.fromDefines({...emulator, ...mutation}),
        throwsA(isA<ConfigurationFailure>()),
      );
    }
  });
  test('live config requires complete options and placeholders fail before SDK initialization', () {
    final live = {
      ...emulator,
      'FIREBASE_EMULATORS': 'false',
      'FIREBASE_PROJECT_ID': 'clinic-example',
    };
    expect(BackendConfiguration.fromDefines(live).useEmulators, isFalse);
    for (final key in [
      'FIREBASE_PROJECT_ID',
      'FIREBASE_API_KEY',
      'FIREBASE_APP_ID',
      'FIREBASE_MESSAGING_SENDER_ID',
    ]) {
      expect(
        () => BackendConfiguration.fromDefines({...live, key: ''}),
        throwsA(isA<ConfigurationFailure>()),
      );
      expect(
        () => BackendConfiguration.fromDefines({...live, key: 'REPLACE_VALUE'}),
        throwsA(isA<ConfigurationFailure>()),
      );
    }
  });
  test('clinic time retains instants and changes Cairo offsets across both DST boundaries', () {
    final clock = ClinicClock();
    for (final sample in [
      ('2026-04-23T21:30:00Z', 23, 2, '2026-04-23'),
      ('2026-04-23T22:30:00Z', 1, 3, '2026-04-24'),
      ('2026-10-29T20:30:00Z', 23, 3, '2026-10-29'),
      ('2026-10-29T21:30:00Z', 23, 2, '2026-10-29'),
      ('2026-12-31T23:30:00Z', 1, 2, '2027-01-01'),
    ]) {
      final instant = DateTime.parse(sample.$1),
          displayed = clock.inClinic(instant);
      expect(displayed.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
      expect(displayed.hour, sample.$2);
      expect(displayed.timeZoneOffset.inHours, sample.$3);
      expect(clock.dateKey(displayed), sample.$4);
      expect(displayed.isUtc, isFalse);
    }
  });
}
