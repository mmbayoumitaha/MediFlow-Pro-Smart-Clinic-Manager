# Firebase backend: B6 in progress

The Flutter app still uses the in-memory demo. This first B6 slice adds the backend authorization and reservation boundary; it does **not** enable Firebase in the app or complete the Firebase CV claim. No live project has been configured or deployed.

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

Observed verification on 2026-10-09: Node 22.23.3, Java 27, CLI 15.25.1, Firestore emulator 1.22.0. Nine policy tests, 17 rule tests and nine service/emulator tests passed. The service suite sends real Firebase SDK callable requests authenticated through the Auth emulator, including simultaneous competing bookings. One additional scenario invokes the same service through the Admin SDK with an injected clock to exercise check-in/completion/no-show boundaries deterministically. No Flutter-to-emulator or live Firebase runtime check is claimed yet.

The lockfile is committed. Overrides keep Firebase App/Compat on the Firebase 12 SDK versions (`0.16.2` / `0.5.18`) so Node 22 has one compatible component registry; unconstrained peers otherwise pull Node 24 packages alongside a second App instance. gRPC is constrained to a patched `1.14.6` or newer compatible release. Dependency installation reported zero known vulnerabilities after these changes; this is a point-in-time check.

## Authorization and schema

`users/{authUid}` is the trusted clinic identity. Its role and `isActive` flag determine authorization, independently of role selectors, command fields or custom role claims. Patient registration derives UID/email from Firebase Auth and creates only a patient. There is no client-accessible doctor/admin enrollment endpoint in this slice; tests seed trusted staff profiles through the Admin SDK.

All client writes are denied, including administrator writes. Clients must call authenticated server commands. Existing commands are `completePatientRegistration`, `availableSlots`, `bookAppointment` and `changeAppointmentStatus`, in `us-central1`. Inputs reject unknown fields, unsafe document IDs and invalid values. The callable boundary maps expected errors to public codes and hides database errors and clinical payloads.

| Collection | Patient reads | Doctor reads | Admin reads |
| --- | --- | --- | --- |
| `users` | Own document via get | Own document via get | All |
| `doctors` | Professional directory | Own linked profile | All |
| `appointments`, `prescriptions` | Filter by own `patientId` | Filter by own `doctorUserId` | All |
| `invoices` | Filter by own `patientId` | Denied | All |
| `doctorPatients/{doctorUid}/patients` | Denied | Own doctor hierarchy | All |
| `clinicLocks`, unknown paths | Denied | Denied | Denied |

An inactive or unprovisioned authenticated identity may get its own user document so the app can observe missing/deactivated profiles. It cannot read clinic records. Queries must match these ownership constraints; broad collection queries are rejected. The empty indexes file is intentional: these initial scopes require only single-field equality queries, with ordinary automatic indexes.

Records use the domain mapper's snake-case enum values, document IDs as entity IDs, and Firestore `Timestamp` values for instants. Appointments/prescriptions additionally store trusted `doctorUserId`, distinct from the doctor's profile ID. Booking creates the associated doctor's private patient projection without exposing users through broad queries. Future contact updates must update projections in the same transaction.

Firestore server libraries bypass client security rules, so commands perform their own trusted-identity and business validation. See the official [security rules guidance](https://firebase.google.com/docs/firestore/security/rules-fields) and [query constraints](https://firebase.google.com/docs/firestore/security/rules-query).

## Reservation and time contract

Backend clinic time uses **Africa/Cairo**. Commands accept Unix milliseconds; records store UTC instants. Availability returns only `{zone, startMillis}` and never another patient's appointment or contact data. Dates follow Cairo's next 14 calendar dates, excluding today. Active same-day periods produce 30-minute slots aligned to each period's start and permit visits ending at closing.

Nonexistent or ambiguous DST start times are excluded. A slot must also end at the expected wall time after 30 elapsed minutes. Tests cover both Cairo DST boundaries, malformed periods, adjacent/partially overlapping visits, cross-doctor patient conflicts and year rollover. The existing demo continues to use local device wall times until the Flutter backend adapter supplies explicit clinic-time conversion.

Every mutation reads and increments `clinicLocks/current` in the same Firestore transaction. Booking rechecks the current patient, linked active doctor, fee/specialty, working hours and all reserved doctor/patient intervals. It derives names, owner IDs, duration, lifecycle and payment fields from trusted records. Identical request IDs/payloads return the existing reservation, even after doctor details change; changed or foreign reuse fails. Status transitions enforce ownership, expected status and server time, without changing payments.

This implementation scans the clinic appointment collection and serializes mutations on one revision document. It is a small-clinic reference, with increasing read cost and limited concurrent throughput. Scaling needs indexed reservation locks/time partitions and equivalent conflict tests. Future billing/profile mutations must participate in the same revision; direct Admin SDK edits bypass that coordination. Offline backend writes, overnight periods, multiple clinic timezones and payment gateway charges are not implemented.

## Files to commit

Commit rules, indexes, public emulator configuration, source, tests and lockfiles. `.gitignore` excludes generated caches, `node_modules`, debug logs, local environment/configuration, and recognizable service-account key files. Keep private credentials outside the repository; ignore patterns are not a substitute for reviewing staged files. No credentials are included in the committed emulator fixtures.

Remaining B6 work: trusted staff provisioning, billing and profile commands, optional Flutter Firebase configuration/adapters, Auth session/profile events, role-scoped streams, Timestamp/clinic-time mapping, asynchronous free-slot UI, platform networking and an actual Flutter-to-emulator workflow. B6 remains open until those behaviors and the no-configuration demo are verified.
