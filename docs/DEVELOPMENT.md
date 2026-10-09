# Development baseline

## Toolchain

Use Flutter **3.47.4 stable**, which includes Dart **3.13.3**. This is the exact toolchain used for batch B1; other SDK versions have not been verified. `pubspec.yaml` declares these as minimum SDK versions, and the committed `pubspec.lock` records the resolved dependencies.

Check your installation with `flutter --version` before running:

```bash
flutter pub get --enforce-lockfile
dart run tool/check_architecture.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

Run formatting with `dart format lib test tool integration_test test_driver`. Verify the committed formatting baseline with:

```bash
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
```

No Firebase configuration, external font service or platform plugin is needed for the current demo. New dependencies should be introduced with working features and tests, rather than reserved for speculative functionality.

## Startup behavior

The splash shows for three seconds, then opens onboarding. Skip opens the login screen. Startup tests advance the clock explicitly while the splash spinner is active; an indeterminate spinner cannot be waited out with `pumpAndSettle`.

The splash owns and cancels its navigation timer, and onboarding disposes its page controller. Riverpod owns router/container disposal. The router now keeps one instance through auth loading/login/logout changes; role guards and scoped read providers are implemented in B3. Demo sessions intentionally require login after restart; confirmed reset drops registrations/writes and cancels pending view-model results, while logout keeps synthetic clinic data and clears per-account reads/filters.

Time-dependent providers watch a shared presentation clock that ticks every 30 seconds. It never reseeds the clinic; repositories validate mutations against the injected clock at write time. The provider owns/cancels its timer. Widget tests with an externally owned container dispose that container before test invariants run, as well as using teardown for failure cleanup.

Fonts use Flutter's platform defaults. Typography sizes, weights and colors remain defined in `AppTheme`; Inter is no longer downloaded at runtime. Page transitions use the SDK's platform defaults.

## Verification limits

- The Flutter suite includes demo business/UI workflows, Mockito interactions, role guards, profile/management/billing races and confirmation flows, charts and time boundaries. Firebase adapter tests cover trusted sessions, stale credentials/reads, configuration, mapping and cleared access; mode-specific widgets exercise patient-only registration, recovery and asynchronous availability. See [the architecture guide](ARCHITECTURE.md) and [Firebase verification](FIREBASE.md) for separate SDK/emulator evidence.
- Web builds verify compilation; they do not establish browser interaction, cold offline caching or production readiness.
- Firebase adapters, rules and callable commands are implemented. Backend/browser integration uses a separate explicit emulator command; a unit/widget run does not execute it. Live deployment is unverified. UI language is intentionally English; Firebase password recovery is available, with no unsupported translation/notification/upload controls advertised.
- Android, iOS and desktop build/runtime checks have not been run for this baseline. Generated desktop plugin registrants are refreshed by `flutter pub get` when dependencies change.

See [the repair plan](REPAIR_PLAN.md) for batch progress and [the baseline audit](PROJECT_AUDIT.md) for starting-state evidence.
