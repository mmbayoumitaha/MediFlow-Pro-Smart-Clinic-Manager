import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/backend_configuration.dart';
import 'clinic_clock.dart';

class FirebaseRuntime {
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final ClinicClock clock;
  const FirebaseRuntime._(
    this.app,
    this.auth,
    this.firestore,
    this.functions,
    this.clock,
  );

  static Future<FirebaseRuntime> initialize(BackendConfiguration config) async {
    if (config.isDemo) {
      throw const ConfigurationFailure(
        'Firebase initialization requires explicit Firebase mode.',
      );
    }
    final app = await Firebase.initializeApp(
      name: 'mediflow',
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        authDomain: config.authDomain,
      ),
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      final functions = FirebaseFunctions.instanceFor(
        app: app,
        region: 'us-central1',
      );
      // Clinical records are not persisted to disk. Role restoration requires a
      // confirmed server profile, independently of cached Firebase Auth state.
      firestore.settings = const Settings(persistenceEnabled: false);
      if (config.useEmulators) {
        await auth.useAuthEmulator(
          config.emulatorHost,
          19099,
          automaticHostMapping: false,
        );
        firestore.useFirestoreEmulator(
          config.emulatorHost,
          18080,
          automaticHostMapping: false,
        );
        functions.useFunctionsEmulator(
          config.emulatorHost,
          15001,
          automaticHostMapping: false,
        );
      }
      if (kIsWeb) await auth.setPersistence(Persistence.SESSION);
      return FirebaseRuntime._(app, auth, firestore, functions, ClinicClock());
    } catch (_) {
      await app.delete();
      rethrow;
    }
  }
}
