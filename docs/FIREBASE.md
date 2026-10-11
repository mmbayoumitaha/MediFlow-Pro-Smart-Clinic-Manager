# Firebase setup — Auth + Firestore on Spark

The default app is an offline demo. Explicit Firebase mode uses email/password Auth and Standard Firestore client transactions enforced by maintained Security Rules. No Functions, Storage or billing account is required. Read the [migration contract](SPARK_MIGRATION.md) for reservations, scheduling, billing and management invariants.

## Live project

[Console: MediFlow Pro](https://console.firebase.google.com/project/mediflow-pro-mmbayoumi/overview), project ID `mediflow-pro-mmbayoumi`. A web app is registered. On 2026-10-11 email/password Auth was enabled and the `(default)` Standard Firestore database was created in Frankfurt (`europe-west3`), with deletion protection enabled and PITR disabled. Billing inspection confirmed no billing account linked. Rules/indexes were deployed successfully and the owner-supplied Auth identity was bound as the initial administrator in an atomic operator transaction. Read-back confirmed its canonical email/active role/server timestamps; no password was shared or stored in this repository. The temporary display label is Clinic Administrator with no contact number.

The database location cannot be changed in place. No synthetic emulator accounts or fixtures are uploaded to this project. The registered release opened its connected-clinic login screen in Chromium without severe startup errors, and deployed rules rejected an anonymous owner-profile read (403). Authenticated live clinic journeys still require the owner to sign in; emulator journeys are reported separately. [Spark plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans) and [Firestore quotas](https://firebase.google.com/docs/firestore/quotas) apply; no unlimited/free production-capacity claim is made.

## Reproduce local checks

Use Node 22 or newer, Firebase CLI 15.25.1, Java 21 or newer, Flutter 3.47.4 and matching Chromium/ChromeDriver. Install the Java and Node dependencies before starting emulators.

```bash
npm ci --prefix firebase
firebase emulators:exec --only auth,firestore --project demo-mediflow \
  'npm run test:spark --prefix firebase'
firebase emulators:exec --only auth,firestore --project demo-mediflow \
  'MEDIFLOW_SPARK_TARGET=workflows bash tool/test_spark_web.sh'
```

The first command exercises adversarial security-rule cases, including atomic booking/billing, concurrent reservations, role isolation and safe deletion. The second runs actual Chromium Flutter UI/SDK integration. `MEDIFLOW_SPARK_TARGET=registration` runs the standalone enrollment journey; `booking` runs reservation/lifecycle/retry behavior. `MEDIFLOW_SPARK_TARGET=staff` additionally verifies first-admin calendar creation, real Auth UID binding, staff login/editing, safe deletion and revoked login. Ordinary `flutter test` does not run these browser integrations.

Emulators bind to localhost: Auth `19099`, Firestore `18080`. Fixture tools require the exact fictitious `demo-mediflow` project and both emulator hosts. They replace emulator documents and create synthetic Auth identities; closing emulators without export discards their state. Never use the fixture tools for a real project or an emulator session whose data you need to retain.

To explore a populated local clinic:

```bash
firebase emulators:exec --only auth,firestore --project demo-mediflow \
  'node firebase/tool/seed_web_emulator.js && node firebase/tool/seed_spark_emulator.js && flutter run -d chrome --dart-define-from-file=config/firebase.emulator.json'
```

Fixture accounts: `browser-patient@example.test`, `browser-doctor@example.test`, `browser-admin@example.test`, password `Emulator-only-password1!`. These credentials are fictional and local only. Registration creates patients only; password recovery emits a local emulator link. The retired Functions implementation and its historical checks remain available in Git history; the current Node package contains only tests, emulator fixtures and operator tools.

## Configure and deploy the live backend

`.firebaserc` names `live` and `emulator` explicitly, with no default alias. Select the project on every CLI mutation. Public client options belong in ignored `config/firebase.local.json`; copy `config/firebase.example.json` when using another project and replace all placeholders. API client configuration identifies a project and does not grant privileged access. Keep operator/service-account credentials outside the repository.

```bash
firebase deploy --only auth,firestore --project live --non-interactive
flutter run -d chrome --dart-define-from-file=config/firebase.local.json
```

The deploy config enables email/password Auth and deploys Firestore rules/indexes only. The initial scopes and occupancy queries use automatic single-field indexes; the empty composite-index file is intentional. Review changes before deployment and monitor quota usage in Console. No billing upgrade is included in these commands.

Explicit invalid Firebase configuration displays a setup error and never silently falls back to fictional data. Emulator configuration requires a `demo-` project; live mode rejects demo project IDs. Firebase is never initialized for the default demo. Web Auth uses session persistence; Firestore disk persistence is disabled. Backend transactions require a server connection. Offline demo mode is a separate in-memory clinic.

## Initial administrator and doctors

Create the owner's chosen email/password account in [Authentication → Users](https://console.firebase.google.com/project/mediflow-pro-mmbayoumi/authentication/users), then obtain its UID. Keep the password private. A trusted operator with Application Default Credentials can bind the initial administrator:

```bash
node firebase/tool/provision_admin.js --project mediflow-pro-mmbayoumi --uid AUTH_UID \
  --name 'Clinic Owner' --phone '+201000000000'
```

The owner chooses the display name and can omit the contact number until a real one is available. The operator must verify the actual Auth identity and refuse promotion of patient/doctor/revoked identities. This operation bypasses client rules, so it is never an application signup feature. See [Admin SDK authentication](https://firebase.google.com/docs/admin/setup). Admin login prepares trusted Cairo calendar documents for this year and the next.

For each doctor, create the email/password account in Auth Console and enter its UID and matching email in the clinic administrator's Add Doctor form. Password setup/transfer stays between the owner and doctor. The form atomically binds the trusted user, professional profile and immutable email reservation. Public self-registration cannot assign staff roles. Deletion removes only unused clinic profiles; Auth identity removal is a separate owner operation.

## Authorization and schema

| Record | Patient | Doctor | Administrator |
| --- | --- | --- | --- |
| Trusted `users` | Own document/contact edit | Own document; get associated patients | Read all; permitted patient/staff management |
| `doctors` | Directory | Own linked profile/edit | Directory and staff management |
| `appointments`, `prescriptions` | Query own patient ID | Query own doctor UID | All |
| `invoices` | Query own patient ID | Denied | All; atomic issue/settle/refund |
| Doctor reservation slots | Occupancy without patient data | Occupancy without patient data | Occupancy without patient data |
| Patient reservation slots | Own occupancy | Denied | All |
| Private care index | Own link get | Own doctor hierarchy | All |

Missing/inactive identities can get their own trusted user document to observe revocation. They cannot access clinic records. Broad cross-role queries are denied, and all unknown paths/writes fail closed. Roles are bound to the authenticated UID and matching token email; UI selectors, custom caller fields or a form email cannot confer privileges.

Records use snake-case enums, Firestore Timestamps and immutable document identities. Backend instants display in Africa/Cairo. Public booking data exposes only occupied slot time and random appointment ID. New weekly schedules use seven 48-bit grids, decoded into bookable HH:mm periods by the data adapter. Changing working hours requires no reserved visits; disabling new bookings preserves existing visits. Contact changes preserve historical visit and invoice names/fees.

The schema uses `accountEmails`, `revokedUsers`, `clinicTimezones`, `patientHistory`, `bookingGuards`, `doctorReservations`, `patientReservations`, `doctorPatients` and `billingLinks` to enforce cross-document invariants. Client writes must pair all required records in transactions. Direct Console/Admin SDK clinical imports bypass these protections and must maintain every invariant; arbitrary clinical imports are not supported by the fixture tooling.

Prescriptions are read-only in the current product. Payments are administrative records; no payment gateway or file upload is implemented. Native build/runtime, quota-capacity measurement, cold offline browser startup and live clinic journeys remain separate verification targets.

## Observed final migration checks (2026-10-11–12)

- **79** Node/emulator cases passed: seven operator-bootstrap protections, 15 patient-enrollment rules, 40 booking/billing/profile rules and 17 read/access cases. Current tooling passed syntax/Prettier checks; dependency audit reported zero vulnerabilities.
- **238** Flutter tests passed, including 72 width/text-scale cases and a snackbar-account regression that failed before the scope fix. Analysis, formatting and the 21-file domain boundary check passed. An observed hot reload succeeded.
- The complete multi-role Chromium/ChromeDriver 153 journey passed with only Auth/Firestore emulators: private booking/retry, contacts, restored SDK sessions, doctor lifecycle, admin issue/settle/refund/analytics, UID-bound doctor creation/login/edit/schedule normalization/deletion, patient registration and local password recovery.
- The separate staff journey passed with missing calendar fixtures, proving administrator initialization through the actual client SDK/rules, plus refused sign-in after deletion. No synthetic identity or clinic fixture was created in the live project.

Native runtime, authenticated live journeys, production load/capacity and cold offline browser launch remain unverified. Historical B6 Functions results remain in the repair plan/Git history and are not counted as current backend checks.
