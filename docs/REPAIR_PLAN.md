# MediFlow Pro: repair batches

Created: 2026-10-04 (Africa/Cairo). Baseline: `5a02453`.

The owner requested an audit first, collaborative scheduling, and small commits pushed after each completed batch, then delegated the scheduling choice. Completion-driven batches are selected: work follows the dependency order below, with no fixed daily deadlines. Implementation scopes are proposed until each batch is undertaken. Actual commits retain their real author/committer timestamps. Progress is recorded through completed changes, check results and GitHub commit links.

Findings and evidence: [PROJECT_AUDIT.md](PROJECT_AUDIT.md).

## Delivery order

| Batch | Scope / audit IDs | Depends on | Required evidence before completion | Status |
| --- | --- | --- | --- | --- |
| B0 | Document source audit, CV gaps, baseline failures and this repair plan | — | Evidence-backed issue inventory; documentation diff checked | Complete in the commit introducing this plan |
| B1 | Restore compilation; align toolchain/lockfile; repair smoke test, trim unused dependencies and analyzer diagnostics. MF-001, MF-031 baseline, MF-033 | B0 | `flutter analyze`, deterministic startup test, `flutter test`, `flutter build web` pass; record exact SDK | Complete; startup `a7ce807`, formatting in the commit closing B1 |
| B2 | Introduce actual domain/data/presentation boundaries, repository contracts, injected demo repository, use cases and Riverpod view models; immutable state and model mapping. MF-005, MF-016, MF-017, MF-029 | B1 | Domain imports no Flutter/Firebase; screens use view models; isolated repository/unit/Mockito tests for mapping and state interactions | Complete; domain/mapping `b35b841`, repository and presentation wiring in the commit closing B2 |
| B3 | Explicit demo mode, stable router, role guards, patient/doctor data scoping, safe auth state and session/reset behavior. MF-002, MF-003, MF-004, MF-006, MF-008, MF-020, MF-036 | B2 | All role/path combinations, auth failure/logout/reset races and cross-user reads tested; exercise actual login/logout/registration/reset UI in widget tests | Complete; route/scoping `4433555`, explicit demo UI/reset in the commit closing B3; Firebase authorization remains B6 |
| B4 | Correct booking time, availability/conflicts/retries, appointment lifecycle/categories, working search and deep-link return. MF-009–MF-015 | B3 | Booking and status business rules tested, including midnight/AM-PM/time boundaries and conflicts; patient-to-doctor workflow verified | Complete for demo; reservations `01ea66d`, lifecycle/categories `4242f3e`; Firebase transactions/timezone remain B6 |
| B5 | Working doctor/patient admin management, profiles/availability, billing, truthful analytics and correct activity/revenue semantics. MF-021–MF-025, MF-028 | B4 | Analytics unit tests with empty/multi-month data; management/payment/view-model tests; charts update after writes | Complete for demo; analytics `b0956a7`, billing `21f1a40`, management/profiles `ef526ce` |
| B6 | Implement optional configurable Firebase Auth/Firestore adapters, secure role provisioning, transactions, maintained rules/indexes and emulator tests. MF-007, MF-018, MF-029 Firebase mapping, MF-034 Android networking | B5 | Backend mode exercised against emulators; rules reject escalation/forgery/cross-user access; demo works with no configuration | In progress; access/reservations `2851208`, billing/profiles/staff provisioning in the next commit; Flutter integration open |
| B7 | Offline font handling, onboarding/localization decision, layout/branding, CI and truthful README/CV evidence. MF-019, MF-026, MF-027, MF-030, MF-031 full suite, MF-032, MF-034 branding, MF-035 | B6 | Full quality gates; offline demo and representative responsive checks; setup instructions reproduced; CI green; final evidence matrix | Proposed; Inter downloads removed, controller disposal fixed and README corrected in B1; remaining checks still open |

Tests accompany each change; B7 completes the overall verification and documentation. P0 authorization issues stay ahead of enabling Firebase. Individual batches may contain several small commits rather than one large commit. Keep the application runnable after B1, and include tests with the corresponding behavior change.

