# MediFlow Pro: repair batches

Created: 2026-10-04 (Africa/Cairo). Baseline: `5a02453`.

The owner requested an audit first, collaborative scheduling, and small commits pushed after each completed batch, then delegated the scheduling choice. Completion-driven batches are selected: work follows the dependency order below, with no fixed daily deadlines. Implementation scopes are proposed until each batch is undertaken. Actual commits retain their real author/committer timestamps. Progress is recorded through completed changes, check results and GitHub commit links.

Findings and evidence: [PROJECT_AUDIT.md](PROJECT_AUDIT.md).

## Delivery order

| Batch | Scope / audit IDs | Depends on | Required evidence before completion | Status |
| --- | --- | --- | --- | --- |
| B0 | Document source audit, CV gaps, baseline failures and this repair plan | — | Evidence-backed issue inventory; documentation diff checked | Complete in the commit introducing this plan |
| B1 | Restore compilation; align toolchain/lockfile; repair smoke test, trim unused dependencies and analyzer diagnostics. MF-001, MF-031 baseline, MF-033 | B0 | `flutter analyze`, deterministic startup test, `flutter test`, `flutter build web` pass; record exact SDK | Startup checks passed; formatting baseline in progress |
| B2 | Introduce actual domain/data/presentation boundaries, repository contracts, injected demo repository, use cases and Riverpod view models; immutable state and model mapping. MF-005, MF-016, MF-017, MF-029 | B1 | Domain imports no Flutter/Firebase; screens use view models; isolated repository/unit/Mockito tests for mapping and state interactions | Proposed |
| B3 | Explicit demo mode, stable router, role guards, patient/doctor data scoping, safe auth state and session/reset behavior. MF-002, MF-003, MF-004, MF-006, MF-008, MF-020, MF-036 | B2 | All role/path combinations, auth failure/logout races and cross-user reads tested; manually exercise login/logout | Proposed |
| B4 | Correct booking time, availability/conflicts/retries, appointment lifecycle/categories, working search and deep-link return. MF-009–MF-015 | B3 | Booking and status business rules tested, including midnight/AM-PM/time boundaries and conflicts; patient-to-doctor workflow verified | Proposed |
| B5 | Working doctor/patient admin management, profiles/availability, billing, truthful analytics and correct activity/revenue semantics. MF-021–MF-025, MF-028 | B4 | Analytics unit tests with empty/multi-month data; management/payment/view-model tests; charts update after writes | Proposed |
| B6 | Implement optional configurable Firebase Auth/Firestore adapters, secure role provisioning, transactions, maintained rules/indexes and emulator tests. MF-007, MF-018, MF-029 Firebase mapping, MF-034 Android networking | B5 | Backend mode exercised against emulators; rules reject escalation/forgery/cross-user access; demo works with no configuration | Proposed |
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

- Demo changes: session-only versus local persistence; provide a predictable reset either way.
- Firebase: repository-owned configuration template and emulator setup can be completed locally. A deployed project needs the owner's project/configuration and administrator provisioning. Do not invent credentials or claim live verification without them.
- Currency: select one explicit currency for the clinic and use it consistently.
- Language: implement English/Arabic fully or narrow documentation to English.
- Scope: CV-critical workflows come first. Optional notifications, uploads, PDF export and medical records must be implemented, disabled with an explanation, or removed from claims; they are not implied complete by declared packages.
- License: owner selects the license; remove unsupported commercial-use wording until resolved.
- Platform claims: web can be checked locally; only claim Android/iOS/desktop verification when the appropriate build/runtime checks actually run.

## Progress log

| Date (Cairo) | Batch | Commit | Verification | Remaining |
| --- | --- | --- | --- | --- |
| 2026-10-04 | B0 | See commit introducing these documents | Source review; analyzer/test failures captured; documentation whitespace check | 36 open findings; runtime verification blocked by MF-001; B1–B7 not started |
| 2026-10-04 | B1 startup | Commit introducing the startup repair | `flutter analyze --no-pub`: no issues; `flutter test --no-pub`: 3 passed; `flutter build web --no-pub`: passed | MF-001 and MF-033 closed; 34 findings open/partial; B1 formatting next |

When a finding closes, record its test/manual evidence and commit. Keep the baseline audit intact as a record of the starting point.

## B1 implementation notes

- Verified SDK: Flutter 3.47.4 stable / Dart 3.13.3; `pubspec.yaml` declares the corresponding minimums and the lockfile is re-resolved on this SDK.
- Replaced invalid transition builders with the SDK's platform defaults. Removed unused dependencies and refreshed the tracked desktop plugin registrants. Kept the Cupertino icon font because the web build references it through Flutter widgets.
- Replaced runtime Google Fonts calls with Flutter's default typography; downloading Inter is no longer an application dependency. A fresh offline browser launch still requires B7 verification.
- Added three deterministic startup widget tests: splash timing/onboarding/sign-in in light mode and dark mode, plus early disposal without a pending navigation timer.
- Splash now cancels its timer and onboarding disposes its page controller. First-run persistence remains open under MF-027.
- README now describes the implemented demo and actual remaining work. Firebase packages will be added when the adapters are implemented in B6. License selection remains with the owner.
- Formatting is a separate commit so the behavioral repair can be reviewed independently of expanded Dart formatting.
