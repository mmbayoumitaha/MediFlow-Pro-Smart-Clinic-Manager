import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/clinic/data/demo_clinic_repository.dart';
import '../../features/clinic/domain/clinic_repository.dart';

/// The composition root is the only place that selects concrete adapters.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
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
