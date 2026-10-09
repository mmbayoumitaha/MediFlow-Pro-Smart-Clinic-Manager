# MediFlow Pro — Smart Clinic Manager

A personal Flutter project for patient, doctor and administrator clinic workflows. The default offline demo uses fictional, in-memory data and requires no Firebase account or backend configuration. An explicit Firebase mode connects Auth, Firestore and callable clinic commands.

The project is being repaired in tested batches. [The repair plan](docs/REPAIR_PLAN.md) tracks completed changes; [the baseline audit](docs/PROJECT_AUDIT.md) records the original findings.

The Firebase backend includes maintained Firestore rules, trusted roles, patient registration, reservations, lifecycle, billing and profile management. The Flutter adapters restore trusted sessions, download records according to role, and display backend instants in Africa/Cairo. [Backend setup and verification](docs/FIREBASE.md) records the measured checks and setup steps. No live Firebase project has been created or deployed by this repair.

## Current functionality

- Patient, doctor and administrator portals with role-checked GoRouter routes and persistent tab navigation.
- Doctor directory with search/specialty filters and doctor links into booking. Future 30-minute slots follow active working periods and exclude doctor/patient conflicts; repeated booking requests are idempotent within the demo session.
- Patient-owned appointment/prescription/invoice reads; doctors see their own schedule and associated patients. New demo registrations add linked patient/doctor profiles.
- Appointment cancellation, confirmation, check-in, completion and no-show actions with role/time validation; administrator appointment management, overview, billing lists and fl_chart visualizations.
- Working admin doctor/patient management, self-service profile editing and doctor availability validation.
- Material 3 light/dark themes using Flutter's default fonts; the app no longer downloads Inter through Google Fonts.

All demo amounts use **USD**, displayed consistently without currency conversion. Paid-invoice totals count only fully paid, non-refunded invoices with valid dates and amounts. The six-month chart groups by payment date; the dashboard card covers all time. These snapshot totals are not a cash-flow ledger. Doctor completed-visit fees are explicitly separate from collected payments. Specialty distribution includes every recorded appointment status.

Administrators can issue one consultation-only invoice for an unpaid completed visit, record a full demo settlement, and record a full refund. Invoice and appointment payment status update together. These actions never charge or refund real money; partial balances and a transaction ledger are outside the current demo scope.

Administrators can add/edit doctors, edit/deactivate patients and delete unused profiles. Linked profiles cannot be deleted. Patients edit their own contact/address details; doctors edit their own profile and active working periods. Changes retain historical names/fees and must preserve future reservations. Current sessions and subsequent sign-ins follow the updated clinic profile.

The interface is **English only**. Unsupported notification, password-change and upload controls have been removed; About, theme and Settings links work. Firebase sign-in offers password recovery; staff accounts cannot self-register. Charts derive from source records. Route guards and scoped reads enforce demo visibility; Firebase rules and trusted callable commands enforce backend authorization. The demo contains fictional records; use fictional details in it.

## Run the demo

Verified toolchain: **Flutter 3.47.4 stable / Dart 3.13.3**. Use this version to reproduce the development checks. The SDK minimums are declared in `pubspec.yaml`; dependency versions are recorded in `pubspec.lock`.

```bash
git clone https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager.git
cd MediFlow-Pro-Smart-Clinic-Manager
flutter pub get
flutter run -d chrome
```

On the login screen, select Patient, Doctor or Admin. The prefilled `demo@mediflow.com` / `password123` values open the selected demo role. Authentication is simulated: any dummy password of at least six characters is accepted. Never enter a real password. The role selector applies only to this shared demo email; seeded and newly registered accounts retain their record’s role.

Demo registrations and bookings stay in memory across logout/account switches, so you can explore the same clinic from several roles. Logout clears account reads, search and specialty filters. **Reset demo**, available in each portal and on login, restores fixtures and signs out after confirmation; app restart also resets everything. Theme preferences last for the running app and are not changed by clinic reset. Initial dependency installation requires an Internet connection. The running demo uses local fixtures; a cold offline browser launch and browser caching have not been verified.

## Development checks

```bash
dart run tool/check_architecture.dart
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

The Flutter suite covers startup, trusted Firebase sessions/auth races, configuration, Timestamp/clinic-time mapping, scoped reads and revoked-access clearing, immutable storage models, demo repositories and Mockito use-case/view-model interactions. Widget tests exercise demo and Firebase-mode presentation, registration/sign-in/logout, role guards, reset/recovery, profile and management edits, availability/retry, booking and appointment actions. Analytics tests cover payment-month boundaries, immediate settlement updates, invalid/empty data, specialties and reactive charts. Backend policy/rule/service checks and the separate browser integration command are documented in [Firebase notes](docs/FIREBASE.md); the ordinary `flutter test` command does not run that browser journey.

Web is the current build-verification target. Platform folders exist for Android, iOS and desktop; their build/runtime support is not yet verified.

## Architecture and roadmap

The current code uses Flutter, Riverpod, GoRouter, fl_chart, intl, characters and uuid, plus the bundled Cupertino icon font for adaptive Flutter widgets. Auth and clinic features now separate framework-independent domain entities/use cases/repository contracts, demo data adapters and Riverpod presentation view models. Core providers inject repositories, clocks and ID generators; screens render immutable state and invoke view-model actions. Mockito unit tests verify repository interactions. See [the architecture guide](docs/ARCHITECTURE.md) for responsibilities and dependency boundaries.

The demo uses local device wall-clock times. Firebase mode uses Africa/Cairo and server validation of real instants. Time-dependent presentation updates every 30 seconds; analytics use the current clock again when new records arrive. New slots are revalidated at write time. The horizon is the next 14 dates; overnight working periods are unavailable. Remaining verification is tracked in [repair batches](docs/REPAIR_PLAN.md).

Firebase packages are used by the optional backend adapters; timezone handles clinic dates. Mockito and build_runner generate repository mocks; regenerate them with `dart run build_runner build` after changing a repository signature. The official `integration_test` package runs the separate browser journey. Demo mode continues to work without backend setup.

License selection is pending; no commercial-use license is currently declared.
