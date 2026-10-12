# Auth + Firestore migration

Since **2026-10-11**, the connected backend uses Firebase Auth and Standard Firestore within Spark allowances, without Cloud Functions, Storage or a billing account. Default offline demo behavior and the domain/presentation boundaries are preserved.

## Protected SDK transactions

All reachable clinic commands now use the Firebase client SDK. Firestore Security Rules authorize the actual Auth UID and email against an active trusted `users/{uid}` record. Patient enrollment has a strict field allowlist, canonical token email, server timestamps, immutable email reservation and removed-identity protection. Staff cannot self-register or change roles/emails. Session guards reject delayed writes after an account switch.

Booking uses a fixed 30-minute Cairo grid over the next 14 dates, excluding today. A transaction writes the canonical appointment, doctor and patient reservation locks, a doctor reservation counter, immutable patient history and the associated doctor's minimal care link. Rules check all required documents through `getAfter`; competing patients cannot reserve the same doctor, or book the same patient with different doctors at the same instant. Public occupancy contains only an instant and random appointment ID. Identical request retries acknowledge the original appointment. Terminal lifecycle transitions release both locks and decrement the counter atomically.

Weekly availability stores seven 48-bit strings, one per weekday, rather than repeatedly validating nested periods against Firestore's expression budget. The data adapter exposes actual bookable HH:mm periods to domain and presentation; saving 09:15–17:45 normalizes to 09:30–17:30. Overnight slots are excluded. Trusted immutable yearly calendar documents specify Cairo DST transitions; an admin login prepares the UTC instant year, Cairo year and next year, including the January 1 overlap. Missing/mismatched calendar data fails closed. A timezone-law change requires an operator update and verification, not a patient-supplied offset.

Billing uses an immutable appointment-to-invoice link, exactly one canonical consultation line and strict arithmetic. Settlement/refund changes the invoice and appointment payment status in one transaction with server timestamps. These actions record clinic payment status; they do not charge/refund money.

Patient contact edits update their own authoritative profile. Associated doctors watch the minimal care index and fetch only linked patient documents, so contact updates require no fan-out. Doctor edits atomically update their professional and trusted user records. Availability changes require no reserved visits; contacts, fees and the new-booking switch remain editable. Historical appointment names/fees remain unchanged.

Unused-profile deletion requires an immutable tombstone. Booking history prevents patient and doctor deletion, even after every visit becomes terminal. Auth identities and email reservations remain, preventing re-enrollment under a removed UID. Trusted operators must maintain history/counter/link invariants when importing clinical records; no live clinical import is performed by this migration. Prescription reads remain role-scoped; prescription issuing and file uploads are not implemented.

## Staff and owner setup

Create a doctor's email/password identity in Firebase Console. The clinic admin enters its actual UID and matching email in the Add Doctor form. The identity gets clinic access only after that privileged binding and only when its Auth email matches. No generated inaccessible password, secondary sign-in or outgoing provisioning email is used. Correcting an erroneous binding is an owner operation.

The initial administrator requires a trusted operator binding an existing Auth identity, not public registration. See [Firebase setup](FIREBASE.md). Passwords must never be shared with the coding agent or committed.

## Verification and cloud state

The first enrollment slice (`5b38001`) passed 15 enrollment and 17 access-rule cases, 21 focused Flutter tests, analysis, and Chromium UI registration/login/retry with Auth/Firestore only.

The complete original browser journey also passed with Functions absent: scoped portals, booking, contact update, session restoration, lifecycle, invoice issuance, settlement/refund, analytics, registration and emulator password recovery. The expanded complete journey passed including admin UI binding of a new Auth UID, real staff login, profile/hours editing and unused deletion. A separate staff journey also passed first-admin calendar initialization and rejected removed-account login. Final checks passed 79 Node/emulator cases and 239 Flutter tests; details are in the development history and Firebase guide.

The live project is `mediflow-pro-mmbayoumi`; email/password Auth is enabled and the `(default)` Standard Firestore database exists in `europe-west3`. Billing inspection reported `billingEnabled: false` with no billing account linked. Rules/indexes were deployed, the owner-supplied Auth identity was atomically bound as the initial administrator, and read-back verified its active canonical profile. The registered release opened its connected-clinic login in Chromium without severe startup errors; a live anonymous profile read was denied (403). Authenticated live clinic journeys remain separate from emulator evidence.

Spark quotas apply to transactions, listeners and rule-dependent reads too. This is a small-clinic implementation, not an unlimited-capacity service. Monitor [Firestore usage and free quotas](https://firebase.google.com/docs/firestore/quotas). Historical Functions implementation/verification remains available in Git history; it is not the current deployment design.
