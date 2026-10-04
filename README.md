# MediFlow Pro — Smart Clinic Manager

A personal Flutter project for exploring patient, doctor and administrator clinic workflows. The current app runs with synthetic, in-memory demo data and requires no Firebase account or backend configuration.

The project is being repaired in tested batches. [The repair plan](docs/REPAIR_PLAN.md) tracks completed changes; [the baseline audit](docs/PROJECT_AUDIT.md) records the original findings.

## Current functionality

- Separate patient, doctor and administrator screens with persistent tab navigation using GoRouter.
- Doctor directory with specialty filters, appointment booking and appointment/prescription lists backed by demo fixtures.
- Doctor schedule and patient browser.
- Administrator overview, billing lists and fl_chart visualizations.
- Material 3 light/dark themes using Flutter's default fonts; the app no longer downloads Inter through Google Fonts.

Some visible actions are still placeholders. Role authorization, per-user data scoping, booking validation and chart calculations remain under repair. The demo contains fictional records; do not enter real patient information.

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
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

Startup tests cover splash timing, onboarding-to-login navigation in both themes, and disposal before delayed navigation. They do not yet verify the complete clinic workflows. See [development notes](docs/DEVELOPMENT.md) for toolchain details and the formatting check.

Web is the current build-verification target. Platform folders exist for Android, iOS and desktop; their build/runtime support is not yet verified.

## Architecture and roadmap

The current code uses Flutter, Riverpod, GoRouter, fl_chart, intl and uuid, plus the bundled Cupertino icon font for adaptive Flutter widgets. Screens live under `lib/features`, with shared models, providers and demo fixtures. Clean Architecture/MVVM separation, Mockito business-rule tests and configurable Firebase Auth/Firestore adapters are planned in subsequent [repair batches](docs/REPAIR_PLAN.md).

Unused Firebase, storage, upload, PDF and generator dependencies were removed from the startup baseline. Packages will be added alongside their actual implementations and tests. Demo mode will continue to work without backend setup.

License selection is pending; no commercial-use license is currently declared.
