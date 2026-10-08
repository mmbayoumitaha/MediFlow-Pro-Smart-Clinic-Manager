# Firebase backend: B6 in progress

The Flutter app still uses the in-memory demo. Backend authorization, reservations, billing and profile management are now implemented; Flutter integration is the next B6 slice. Firebase is **not** enabled in the app yet, and the Firebase CV claim remains incomplete. No live project has been configured or deployed.

## Reproduce the backend checks

Use Node **22**, Java **21 or newer** on `PATH`, and Firebase CLI **15.25.1**. From the repository root:

```bash
npm ci --prefix functions
npm test --prefix functions
npm run check --prefix functions
npm run format:check --prefix functions
firebase emulators:exec --only auth,firestore,functions --project demo-mediflow \
  'npm run test:emulator --prefix functions'
```

The emulator configuration binds to localhost: Auth `19099`, Firestore `18080`, Functions `15001`. The first run downloads emulator binaries. The tests require emulator environment variables and use only the fictitious `demo-mediflow` project; the callable suite also verifies its project environment. They erase **this project's emulator documents** and create synthetic accounts, never a live database. Do not reuse an emulator session whose data you need to keep.

Observed verification on 2026-10-09: Node 22.23.3, Java 27, CLI 15.25.1, Firestore emulator 1.22.0. Twelve policy tests, 17 rule tests and 19 service/emulator tests passed. The service suite sends real Firebase SDK callable requests authenticated through the Auth emulator, including simultaneous competing bookings, profile changes and invoice/payment mutations. Additional scenarios invoke the same service with an injected clock or Auth failure to exercise lifecycle boundaries and interrupted provisioning deterministically. No Flutter-to-emulator or live Firebase runtime check is claimed yet.

The lockfile is committed. Overrides keep Firebase App/Compat on the Firebase 12 SDK versions (`0.16.2` / `0.5.18`) so Node 22 has one compatible component registry; unconstrained peers otherwise pull Node 24 packages alongside a second App instance. gRPC is constrained to a patched `1.14.6` or newer compatible release. Dependency installation reported zero known vulnerabilities after these changes; this is a point-in-time check.

## Authorization and schema

`users/{authUid}` is the trusted clinic identity. Its role and `isActive` flag determine authorization, independently of role selectors, command fields or custom role claims. Patient registration derives UID/email from Firebase Auth and creates only a patient. Only an active clinic admin can provision doctors. Administrator enrollment is absent from callable exports: the initial administrator requires a trusted operator and Admin SDK credentials.

All client writes are denied, including administrator writes. Clients must call authenticated server commands. Existing commands are `completePatientRegistration`, `availableSlots`, `bookAppointment`, `changeAppointmentStatus`, `issueAppointmentInvoice`, `recordInvoicePayment`, `savePatient`, `saveDoctor`, `removePatient` and `removeDoctor`, in `us-central1`. Inputs reject unknown fields, unsafe document IDs and invalid values. The callable boundary maps expected errors to public codes and hides database errors and clinical payloads.

| Collection | Patient reads | Doctor reads | Admin reads |
| --- | --- | --- | --- |
| `users` | Own document via get | Own document via get | All |
| `doctors` | Professional directory | Own linked profile | All |
| `appointments`, `prescriptions` | Filter by own `patientId` | Filter by own `doctorUserId` | All |
| `invoices` | Filter by own `patientId` | Denied | All |
| `doctorPatients/{doctorUid}/patients` | Denied | Own doctor hierarchy | All |
| `clinicLocks`, unknown paths | Denied | Denied | Denied |

An inactive or unprovisioned authenticated identity may get its own user document so the app can observe missing/deactivated profiles. It cannot read clinic records. Queries must match these ownership constraints; broad collection queries are rejected. The empty indexes file is intentional: these initial scopes require only single-field equality queries, with ordinary automatic indexes.

Records use the domain mapper's snake-case enum values, document IDs as entity IDs, and Firestore `Timestamp` values for instants. Appointments/prescriptions additionally store trusted `doctorUserId`, distinct from the doctor's profile ID. Booking creates the associated doctor's private patient projection without exposing users through broad queries. Contact updates update all associated doctor projections in the same transaction.