## Target structure

```text
lib/
  core/                       # composition, configuration, theme, shared UI
  features/
    auth/
      domain/                 # entities and authentication contracts
      data/                   # demo/Firebase authentication adapters
      presentation/           # Riverpod view model, state, screens
    clinic/
      domain/                 # clinic entities, policies, repository, use cases
      data/                   # demo/Firebase repositories, DTO mapping
      presentation/           # clinic view models and analytics state
    patient/                  # role-specific presentation
    doctor/                   # role-specific presentation
    admin/                    # role-specific presentation
  routes/                     # router and role access policy
```

The exact folder split can follow implementation needs. The requirement is dependency direction and actual separation: domain owns business policies and contracts; data implements them; views render state and invoke presentation actions. Moving files alone does not complete B2.

## Commit and push policy

1. Make a focused, reviewable change. Add useful regression tests for logic and permissions; do not create empty/activity-only commits.
2. Run the checks relevant to the change. App batches must pass analysis/tests, with builds when configuration or platform behavior changes. Documentation batches require review and `git diff --check`.
3. Stage only that change and inspect the staged diff. Commit with a descriptive message, for example `fix(appointments): preserve selected slot and reject conflicts`.
4. Push to the agreed current branch (`main` at baseline) after each verified unit of work. Do not force-push or rewrite existing history. If the remote moved, reconcile without discarding others' changes.
5. Update the progress table with the actual commit, checks and remaining findings. Report a failed push separately from a successful local commit.

B0 records baseline application failures and does not require a green app build. Subsequent completion claims must reference checks that actually ran.

## Scheduling choices

| Option | How progress is scheduled |
| --- | --- |
| Completion-driven batches (selected) | Work through the dependencies, with no invented daily dates. Each completed, verified change is committed and pushed. |
| One intensive week | Tentative sessions: baseline/build, architecture, access, bookings, management/analytics, Firebase, final verification. Split or extend sessions if a gate fails. |
| Two lighter weeks | Spread the same dependencies over smaller sessions; agree available days before assigning calendar dates. |

These are scheduling options, not time estimates or autonomous future jobs. Sessions require actual work to occur; commits reflect when it happened.

## Decisions to resolve during implementation

- Demo changes (decided B3): in-memory records survive logout for cross-role exploration, confirmed reset/restart restores fixtures; account filters clear on identity changes. Theme preferences last for the running app.
- Firebase: repository-owned configuration template and emulator setup can be completed locally. A deployed project needs the owner's project/configuration and administrator provisioning. Do not invent credentials or claim live verification without them.
- Currency (decided B5): USD for all synthetic amounts, with one explicit formatter and no currency conversion.
- Language (decided B5): intentionally English-only; removed the unused locale selector and unsupported Arabic locale declaration.
- Scope: CV-critical workflows come first. Optional notifications, uploads, PDF export and medical records must be implemented, disabled with an explanation, or removed from claims; they are not implied complete by declared packages.
- License: owner selects the license; remove unsupported commercial-use wording until resolved.
- Platform claims: web can be checked locally; only claim Android/iOS/desktop verification when the appropriate build/runtime checks actually run.

## Progress log

