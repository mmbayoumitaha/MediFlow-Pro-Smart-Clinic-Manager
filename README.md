# MediFlow Pro — Smart Clinic Manager

A personal Flutter project for exploring patient, doctor and administrator clinic workflows. The current app runs with synthetic, in-memory demo data and requires no Firebase account or backend configuration.

The project is being repaired in tested batches. [The repair plan](docs/REPAIR_PLAN.md) tracks completed changes; [the baseline audit](docs/PROJECT_AUDIT.md) records the original findings.

## Current functionality

- Separate patient, doctor and administrator screens with persistent tab navigation using GoRouter.
- Doctor directory with working name/specialty search and filters, appointment booking and appointment/prescription lists backed by demo fixtures.
- Doctor schedule and patient browser; new demo registrations add linked patient/doctor profiles.
- Administrator overview, billing lists and fl_chart visualizations.
- Material 3 light/dark themes using Flutter's default fonts; the app no longer downloads Inter through Google Fonts.

Some visible actions are still placeholders. Role authorization, per-user data scoping, working-hours/conflict validation and chart calculations remain under repair. The demo contains fictional records; do not enter real patient information.

## Run the demo

Verified toolchain: **Flutter 3.47.4 stable / Dart 3.13.3**. Use this version to reproduce the development checks. The SDK minimums are declared in `pubspec.yaml`; dependency versions are recorded in `pubspec.lock`.

```bash
git clone https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager.git
cd MediFlow-Pro-Smart-Clinic-Manager
flutter pub get
flutter run -d chrome
```

On the login screen, select Patient, Doctor or Admin. The prefilled `demo@mediflow.com` / `password123` values open the selected demo role. Authentication is simulated; these are not real backend credentials.

Demo changes last for the current application session and reset when the app restarts. Initial dependency installation requires an Internet connection. The running demo uses local fixtures; a cold offline browser launch and browser caching have not been verified.

## Development checks

```bash
dart run tool/check_architecture.dart
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

The 46 tests cover startup, immutable entities/storage mapping, demo repositories, Mockito use-case/view-model interactions, auth and refresh races, registration, role sign-in/logout, selected-time booking and loading/error/retry UI. Complete clinic lifecycle and authorization checks remain in subsequent batches. See [development notes](docs/DEVELOPMENT.md) for toolchain details and the formatting check.

Web is the current build-verification target. Platform folders exist for Android, iOS and desktop; their build/runtime support is not yet verified.

## Architecture and roadmap

The current code uses Flutter, Riverpod, GoRouter, fl_chart, intl and uuid, plus the bundled Cupertino icon font for adaptive Flutter widgets. Auth and clinic features now separate framework-independent domain entities/use cases/repository contracts, demo data adapters and Riverpod presentation view models. Core providers inject repositories, clocks and ID generators; screens render immutable state and invoke view-model actions. Mockito unit tests verify repository interactions. See [the architecture guide](docs/ARCHITECTURE.md) for responsibilities and dependency boundaries.

Configurable Firebase Auth/Firestore adapters remain planned in subsequent [repair batches](docs/REPAIR_PLAN.md).

Unused Firebase, storage, upload and PDF dependencies were removed from the startup baseline. Mockito and build_runner are now used to generate test mocks; regenerate them with `dart run build_runner build` after changing a repository signature. Packages will be added alongside their actual implementations and tests. Demo mode will continue to work without backend setup.

License selection is pending; no commercial-use license is currently declared.