Firestore server libraries bypass client security rules, so commands perform their own trusted-identity and business validation. See the official [security rules guidance](https://firebase.google.com/docs/firestore/security/rules-fields) and [query constraints](https://firebase.google.com/docs/firestore/security/rules-query).

## Reservation and time contract

Backend clinic time uses **Africa/Cairo**. Commands accept Unix milliseconds; records store UTC instants. Availability returns only `{zone, startMillis}` and never another patient's appointment or contact data. Dates follow Cairo's next 14 calendar dates, excluding today. Active same-day periods produce 30-minute slots aligned to each period's start and permit visits ending at closing.

Nonexistent or ambiguous DST start times are excluded. A slot must also end at the expected wall time after 30 elapsed minutes. Tests cover both Cairo DST boundaries, malformed periods, adjacent/partially overlapping visits, cross-doctor patient conflicts and year rollover. The existing demo continues to use local device wall times until the Flutter backend adapter supplies explicit clinic-time conversion.

Every mutation reads and increments `clinicLocks/current` in the same Firestore transaction. Booking rechecks the current patient, linked active doctor, fee/specialty, working hours and all reserved doctor/patient intervals. It derives names, owner IDs, duration, lifecycle and payment fields from trusted records. Identical request IDs/payloads return the existing reservation, even after doctor details change; changed or foreign reuse fails. Status transitions enforce ownership, expected status and server time, without changing payments.

This implementation scans the clinic appointment collection and serializes mutations on one revision document. It is a small-clinic reference, with increasing read cost and limited concurrent throughput. Scaling needs indexed reservation locks/time partitions and equivalent conflict tests. Future billing/profile mutations must participate in the same revision; direct Admin SDK edits bypass that coordination. Offline backend writes, overnight periods, multiple clinic timezones and payment gateway charges are not implemented.

## Files to commit

Commit rules, indexes, public emulator configuration, source, tests and lockfiles. `.gitignore` excludes generated caches, `node_modules`, debug logs, local environment/configuration, and recognizable service-account key files. Keep private credentials outside the repository; ignore patterns are not a substitute for reviewing staged files. No credentials are included in the committed emulator fixtures.

## Billing, management and staff provisioning

Billing is administrative recordkeeping, not a payment gateway. Only active admins can issue one consultation invoice for a completed unpaid positive-fee visit, record full settlement (`cash`, `card`, `bankTransfer`) or a full refund. Invoice arithmetic/dates/items, expected status and appointment linkage are validated. Concurrent issuance returns the same invoice; concurrent settlement accepts only one expected-status command. Invoice/appointment payment states update together without altering lifecycle or historical fees.

Patients can edit their own contact/address details; admins can also deactivate/reactivate them. Doctors can edit their own linked profile and availability; admins can edit any doctor. Commands compare original editable values, including working periods, to reject stale forms independently of timestamp precision. Identity/email/role cannot change through these forms. Working-period changes must retain existing future reservations; disabling new bookings retains visits.

Admin doctor creation uses private `staffProvisioning/{authUid}` requests with stable identities, owner and normalized details. Auth and Firestore cannot share a transaction: a random inaccessible password and unpredictable Auth display-name marker allow safe recovery after Auth creation, before a trusted doctor profile exists. The server never promotes preexisting Auth accounts. Concurrent/identical retries, including a reopened form generating new suggested IDs, resume the same request. Changing an incomplete request's details is rejected. The marker stays in Auth metadata; the app uses the canonical Firestore name. First sign-in requires an explicit password reset by the account owner; no emails are sent by provisioning.

Deleting an unused profile removes its clinic records and creates an internal `revokedUsers/{authUid}` tombstone. Every historical appointment/prescription/invoice blocks patient deletion; doctor appointments/prescriptions block doctor deletion. Auth identities are retained without clinic access. Tombstones prevent public re-enrollment or reprovisioning under the same UID. Auth account cleanup and resolving abandoned/conflicting provisioning requests require the trusted owner; these operations are not automatic or claimed as physical Auth deletion.

To provision the initial administrator, first create an email/password identity in the intended Firebase Auth project and obtain its UID. A trusted operator with Application Default Credentials can run:

```bash
node functions/tool/provision_admin.js --project YOUR_PROJECT_ID --uid AUTH_UID \
  --name 'Clinic Owner' --phone '+201000000000'
```

This command has not been run against a live project. It participates in the same revision transaction and refuses patient/doctor/removed identity promotion. Emulator usage requires both Auth and Firestore emulator environment variables and a `demo-` project. Never commit Admin SDK credentials. See [Firebase Admin setup](https://firebase.google.com/docs/admin/setup) for operator authentication.

Remaining B6 work: optional Flutter Firebase configuration/adapters, Auth session/profile events, role-scoped streams, Timestamp/clinic-time mapping, asynchronous free-slot/reset-password UI, platform networking and an actual Flutter-to-emulator workflow. B6 remains open until those behaviors and the no-configuration demo are verified.

## Flutter configuration and mapping foundation

The Flutter SDK packages and typed initialization/configuration helpers are now present, with a separate Firestore/callable mapper. They are not wired into `main` or the app's repositories yet: running the app still opens the demo, regardless of these proposed backend flags. App-mode activation is the next slice.

`BACKEND_MODE` defaults to `demo`; Firebase options alone cannot enable a backend. Explicit Firebase configuration requires complete client options. `FIREBASE_EMULATORS=true` requires a `demo-` project; live mode rejects demo project IDs. `config/firebase.emulator.json` contains synthetic localhost options; `config/firebase.example.json` contains placeholders that validation rejects. Real platform-specific options belong in ignored `config/firebase.local.json`. Initialization never silently selects the demo on an invalid Firebase configuration. It disables Firestore disk persistence and uses session-only Auth persistence on web.

The backend mapper handles actual Firestore `Timestamp` values and callable UTC strings, uses trusted document IDs and rejects unknown roles/statuses/specialties and ambiguous naive timestamp strings. Domain instants become `TZDateTime` values in Africa/Cairo, retaining their epoch, offset and comparisons. Calendar-date selections remain separate from instants. Tests cover both Cairo DST changes, midnight/year boundaries, all five clinic storage entity types and malformed values.

Verification: seven new Flutter tests passed; the full suite passed **135** tests. Analysis and the 18-file domain architecture check passed; formatting passed. The demo web release build passed after adding the SDK dependencies. Native registrants were updated by dependency resolution; native builds/runtime, actual SDK initialization and Flutter-to-emulator operation remain unverified in this slice.

## Flutter authentication adapter

The authentication adapter now separates Firebase identity credentials from trusted server profiles. Startup restoration reads the own profile from the server; the profile watcher ignores cached role data. Login ignores the demo role argument. Registration allows patients only and recovers interrupted enrollment after proving the same email/password. The optional domain session source updates the Riverpod auth view model on profile/role changes and clears access for missing/inactive records or stream failures.

Credential operations are serialized, with generation checks around awaits. Logout clears the session immediately, then signs out after any pending SDK credential operation; a late old sign-in or restoration cannot replace a newer account. Listeners/controllers are disposed, and trusted same-UID role updates supersede pending command results. Password recovery validates/normalizes email and avoids distinguishing unknown addresses in the UI.

Callable requests may include `expectedActorUid`. The server checks it against the actual authenticated UID before executing the command. The Flutter command adapter always includes it, so a request prepared under a previous account cannot accidentally execute under the next account. This is a session binding, not a source of permissions.

Eight adapter/view-model tests passed with controlled identity/profile gateways, including logout/sign-in races, deactivation, errors/disposal, interrupted registration and same-UID role updates. The full Flutter suite passed **143** tests; analysis, the 19-file domain architecture check and formatting passed. All 17 rule and 19 service/emulator tests passed with the callable binding. The app still uses demo composition: backend repository/UI wiring and actual Flutter SDK-to-emulator integration remain open.

## Scoped Flutter clinic adapter

The Firestore adapter selects queries before downloading data. Patients read their own user document, the professional doctor directory and their appointments/prescriptions/invoices. Doctors read their own profile, private patient projections and their assigned appointments/prescriptions, without invoices. Admins read the clinic collections. Cached snapshots are ignored; explicit reads require the server. Writes use the callable service with expected-actor bindings and canonical returned records. Availability sends calendar dates and receives actual instants in Africa/Cairo; booking leaves private conflict validation to the server.

Account/role changes clear the old scope and invalidate pending reads and command acknowledgements. Query/read errors clear previous data before reporting safe feedback. Refresh restarts failed query subscriptions. Seven new tests cover these behaviors, canonical booking/retries, availability validation and disposal. All **150** Flutter tests, analysis and the 20-file domain boundary check pass. These tests use controlled record/command gateways; actual SDK queries, app composition and browser-to-emulator verification remain open.
