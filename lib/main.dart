import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/app_dependencies.dart';
import 'core/config/backend_configuration.dart';
import 'core/firebase/firebase_runtime.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    final configuration = BackendConfiguration.fromEnvironment();
    final runtime = configuration.isDemo
        ? null
        : await FirebaseRuntime.initialize(configuration);
    runApp(
      ProviderScope(
        overrides: [
          backendConfigurationProvider.overrideWithValue(configuration),
          if (runtime != null)
            firebaseRuntimeProvider.overrideWithValue(runtime),
        ],
        child: const MediFlowApp(),
      ),
    );
  } catch (error) {
    runApp(
      StartupFailureApp(
        message: error is ConfigurationFailure ? error.message : 'The clinic service could not start. Check the connection and Firebase configuration, then restart.',
      ),
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  final String message;
  const StartupFailureApp({super.key, required this.message});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediFlow Pro',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text('Clinic configuration required'),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Root application widget.
class MediFlowApp extends ConsumerWidget {
  const MediFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MediFlow Pro',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      routerConfig: router,
    );
  }
}
