import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/clinic/data/demo_clinic_repository.dart';
import '../../features/clinic/domain/clinic_repository.dart';

/// The composition root is the only place that selects concrete adapters.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
  final clock = ref.watch(clockProvider);
  final repository = DemoClinicRepository(at: clock(), now: clock);
  ref.onDispose(repository.dispose);
  return repository;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DemoAuthRepository(
    ref.watch(clinicRepositoryProvider),
    now: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);