| Date (Cairo) | Batch | Commit | Verification | Remaining |
| --- | --- | --- | --- | --- |
| 2026-10-04 | B0 | [50976bb](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/50976bb) | Source review; analyzer/test failures captured; documentation whitespace check | 36 open findings; runtime verification blocked by MF-001; B1–B7 not started |
| 2026-10-04 | B1 startup | [a7ce807](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/a7ce807) | `flutter analyze --no-pub`: no issues; `flutter test --no-pub`: 3 passed; `flutter build web --no-pub`: passed | MF-001 and MF-033 closed; 34 findings open/partial; B1 formatting next |
| 2026-10-04 | B1 formatting / completion | [6c4d904](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/6c4d904) | Format check: 33 files, zero changes; analysis: no issues; tests: 3 passed; web build: passed; `flutter pub get --enforce-lockfile`: passed without lockfile changes | B1 complete; B2–B7 remain; MF-031 only startup portion completed |
| 2026-10-05 | B2 entities / mapping | [b35b841](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/b35b841) | Analysis: no issues; tests: 16 passed, including nested storage round trips, invalid role/enum/date rejection, nullable clearing and defensive collection copies | B2 repositories, use cases and view models still in progress; Firebase Timestamp conversion remains B6 |
| 2026-10-05 | B2 repositories / MVVM completion | [e816ad1](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/e816ad1) | Domain boundary: 9 files passed; formatting: 58 files unchanged; analysis: no issues; tests: 46 passed; web build: passed; enforced lockfile: unchanged | B2 complete; MF-005, MF-008, MF-009, MF-016, MF-017 closed; 29 findings open/partial overall; B3 next |
| 2026-10-06 | B3 route guards / scoped reads | [4433555](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/4433555) | Analysis: no issues; tests: 56 passed; domain boundary: 10 files passed | Cross-role and anonymous routes rejected; account reads and filters rescope on identity changes; demo notice/reset remain |
| 2026-10-06 | B3 explicit demo / session completion | [71bce4d](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/71bce4d) | Analysis: no issues; tests: 65 passed; domain boundary: 10 files passed; formatting: 65 files unchanged; web build: passed | B3 complete; MF-002, MF-003, MF-004, MF-020, MF-036 closed for demo; MF-006 demo boundary implemented, trusted Firebase roles remain B6; 24 findings open/partial; B4 next |
| 2026-10-07 | B4 slots / reservation safety | [01ea66d](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/01ea66d) | Analysis: no issues; tests: 76 passed; domain boundary: 11 files passed | Availability and demo conflicts/retries implemented; doctor selection/deep-link return covered; lifecycle/categories remain; Firebase reservation transaction remains B6 |
| 2026-10-07 | B4 lifecycle / completion | [4242f3e](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/4242f3e) | Analysis: no issues; tests: 94 passed; domain boundary: 13 files passed; formatting: 76 files unchanged; web build: passed | B4 demo complete; MF-011/012/013/014/015 closed; MF-010 demo implemented, Firebase transaction remains B6; 19 findings open/partial; B5 next |

| 2026-10-08 | B5 analytics / safe display | [b0956a7](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/b0956a7) | Analysis: no issues; tests: 102 passed; domain boundary: 14 files passed; web build: passed | MF-021/022/028 closed; 16 findings open/partial; management/payment/profile work remains |

| 2026-10-08 | B5 demo billing | [21f1a40](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/commit/21f1a40) | Analysis: no issues; tests: 114 passed; domain boundary: 16 files passed | MF-024 closed for demo; 15 findings open/partial; management/profile/availability remains |

| 2026-10-08 | B5 management / completion | Commit introducing this log entry | Analysis: no issues; tests: 128 passed; domain boundary: 18 files passed; formatting: 92 files; web build: passed | MF-023/025/026 closed for demo; B5 complete; 12 findings open/partial; B6 next |

When a finding closes, record its test/manual evidence and commit. Keep the baseline audit intact as a record of the starting point.

## B1 implementation notes

- Verified SDK: Flutter 3.47.4 stable / Dart 3.13.3; `pubspec.yaml` declares the corresponding minimums and the lockfile is re-resolved on this SDK.
- Replaced invalid transition builders with the SDK's platform defaults. Removed unused dependencies and refreshed the tracked desktop plugin registrants. Kept the Cupertino icon font because the web build references it through Flutter widgets.
- Replaced runtime Google Fonts calls with Flutter's default typography; downloading Inter is no longer an application dependency. A fresh offline browser launch still requires B7 verification.
- Added three deterministic startup widget tests: splash timing/onboarding/sign-in in light mode and dark mode, plus early disposal without a pending navigation timer.
- Splash now cancels its timer and onboarding disposes its page controller. First-run persistence remains open under MF-027.
- README now describes the implemented demo and actual remaining work. Firebase packages will be added when the adapters are implemented in B6. License selection remains with the owner.
- Formatting is a separate commit so the behavioral repair can be reviewed independently of expanded Dart formatting. It includes braces around the existing empty-state return to satisfy the lint after line wrapping; no clinic business rules changed.

