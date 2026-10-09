import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/data/firebase_auth_gateway.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/auth_session.dart';
import '../../features/clinic/data/demo_clinic_repository.dart';
import '../../features/clinic/data/firebase_clinic_mapper.dart';
import '../../features/clinic/data/firebase_clinic_records.dart';
import '../../features/clinic/data/firebase_clinic_repository.dart';
import '../../features/clinic/domain/clinic_repository.dart';
import '../config/backend_configuration.dart';
import '../firebase/clinic_commands.dart';
import '../firebase/firebase_runtime.dart';

/// The composition root is the only place that selects concrete adapters.
final backendConfigurationProvider = Provider<BackendConfiguration>(
  (ref) => const BackendConfiguration.demo(),
);
final isDemoProvider = Provider<bool>(
  (ref) => ref.watch(backendConfigurationProvider).isDemo,
);
final firebaseRuntimeProvider = Provider<FirebaseRuntime>(
  (ref) => throw StateError('Initialize Firebase before opening backend mode.'),
);
final clockProvider = Provider<DateTime Function()>(
  (ref) => ref.watch(isDemoProvider)
      ? DateTime.now
      : ref.watch(firebaseRuntimeProvider).clock.now,
);

/// Presentation time advances independently of the repository's seed clock.
final liveClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  return Stream.multi((controller) {
    controller.add(clock());
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => controller.add(clock()),
    );
    controller.onCancel = () => timer?.cancel();
  });
});
final clinicTimeProvider = Provider<DateTime>(
  (ref) =>
      ref.watch(liveClockProvider).valueOrNull ?? ref.watch(clockProvider)(),
);
final idGeneratorProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  if (!ref.watch(isDemoProvider)) {
    final runtime = ref.watch(firebaseRuntimeProvider);
    final mapper = FirebaseClinicMapper(runtime.clock);
    final repository = FirebaseClinicRepository(
      ref.watch(authRepositoryProvider) as AuthSessionSource,
      FirebaseClinicRecords(runtime.firestore, mapper),
      FirebaseClinicCommands(runtime.functions),
      mapper,
      runtime.clock,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final clock = ref.watch(clockProvider);
  final repository = DemoClinicRepository(at: clock(), now: clock);
  ref.onDispose(repository.dispose);
  return repository;
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      if (!ref.watch(isDemoProvider)) {
        final runtime = ref.watch(firebaseRuntimeProvider);
        final repository = FirebaseAuthRepository(
          FirebaseSdkIdentity(runtime.auth),
          FirebaseSdkProfiles(
            runtime.firestore,
            FirebaseClinicMapper(runtime.clock),
          ),
          FirebaseClinicCommands(runtime.functions),
        );
        ref.onDispose(repository.dispose);
        return repository;
      }
      return DemoAuthRepository(
        ref.watch(clinicRepositoryProvider),
        now: ref.watch(clockProvider),
        newId: ref.watch(idGeneratorProvider),
      );
    });
