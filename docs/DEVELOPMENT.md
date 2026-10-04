# Development baseline

## Toolchain

Use Flutter **3.47.4 stable**, which includes Dart **3.13.3**. This is the exact toolchain used for batch B1; other SDK versions have not been verified. `pubspec.yaml` declares these as minimum SDK versions, and the committed `pubspec.lock` records the resolved dependencies.

Check your installation with `flutter --version` before running:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

Run formatting with `dart format lib test`. Verify the committed formatting baseline with:

```bash
dart format --output=none --set-exit-if-changed lib test
```

No Firebase configuration, external font service or platform plugin is needed for the current demo. New dependencies should be introduced with working features and tests, rather than reserved for speculative functionality.

## Startup behavior

The splash shows for three seconds, then opens onboarding. Skip opens the login screen. Startup tests advance the clock explicitly while the splash spinner is active; an indeterminate spinner cannot be waited out with `pumpAndSettle`.

The splash owns and cancels its navigation timer, and onboarding disposes its page controller. The tests explicitly dispose their router/container; the router lifecycle and role checks in the application remain scheduled for B3.

Fonts use Flutter's platform defaults. Typography sizes, weights and colors remain defined in `AppTheme`; Inter is no longer downloaded at runtime. Page transitions use the SDK's platform defaults.

## Verification limits

- Startup widget tests verify navigation to sign-in in light and dark modes, exact splash timing, and early splash disposal.
- Web builds verify compilation; they do not establish browser interaction, cold offline caching or production readiness.
- Complete appointment, authorization, management and analytics tests arrive with the corresponding repair batches.
- Android, iOS and desktop build/runtime checks have not been run for this baseline. Generated desktop plugin registrants are refreshed by `flutter pub get` when dependencies change.

See [the repair plan](REPAIR_PLAN.md) for batch progress and [the baseline audit](PROJECT_AUDIT.md) for starting-state evidence.