## B2 implementation notes

- Domain entities/enums, snapshots, failures, contracts, use cases and queries have no Flutter, Riverpod, data or presentation imports. Enum text/colors/emoji live in presentation extensions. `tool/check_architecture.dart` enforces the dependency boundary.
- Demo repositories are injected in the composition root, own isolated immutable snapshots, and expose asynchronous reads/writes plus current-and-updated snapshot streams. All fixtures share one injected seed time.
- Patient registration adds a clinic record; doctor registration creates a profile linked through `userId`. Default doctor login now uses this linked user ID. Newly registered doctors start unavailable.
- Auth, clinic-data and booking Riverpod view models replace direct screen mutations. Tested behaviors include errors/retry, duplicate submissions, logout/disposal during pending requests, stream disposal and old refresh results arriving after new data.
- Role shells render a shared loading/error/retry gate; doctor schedule sorting creates a copy. Shared stats calculations are domain queries, while chart series remain B5 work.
- Required integration fixes brought two items forward: the router is now stable and owned/disposed by its provider (MF-008), and booking combines the selected date and time correctly (MF-009). Working search and all specialty chips are wired; doctor-card detail/booking actions remain MF-013/B4.
- Mockito mocks are generated from real repository contracts and committed. Tests verify success and failure interactions, identity/profile linkage, repository isolation, nullable clearing and storage validation; widget tests exercise all three roles and an actual appointment write.
- MF-029 is partially addressed: mapping/immutability/null clearing are implemented, but Firestore Timestamp mapping is still B6. MF-011 still needs full slot/retry idempotency policy; MF-028 still needs safe rendering of malformed stored names.
- Architecture and development guides describe the implemented layers and the limits of current verification. Cross-role guards, per-user reads, lifecycle/conflict rules, backend integration and responsive/offline browser sign-off are not claimed complete.

## B3 implementation notes

- Route access uses the authenticated record's role and active status, matches whole path segments, and redirects unauthorized users to their own portal or login. Tests cover all 14 portal paths for each role, public-route redirects and anonymous access using the actual router/widgets.
- `ClinicAccess` exposes patient-owned appointments/prescriptions/invoices and the doctor directory; doctors receive their own profile, appointments/prescriptions and patients linked through those appointments, with no billing access. Admin retains clinic-wide reads. Missing/ambiguous doctor linkage fails closed.
- All screen-facing collection and metric providers derive from the scoped snapshot. Logout immediately returns empty reads; identity changes reset specialty/search state. Synthetic repository storage remains shared within a running demo so switching accounts can explore the same workflow. This is demo visibility, not backend authorization; Firestore rules remain B6.
- Full route rendering found a raw `List` in the appointments screen that failed when accessing presentation enum extensions. The list now has an explicit `Appointment` type. Specialty chips now include all enum values.
- Login/registration explicitly identify simulated authentication; all three portals show fictional-data/session notices. Password recovery's inactive button is replaced by a working, confirmed reset action. Onboarding describes sample workflows and illustrative charts rather than unimplemented reminders/security/live insights.
- Reset closes/discards the old demo repository, drops registered auth identities and invalidates auth/clinic/booking state. Tests prove old auth/refresh completions cannot restore the discarded session, cancelled confirmation preserves data, and reset reseeds one new clock. Logout preserves clinic mutations for role switching while clearing visible account reads and filters. No durable login restoration is claimed.
- Actual widget tests exercise registration, profile logout, re-login with a different dummy password/selected role, all role/path combinations, reset cancellation/confirmation in each portal, and the role notice. No manual browser interaction is claimed; browser/platform/offline runtime verification remains B7.
- MF-002/003/004/020/036 are closed for the implemented demo. MF-006 is partial: the misleading ordinary-auth presentation is fixed; secure Firebase role provisioning/auth events remain B6 alongside MF-007/018. B4 starts with working-hours/slot conflicts and lifecycle rules.

