# MediFlow Pro — Smart Clinic Manager

A personal Flutter project for exploring patient, doctor and administrator clinic workflows. The current app runs with synthetic, in-memory demo data and requires no Firebase account or backend configuration.

The project is being repaired in tested batches. [The repair plan](docs/REPAIR_PLAN.md) tracks completed changes; [the baseline audit](docs/PROJECT_AUDIT.md) records the original findings.

The first Firebase backend slice now includes tested Firestore rules and server-side registration, availability, reservation and lifecycle commands. It is not yet connected to Flutter. [Backend setup and verification](docs/FIREBASE.md) describes the emulator checks and remaining B6 work.

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

The interface is **English only**. Unsupported notification, password-change and upload controls have been removed; About, theme and Settings links work. Charts derive from source records. Route guards and scoped reads enforce demo visibility; production backend authorization still requires the planned Firebase rules. The demo contains fictional records; do not enter real patient information.

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
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

The 128 tests cover startup, immutable entities/storage mapping, demo repositories, Mockito use-case/view-model interactions, auth/refresh/reset races, profile edits/deactivation/deletion and management conflicts, registration and role retention, all 15 portal role/path combinations, per-account visibility, working periods/conflicts/retries, lifecycle/time/category boundaries, live-clock rollover and loading/error/retry UI. Widget tests exercise registration, sign-in/logout, cross-role links, cancel/confirm reset, doctor-linked booking, slot contention and patient-to-doctor status workflows. Analytics tests cover payment-month boundaries, invalid/empty data, all specialties, recent-change ordering and reactive charts. Lifecycle changes keep invoice/payment values unchanged; manual billing actions have separate permission/concurrency/UI tests; Firebase authorization remains in a subsequent batch. See [development notes](docs/DEVELOPMENT.md) for toolchain details and the formatting check.

Web is the current build-verification target. Platform folders exist for Android, iOS and desktop; their build/runtime support is not yet verified.

## Architecture and roadmap

The current code uses Flutter, Riverpod, GoRouter, fl_chart, intl, characters and uuid, plus the bundled Cupertino icon font for adaptive Flutter widgets. Auth and clinic features now separate framework-independent domain entities/use cases/repository contracts, demo data adapters and Riverpod presentation view models. Core providers inject repositories, clocks and ID generators; screens render immutable state and invoke view-model actions. Mockito unit tests verify repository interactions. See [the architecture guide](docs/ARCHITECTURE.md) for responsibilities and dependency boundaries.

The demo uses local device wall-clock times and updates visible time-dependent state every 30 seconds. New slots are revalidated at write time. The horizon is the next 14 dates; overnight working periods are currently unavailable. Configurable Firebase Auth/Firestore adapters with authoritative timezone handling and reservation transactions remain planned in subsequent [repair batches](docs/REPAIR_PLAN.md).

Unused Firebase, storage, upload and PDF dependencies were removed from the startup baseline. Mockito and build_runner are now used to generate test mocks; regenerate them with `dart run build_runner build` after changing a repository signature. Packages will be added alongside their actual implementations and tests. Demo mode will continue to work without backend setup.

License selection is pending; no commercial-use license is currently declared.
