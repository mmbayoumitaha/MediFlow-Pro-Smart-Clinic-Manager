# Auth + Firestore migration

Owner decision, **2026-10-11**: run the live clinic within Firebase's Spark allowances, without Cloud Functions, Storage or a billing account. Keep the existing default demo, trusted roles, scoped reads and domain/presentation architecture. This migration is in progress; the application is not yet a complete Functions-free backend.

## Verified first slice: patient enrollment

The Flutter Auth adapter now enrolls patients using a Firestore transaction. Its email is obtained from the actual Firebase Auth identity, not form metadata. The transaction checks the current UID on every retry and after completion, preserves an existing patient profile on same-owner retries, rejects inactive/staff/revoked identities, and atomically reserves the email with the user record. Creation timestamps use server transforms.

Security rules permit only self-owned, active patient enrollment with a strict field allowlist, canonical token email, validated contacts, server timestamps and a matching `accountEmails/{email}` reservation. Email reservations are immutable; `revokedUsers/{uid}` is readable only by that identity for enrollment checks and never writable by it. All other record writes retain their previous denial until their replacement policy is implemented and tested. No live rules have been deployed by this slice.

Observed on 2026-10-11: 15 new enrollment rule tests plus the existing 17 access-rule tests passed against the Firestore emulator. Twenty-one focused Flutter auth/configuration/mode tests passed; analysis passed. A separate Chromium/ChromeDriver browser journey passed with **only Auth and Firestore emulators running**: UI registration, canonical patient role despite admin login input, server timestamps, denied role escalation, logout/login and same-owner re-enrollment without changing the saved profile. Functions were not running in that journey.

## Remaining implementation slices

1. Replace availability/booking/lifecycle calls with SDK transactions and rules-validated doctor/patient reservation documents. Availability must expose occupancy without another patient's details; booking must bind both reservations atomically. Validate Cairo calendar/working-hour boundaries using trusted timezone configuration and server request time. Use one fixed 30-minute grid in Firebase mode so cross-doctor conflicts have deterministic reservation keys; keep demo behavior explicit.
2. Replace billing calls with a unique appointment-to-invoice link, strict invoice arithmetic and atomic invoice/appointment payment transitions. Keep administrative recordkeeping; no payment gateway is involved.
3. Replace profile and management calls. Patients retain ownership of their contact data; staff cannot change their own role/email. Protect historical references and removed identities. Preserve doctor reservations during schedule changes.
4. Free staff setup: create the email/password identity in Firebase Console, then let the clinic admin bind the actual Auth UID when creating the doctor profile. Avoid a secondary SDK account, inaccessible generated passwords or self-assigned staff roles. Bootstrap the first admin with a trusted operator, never a public enrollment path.
5. Remove the Functions transport/package/runtime/deployment configuration after all reachable commands have replacements. Run the complete browser journey with Functions absent, plus adversarial rule tests, required Flutter checks and both web builds. Update current setup documentation while preserving historical verification records.
6. Configure live email/password Auth and Firestore, deploy the tested rules/indexes and verify the live project remains without billing. Complete initial admin setup with the owner's chosen account; never upload emulator fixtures to the live project.

The migration adapter deliberately delegates the remaining clinic commands to the previous transport until their coherent replacement slices pass. The existence of a live Console project and a working registration slice must not be presented as a fully working cloud clinic.