## B4 implementation notes

- `AppointmentPolicy` derives 30-minute wall-clock slots from active doctor periods, rejects malformed/reversed/overnight periods and UTC input, deduplicates overlapping periods and allows visits ending exactly at closing. The demo uses the device's local clock; backend timezone normalization is B6. The booking date horizon remains the next 14 dates.
- New reservations check current patient activity, current doctor/fee/specialty, future working-hour slots and doctor/patient interval conflicts. Pending, confirmed and in-progress visits reserve time; terminal visits do not. Demo validation/publication has no intervening await, so competing writes inspect the latest snapshot. Firebase needs equivalent transaction/rule protection in B6.
- A booking view model retains one request ID for the same doctor/time/trimmed reason, ignores duplicate submissions and reuses the ID after an ambiguous acknowledgement failure. The repository acknowledges identical retries without another mutation and rejects ID reuse with different details. Changing the selection starts a new request.
- Doctor cards carry a stable doctor ID into the booking URL; missing IDs and unavailable doctors cannot submit. Slots update on repository changes; a selected slot taken by another patient becomes unavailable. Success goes to `/patient/appointments`; back uses GoRouter with a valid directory fallback. Widget tests cover direct entry, directory entry, AM/PM selections and competing reservations.
- Lifecycle mutations validate current role/ownership, expected status and repository time atomically. Patients cancel before the start; doctors/admins confirm before or at the start, start at/after it, complete active visits, cancel pending/confirmed visits and mark no-show at/after the scheduled end. Terminal states cannot reopen; overdue confirmed visits may still be started by staff. No automatic invoice/payment/refund mutation is implied.
- Patient lists expose disjoint Upcoming/History categories; active visits stay upcoming, terminal records remain in history even with a future date, and completed counters use the completed status alone. Admin gains a guarded full appointment page; all 15 portal paths are exercised for every role.
- A shared presentation clock updates every 30 seconds, without reseeding data. Tests advance it across check-in/no-show/midnight boundaries and dispose owned containers/timers. New writes revalidate actual clock values regardless of display timing.
- Demo fixtures now select valid working periods on any launch weekday, avoiding out-of-hours sample reservations. Regression checks cover weekdays, midnight/month/year rollover, future/past direction and seeded interval conflicts.
- Mockito mocks were regenerated for the lifecycle contract. Unit tests cover every role/status/time combination, foreign/inactive/ambiguous actors, stale/concurrent commands and payment preservation; widget tests cover cancellation confirmation, doctor check-in/completion visible in patient history, admin no-show and live-clock rollover.
- MF-011/012/013/014/015 are closed for the demo. MF-010 remains partial until Firebase reservation transactions/rules and authoritative timezone normalization in B6. Chart/payment/profile/availability management remains B5, and manual browser/platform/offline runtime sign-off remains B7.

## B5 implementation notes

- Analytics aggregate integer cents for fully paid invoices using payment dates. Partial/refunded and invalid/future-dated paid records do not contribute; excluded paid records are flagged in the chart. Six chronological month buckets include zero months and cross year boundaries, with dynamic chart scaling and explicit empty states. The all-time card and six-month chart have distinct, stated periods. These are current invoice snapshots, not a cash-flow ledger.
- Specialty sections/legends count every recorded appointment and specialty, including terminal statuses. Recent appointment changes sort by `updatedAt` descending with deterministic ID ties. Doctor completed visit fees are labeled as fees, not collected revenue.
- A shared USD formatter preserves fractional amounts everywhere. Initials trim names, fall back to `?`, and respect grapheme clusters; whitespace validation already exists in registration domain. Admin/doctor statistics let content set card height and use one column at narrow widths or large text scales. Tests cover domain aggregation, changed snapshots, empty charts and narrow large-text statistics. Full responsive sign-off remains B7.

