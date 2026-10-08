enum BackendMode { demo, firebase }

class BackendConfiguration {
  final BackendMode mode;
  final bool useEmulators;
  final String projectId, apiKey, appId, messagingSenderId, authDomain;
  final String emulatorHost;
  bool get isDemo => mode == BackendMode.demo;

  const BackendConfiguration.demo()
    : mode = BackendMode.demo,
      useEmulators = false,
      projectId = '',
      apiKey = '',
      appId = '',
      messagingSenderId = '',
      authDomain = '',
      emulatorHost = '';

  const BackendConfiguration._({
    required this.mode,
    required this.useEmulators,
    required this.projectId,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.authDomain,
    required this.emulatorHost,
  });

  factory BackendConfiguration.fromDefines(Map<String, String> defines) {
    final mode = defines['BACKEND_MODE'] ?? 'demo';
    if (mode == 'demo') return const BackendConfiguration.demo();
    if (mode != 'firebase') {
      throw const ConfigurationFailure(
        'BACKEND_MODE must be demo or firebase.',
      );
    }
    final emulators = defines['FIREBASE_EMULATORS'] ?? 'false';
    if (!['true', 'false'].contains(emulators)) {
      throw const ConfigurationFailure(
        'FIREBASE_EMULATORS must be true or false.',
      );
    }
    String requiredValue(String key) {
      final value = defines[key]?.trim() ?? '';
      if (value.isEmpty || value.startsWith('REPLACE_')) {
        throw ConfigurationFailure(
          'Provide $key in your local Firebase configuration.',
        );
      }
      return value;
    }

    final project = requiredValue('FIREBASE_PROJECT_ID');
    final useEmulators = emulators == 'true';
    if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(project)) {
      throw const ConfigurationFailure('Invalid Firebase project ID.');
    }
    if (useEmulators != project.startsWith('demo-')) {
      throw const ConfigurationFailure(
        'Emulators require a demo- project; live mode requires a real project.',
      );
    }
    final host = defines['FIREBASE_EMULATOR_HOST']?.trim() ?? '127.0.0.1';
    if (useEmulators &&
        (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(host) || host.contains('..'))) {
      throw const ConfigurationFailure(
        'Use a hostname or IPv4 address for FIREBASE_EMULATOR_HOST.',
      );
    }
    return BackendConfiguration._(
      mode: BackendMode.firebase,
      useEmulators: useEmulators,
      projectId: project,
      apiKey: requiredValue('FIREBASE_API_KEY'),
      appId: requiredValue('FIREBASE_APP_ID'),
      messagingSenderId: requiredValue('FIREBASE_MESSAGING_SENDER_ID'),
      authDomain: defines['FIREBASE_AUTH_DOMAIN']?.trim().isNotEmpty == true
          ? defines['FIREBASE_AUTH_DOMAIN']!.trim()
          : '$project.firebaseapp.com',
      emulatorHost: host,
    );
  }

  factory BackendConfiguration.fromEnvironment() =>
      BackendConfiguration.fromDefines(const {
        'BACKEND_MODE': String.fromEnvironment(
          'BACKEND_MODE',
          defaultValue: 'demo',
        ),
        'FIREBASE_EMULATORS': String.fromEnvironment(
          'FIREBASE_EMULATORS',
          defaultValue: 'false',
        ),
        'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
        'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
        'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
        'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        'FIREBASE_EMULATOR_HOST': String.fromEnvironment(
          'FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        ),
      });
}

class ConfigurationFailure implements Exception {
  final String message;
  const ConfigurationFailure(this.message);
}
