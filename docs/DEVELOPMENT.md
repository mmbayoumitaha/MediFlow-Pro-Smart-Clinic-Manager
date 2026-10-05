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

Run formatting with `dart format lib test tool`. Verify the committed formatting baseline with:

```bash
dart format --output=none --set-exit-if-changed lib test tool
```

No Firebase configuration, external font service or platform plugin is needed for the current demo. New dependencies should be introduced with working features and tests, rather than reserved for speculative functionality.

## Startup behavior

The splash shows for three seconds, then opens onboarding. Skip opens the login screen. Startup tests advance the clock explicitly while the splash spinner is active; an indeterminate spinner cannot be waited out with `pumpAndSettle`.

The splash owns and cancels its navigation timer, and onboarding disposes its page controller. Riverpod owns router/container disposal. The router now keeps one instance through auth loading/login/logout changes; cross-role route guards and data scoping remain B3.

Fonts use Flutter's platform defaults. Typography sizes, weights and colors remain defined in `AppTheme`; Inter is no longer downloaded at runtime. Page transitions use the SDK's platform defaults.

## Verification limits

- The 46 tests include startup in light/dark modes, immutable entities and storage validation, demo repository behavior, Mockito use-case/view-model tests, late auth/refresh completion, role sign-in/logout, selected-time booking and loading/error/retry UI. See [the architecture guide](ARCHITECTURE.md) for mock generation and boundary checks.
- Web builds verify compilation; they do not establish browser interaction, cold offline caching or production readiness.
- Complete appointment, authorization, management and analytics tests arrive with the corresponding repair batches.
- Android, iOS and desktop build/runtime checks have not been run for this baseline. Generated desktop plugin registrants are refreshed by `flutter pub get` when dependencies change.

See [the repair plan](REPAIR_PLAN.md) for batch progress and [the baseline audit](PROJECT_AUDIT.md) for starting-state evidence.