- Demo billing now issues one consultation-only invoice per unpaid completed visit; repeated or competing issuance returns the same invoice. New invoices contain the original visit fee with no automatic tax/discount. Zero-fee visits do not need settlement.
- Only active admins can record a full settlement of an unpaid/legacy partial invoice or a full refund of a paid invoice. Money precision, item quantities/totals, tax/discount arithmetic, dates and appointment linkage are validated; expected status rejects stale/concurrent writes. Invoice and linked appointment payment status publish together, without changing visit lifecycle. Nullable invoice copy fields can be cleared; storage round trips remain supported.
- All four payment statuses render their own labels. Confirmation can preserve data; submission locks prevent repeated commands; safe error feedback refreshes the source. Tests cover permissions, races, malformed monetary values, invoice retries, stream consistency, mocks/disposal and actual issue/settle/refund UI with updated dashboard totals. No gateway, real charge/refund, partial balance ledger, additional invoice items or tax calculator is claimed.

- Admin can create a doctor with a unique profile/auth identity and email, edit either role, deactivate/reactivate patients and delete only unused profiles. Owners edit their own contact/address or doctor profile/availability. Immutable identity/email and historical appointment/invoice names/fees remain unchanged. Forms compare original/current editable values to prevent stale overwrites even at the same clock instant.
- Working-period validation rejects malformed/reversed/too-short/overlapping periods and booking without an active period. Edited periods must keep future reserved appointments; disabling new bookings retains existing visits. Doctor/patient/contact/fee validation is enforced again at the repository boundary.
- Demo sign-in now obtains registered identities from current clinic records; removed accounts cannot reuse cached identity data. A successful clinic stream updates the running profile, while removal/deactivation clears the session and scoped reads. Firebase needs equivalent authoritative role/profile events in B6.
- Four new widget workflows exercise patient editing/validation/re-login, admin doctor creation/working-period setup/deletion confirmation, linked-patient deletion rejection/deactivation and doctor booking availability. Domain/Mockito tests cover foreign/inactive actors, stale/concurrent forms, identities, nullable clearing, relationship-safe deletion, reservation preservation and disposal.
- Removed nonfunctional notification/password-change/upload controls; Settings opens Profile and About opens an actual information dialog. The app now declares only English, with no unsupported locale selector. Full browser/offline/responsive checks remain B7; real payments, a partial-payment ledger and uploads are outside the demo scope.

## B6 implementation notes

- First slice adds explicit localhost emulator configuration, default-deny rules and trusted user-document authorization. Client writes remain denied even for admins; callables obtain UID from Firebase authentication. Patient registration cannot choose a staff role or another identity.
- Reservation commands expose free UTC instants without private occupied records, normalize scheduling to Africa/Cairo, and atomically validate doctor/patient conflicts through a shared revision transaction. Payload retries are idempotent; lifecycle commands validate ownership, expected status and server time while preserving payment.
- Nine policy tests, 17 rule tests and nine service/emulator tests passed on 2026-10-09 using Node 22.23.3, Java 27, CLI 15.25.1 and Firestore emulator 1.22.0. Checks cover forged roles/owners, scoped queries/direct-write denial, malformed values, concurrent bookings, retries and DST/year boundaries. Formatting/syntax checks also pass. Dependencies resolved without known audit vulnerabilities after compatible App/Compat and patched gRPC overrides.
- [Firebase implementation/setup notes](FIREBASE.md) document schema, command contracts, measured verification and transaction scaling limits. Flutter remains runnable in demo mode; no backend app mode, live configuration/deployment or Flutter-to-emulator verification is claimed. MF-007/010/018/029 remain open/partial until the rest of B6 is implemented and exercised.
- Second slice adds transactional billing and profile commands, synchronized doctor/patient contacts and projections, reservation-preserving availability edits and safe unused-profile deletion with re-enrollment tombstones. Trusted initial-admin provisioning is an operator-only tool; doctor provisioning is admin-only and recovers from Auth/Firestore acknowledgement failures without adopting existing Auth accounts. Twelve policy tests, 17 rule tests and 19 service/emulator tests pass; syntax/format checks pass. Flutter integration remains open.
