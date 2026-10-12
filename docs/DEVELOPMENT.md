# Development

## Toolchain and dependencies

The verified Flutter toolchain is **3.47.4 stable / Dart 3.13.3**. Use the committed `pubspec.lock`; check `flutter --version` before reproducing results.

```bash
flutter pub get --enforce-lockfile
dart run tool/check_architecture.dart
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
```

Mockito-generated repository mocks are committed. After changing a contract, regenerate with `dart run build_runner build`. Do not regenerate mocks for ordinary test runs.

The backend tooling needs Node 22+, Java 21+, Firebase CLI **15.25.1**, and matching Chrome/ChromeDriver. `npm ci --prefix firebase` installs its locked packages. See [FIREBASE.md](FIREBASE.md) for commands that run genuine rule and browser integration tests. Normal `flutter test` covers unit/widget tests, not those integrations.

## Running and building

```bash
flutter run -d chrome                         # fictional clinic
flutter run -d linux                          # fictional desktop clinic
flutter build apk --debug --no-pub            # development APK
flutter build linux --release --no-pub
flutter build web --release --no-pub
```

Serve `build/web` over HTTP, for example `python3 -m http.server 5081 --directory build/web`. The custom bootstrap loads CanvasKit from `canvaskit/` on the same origin. Roboto and Noto Sans Arabic ship in assets; fonts do not require a CDN. A fresh browser can use the demo while internet endpoints are blocked if the asset server remains reachable. There is no offline reload service worker; no clinic data is cached by a worker.

Use `--dart-define-from-file=config/firebase.emulator.json` for the local connected clinic, or ignored `config/firebase.local.json` for a registered live app. The checked live configuration is for web. Native connected builds require separately registered matching platform apps/options; a successful demo native build does not verify a native Firebase deployment. Linux Firebase mode is not supported by the selected Auth/Firestore plugins.

## Android signing

The application ID is `io.github.mmbayoumitaha.mediflow`. Release builds never silently use the debug signing key. To sign for distribution, create your own keystore following [Flutter's Android deployment guide](https://docs.flutter.dev/deployment/android) and place its settings in ignored `android/key.properties`:

```properties
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/absolute/path/to/your-private-upload-keystore.jks
```

Keep and back up the keystore/passwords privately. Without this file, a release package is unsigned and must not be distributed as an installable release. The verified Android artifact is a debug APK. The current AGP/Kotlin toolchain builds successfully but Flutter reports upcoming minimum-version changes; upgrade them together with a fresh native build when updating the Flutter SDK.

iOS/macOS require Xcode and signing on macOS; Windows requires its native toolchain. Their source branding is maintained, but those builds are not covered by a Linux-host check.

## State ownership

Riverpod owns repositories, view models, clocks and the router. Splash cancels its timer; onboarding and forms dispose controllers. A shared presentation clock ticks every 30 seconds without reseeding data, and mutations validate current time again. Tests with externally owned containers dispose them before Flutter checks timer invariants.

The router remains stable through sign-in, loading and logout. Account changes clear scoped data and filters; reset invalidates pending demo view models and restores fixtures. Connected roles require an active server-confirmed profile matching Auth identity/email. Delayed reads and write acknowledgements are rejected after account changes.

Domain validation checks names, phone lengths/digits, email document compatibility, addresses, biographies, working periods and monetary precision before external side effects. Firestore rules independently protect the storage boundary; client validation alone grants no access.

## Repository hygiene

Keep `pubspec.lock`, `firebase/package-lock.json`, configuration examples, rules, source and generated test mocks under version control. Keep builds, caches, local Firebase options, keystores, operator credentials and emulator logs out. Client Firebase options are project identifiers, not administrator credentials; Security Rules remain the authorization boundary.

The root MIT license covers original code and artwork; bundled fonts have separate notices. Regenerate icons with `python3 tool/generate_icons.py` after editing the source SVG; install `rsvg-convert` and ImageMagick first.

GitHub Actions pins action revisions and the tested Flutter/Firebase CLI versions. It uses fictional emulator data and no live credentials. Checks run on push/PR; configuring required merge checks is a separate repository setting. See [release evidence](RELEASE_CHECKS.md) for observed outcomes and remaining platform limits.
