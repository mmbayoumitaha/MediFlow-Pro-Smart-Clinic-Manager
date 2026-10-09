import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clinic_repository.dart';
import '../domain/clinic_readiness.dart';
import '../domain/clinic_snapshot.dart';

class ClinicViewModel extends StateNotifier<AsyncValue<ClinicSnapshot>> {
  final ClinicRepository _repository;
  late final StreamSubscription<ClinicSnapshot> _subscription;
  int _revision = 0;
  int _request = 0;

  ClinicViewModel(this._repository) : super(const AsyncLoading()) {
    _subscription = _repository.watch().listen(
      (snapshot) {
        if (!mounted) return;
        _revision++;
        final source = _repository;
        state =
            source is ClinicReadiness && !(source as ClinicReadiness).isReady
            ? const AsyncLoading()
            : AsyncData(snapshot);
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        _revision++;
        state = AsyncError<ClinicSnapshot>(
          error,
          stack,
        ).copyWithPrevious(state);
      },
    );
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final request = ++_request;
    final revision = _revision;
    state = const AsyncLoading<ClinicSnapshot>().copyWithPrevious(state);
    try {
      final snapshot = await _repository.load();
      if (mounted && request == _request && revision == _revision) {
        state = AsyncData(snapshot);
      }
    } catch (error, stack) {
      if (mounted && request == _request && revision == _revision) {
        state = AsyncError<ClinicSnapshot>(
          error,
          stack,
        ).copyWithPrevious(state);
      }
    }
  }

  @override
  void dispose() {
    _request++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
