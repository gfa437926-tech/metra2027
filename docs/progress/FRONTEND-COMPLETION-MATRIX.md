# METRA 2027 — Flutter Frontend Completion Matrix

**Updated (UTC):** 2026-11-11T16:07:16.984Z
**Repository:** `gfa437926-tech/metra2027`
**Branch:** `work/legacy-ui-migration-audit`
**Canonical Flutter path for CI:** `flutter-app/`
**Scope:** Flutter completion only. Angular work starts after Flutter acceptance.

> Statuses below distinguish implemented scaffolds from production-ready screens. A navigation entry or visual shell is not considered complete. This matrix is an initial auditable baseline from the current branch work log and CI configuration; each row must be reconciled against source files, API contracts, permissions, and tests before acceptance.

## Acceptance states

- **Not inventoried:** source implementation and requirements have not yet been individually inspected.
- **Scaffold / partial:** screen or navigation shell exists, but full workflows or live integration are not proven.
- **Blocked:** requires an API contract, approved schema, data source, or external configuration.
- **Verified:** design, workflows, API, authorization, loading/empty/error states, automated tests, and CI evidence all pass.

## Screen and capability inventory

| ID | Area / screen | Current evidence | Status | Exit criteria |
|---|---|---|---|---|
| FLT-BASE-01 | Flutter app foundation, build and lint | Client CI runs `flutter pub get`, `flutter analyze`, `flutter test` in `flutter-app/` | In verification | Green CI on this branch; documented supported SDK/platforms |
| FLT-NAV-01 | Main shell, RTL and navigation | Work log records nav wiring and More-menu entry points | Scaffold / partial | One canonical shell/sidebar; RTL checked on phone/tablet/desktop; deep navigation tests |
| FLT-AUTH-01 | Login, session and account recovery | Not evidenced as fully accepted in current work log | Not inventoried | Complete auth flows, neutral recovery responses, secure token handling, expiry and error tests |
| FLT-ACCESS-01 | Registration, approvals, roles and station assignment | Backend contracts exist; Flutter acceptance not evidenced | Not inventoried | Server-authoritative permissions, two-stage review, station scoping and denial tests |
| FLT-STN-01 | Station directory, search and details | FLT-006 search; station coordinate/elevation audit referenced in README | Scaffold / partial | Full catalogue coverage, details, filters, coordinate provenance, no fabricated live values |
| FLT-OBS-H-01 | Hourly observations | Observation submission/review APIs described in README; Flutter completion not proven | Not inventoried | Entry/edit/validation/draft/submit/return/resubmit workflows with API tests |
| FLT-OBS-D-01 | Daily observations | Daily entry point wired from More menu | Scaffold / partial | Complete daily form, validations, API lifecycle and role tests |
| FLT-OBS-P-01 | Phenomena observations | FLT review type filter includes phenomenon; complete entry workflow not proven | Not inventoried | Full phenomena capture, attachments/notes if specified, review lifecycle |
| FLT-RAIN-01 | Rainfall | Specialist shells FLT-010–017 reported; exact mapping needs source audit | Scaffold / partial | Approved rainfall fields, units, API, validation and history |
| FLT-CLIM-01 | Climate data | Specialist shell evidence only | Scaffold / partial | Variables, periods, quality flags, API and export |
| FLT-AGRI-01 | Agricultural observations | Specialist shell evidence only | Scaffold / partial | Approved forms, units, API and authorization |
| FLT-SOIL-01 | Soil temperature | Specialist shell evidence only | Scaffold / partial | Depth/units/time semantics, API and validation |
| FLT-OPS-01 | Station operations hub | Station operations widgets and support card test were changed; one test fix awaits CI proof | In verification | Flutter tests green; full operational actions backed by secured APIs |
| FLT-STATUS-01 | Station bulletin/status | ObservationStatusScreen lists review/returned items via API | Scaffold / partial | Contract coverage, filters, paging, UTC/local display, authorization and tests |
| FLT-REPORT-01 | Station reports hub | StationReportsHubScreen scaffold; entry requires selected station | Scaffold / partial | Real report catalogue, filters, PDF/Excel export and empty/error tests |
| FLT-FORECAST-01 | Forecast centres and station comparison | Prior work log describes geographic comparison based on station directory; live snapshot contract deferred | Blocked / partial | Approved live observation/bulletin API; comparisons by coordinates/elevation; provenance, freshness and quality |
| FLT-AUDIT-01 | Electronic audit | Auditor scaffold linked from More menu | Scaffold / partial | Immutable audit evidence, diffs, reviewer workflow, separation of duties and permission tests |
| FLT-AI-01 | AI analysis and decision support | Specialist shell evidence only; service/API deferred | Blocked / partial | Server-side gateway, model/version/source disclosure, uncertainty, human review and audit |
| FLT-CLIMATOL-01 | Climatol homogenization | Specialist shell evidence only; service/API deferred | Blocked / partial | Reproducible isolated jobs, immutable originals, diagnostics, breakpoints and reports |
| FLT-QUALITY-01 | Data quality and validation views | Requirements need source-by-source reconciliation | Not inventoried | Quality rules, flags, provenance and traceable correction workflow |
| FLT-EXPORT-01 | Shared exports and downloads | Reports hub scaffold only | Not inventoried | PDF/Excel output validation, Arabic fonts/RTL, access checks and file lifecycle |
| FLT-SETTINGS-01 | User preferences and application settings | Not evidenced | Not inventoried | Profile, locale/timezone, accessibility and secure configuration |

## Cross-cutting release gates

1. **Design:** compare each screen against the approved original reference; preserve Arabic labels and RTL; no duplicate sidebar.
2. **Workflow:** enumerate every field, action, filter, validation, confirmation and state transition from the requirements archive and project documents.
3. **API:** use the ASP.NET Core API for operational access. No direct privileged database access from Flutter and no invented sample observations.
4. **Security:** server-authoritative role and station scope; safe session/token storage; no service-role key in the client.
5. **States:** loading, empty, stale, offline, unauthorized, validation failure, server failure and retry.
6. **Tests:** unit, widget and integration/contract tests for successful and denied workflows.
7. **CI:** green Flutter analyze and test on the current work branch, with run URL and commit recorded.
8. **Documentation:** update this matrix and `docs/progress/WORK-LOG.md` after every implementation round.

## Immediate blockers and repository consistency findings

- The current Client CI workflow runs Flutter from `flutter-app/`, while the repository README still instructs developers to run `mobile/metra_mobile/`. Reconcile README and any stale docs only after verifying whether the old path contains unique functionality.
- Client CI `push.branches` currently lists only `main`; `workflow_dispatch` is enabled. Work-branch validation must be triggered manually or workflow branch filters must be updated by an authorized workflow-capable token.
- The previous station-operations test correction is documented as awaiting CI. Do not mark it verified until a green run is observed.
- Forecast live snapshot and specialist unit APIs are explicitly deferred in the current work log.
- No Supabase schema changes, migrations, RLS changes, legacy database operations, main merge, or deployment are authorized by this matrix.

## Next implementation sequence

1. Reconcile the Flutter source tree and CI/README path discrepancy; inspect both Flutter directories for unique screens/assets/tests before deciding the canonical source.
2. Obtain a green Flutter analyze + test run on this branch.
3. Inventory every Dart route/screen and map it to the requirements archive and existing API endpoint.
4. Complete the core observation lifecycle (hourly, daily, phenomena) before specialist modules.
5. Complete station management, operations, forecasting, reporting, then audit, AI and Climatol.
6. Close every row with linked test/CI evidence before declaring Flutter accepted.
