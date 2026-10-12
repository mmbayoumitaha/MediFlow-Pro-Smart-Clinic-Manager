# Release checks

Observed on October 12, 2026. Results describe the checked scope and are not a guarantee that every possible defect has been found.

| Check | Evidence |
| --- | --- |
| Flutter analysis | No issues |
| Unit/widget suite | 241 passing tests, including 72 width/text-scale cases |
| Domain boundaries | 21 domain files checked; no framework/data/presentation dependencies |
| Backend tests | 79 passing Auth/Firestore emulator and operator cases |
| Web | Release build succeeds; 64-second portrait Chromium walkthrough covers patient booking, doctor schedule and admin screens with external endpoints blocked; zero severe errors and zero external requests |
| Android | Debug APK builds with updated application ID and icons; release distribution signing remains an owner prerequisite |
| Linux | Release demo bundle builds |
| iOS/macOS/Windows | Branding updated; builds and runtime unverified on this Linux host |

## Review coverage

Source review followed authentication/session restoration, route guards, scoped reads, stale-response handling, reservation retry/conflict locks, appointment lifecycle, billing atomicity, profile validation/deletion, timezone mapping, view-model disposal and responsive layouts. Regressions reproduced unsupported profile fields reaching account creation and overlong booking reasons reaching storage; shared validation now rejects those fields before creating an Auth identity. UI/browser checks also exposed an unbundled greeting glyph, replaced with ordinary local text.

## Baseline finding disposition

The original findings remain an archival description of the earlier code in [PROJECT_AUDIT.md](PROJECT_AUDIT.md).

| Finding IDs | Current disposition and evidence |
| --- | --- |
| MF-001, MF-033 | Resolved: supported SDK/theme, used dependencies and locked versions; analysis/tests/builds pass |
| MF-002–MF-008, MF-036 | Resolved for supported modes: role/path matrix, scoped records, consistent identity linkage, explicit demo boundary, trusted Firebase roles, owned router and stale-session tests |
| MF-009–MF-015 | Resolved: selected-time persistence, availability/conflicts/retries, directory/deep links, lifecycle/category policies; widget and real browser workflows pass |
| MF-016–MF-018, MF-029 | Resolved: immutable snapshots, independent domain, injected adapters/view models, strict mapping, optional connected mode and emulator evidence |
| MF-019–MF-020 | Resolved for packaged demo: local renderer/fonts, fresh no-external-request browser run; explicit in-memory reset/logout policy |
| MF-021–MF-024 | Resolved: source-derived analytics and USD semantics, guarded management, correct invoice statuses and atomic settlement/refund workflows |
| MF-025–MF-028 | Resolved within declared scope: functioning profile/settings/about/recovery, removed unsupported controls, English-only UI, owned onboarding controller, validated names and safe initials; onboarding intentionally repeats on restart |
| MF-030–MF-031 | Resolved in measured formats: 72 responsive cases, 241 meaningful Flutter tests, Mockito interactions and separate backend/browser tests |
| MF-032 | Resolved: [remote verification](https://github.com/mmbayoumitaha/MediFlow-Pro-Smart-Clinic-Manager/actions/runs/38303393645) passed Flutter and Firebase jobs, including all four browser targets; required merge checks are not configured by the workflow file |
| MF-034 | Source/configuration fixed: IDs, branding, Internet permission and explicit signing; Android debug/Linux release build evidence. Store signing and untested platform runtime remain separate |
| MF-035 | Resolved: product documentation, MIT license and explicit verification limits |

Linux interactive launch built the debug executable but could not open a display in the check environment. This is a host limitation; Linux runtime is not recorded as verified.

## Cloud boundary

Email/password Auth, deployed rules/indexes and an operator-provisioned initial administrator exist in the live project. A registered live web release was observed at its connected login screen; anonymous profile access was rejected. The owner signed in privately and supplied screenshots showing the connected admin dashboard, doctors, patients and billing pages rendering their empty states. This confirms live admin entry and initial reads; authenticated live booking, staff creation and billing mutations have not been observed. The full fictional emulator journeys exercise actual SDK/rules behavior separately. See [Firebase setup](FIREBASE.md).

Connected mode needs a server connection; the demo needs its packaged/local assets and no backend. Cold browser reload while the asset server is unreachable is not supported by a service worker. Native device interactions, native connected Firebase, store releases, clinical deployment, production capacity and payment processing are not established by these checks.
