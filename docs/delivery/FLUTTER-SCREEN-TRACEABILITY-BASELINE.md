# METRA 2027 — Flutter screen and workflow traceability baseline

Last reviewed: 2026-11-11T15:02:47.370Z
Repository: `gfa437926-tech/metra2027`
Branch: `main`
Review type: static source/document inspection only; no Flutter or API test execution is claimed.

## Status vocabulary

- **Implemented (partial)**: a real screen or client flow exists, but acceptance criteria, API coverage, or end-to-end verification remain incomplete.
- **Placeholder**: the route or visible screen exists but does not deliver the operational workflow.
- **Not found in reviewed Flutter source**: no corresponding feature screen was found in the inspected Flutter files; this is not a claim that no related backend or legacy source exists.
- **Blocked on requirements**: exact fields, states, scientific rules, or acceptance criteria cannot be finalized until authoritative source files are reviewed.

## Verified Flutter baseline

| Area | Current source evidence | Current status | Remaining work / acceptance gate |
|---|---|---|---|
| App bootstrap and configuration | `lib/main.dart`, `lib/api_config.dart` | Implemented (partial) | Verify all build flavors, configuration validation, platform builds and release setup. |
| Secure auth session | `lib/core/auth/metra_auth.dart` | Implemented (partial) | Complete account lifecycle, recovery, registration and approval states; verify refresh/revocation and platform storage behavior. |
| Login | `MetraLoginScreen` in `metra_auth.dart` | Implemented (partial) | Match authoritative design and requirements; add recovery and user-facing account-state handling. |
| Registration / approval | API and policy references exist; no corresponding Flutter workflow in reviewed auth screen | Not found in reviewed Flutter source | Build registration request, pending status, two-stage approval visibility and station assignment journey after requirement mapping. |
| Main navigation shell | `lib/features/home/metra_home.dart`, `lib/core/widgets/metra_adaptive_navigation.dart` | Implemented (partial), CI-verified | Responsive bottom navigation/rail and one shared shell; role-aware visibility remains blocked on a server-authoritative access-context contract. |
| Home dashboard | `_HomeOverview` in `metra_home.dart` | Implemented (partial) | Add only source-backed operational KPIs, status, alerts and role-specific actions. |
| Station catalogue | `lib/features/stations/station_directory_screen.dart` | Implemented (partial) | Verify full catalogue metadata, search, pagination, detail, elevation, coordinate provenance/history, approvals and station-scoped actions. |
| Station map | `StationDirectoryScreen._map` | Implemented (partial) | Verify map UX, clustering/performance, tile policy, coordinate quality and accessibility. |
| Observation review | `lib/features/observations/observation_review_screen.dart` | Implemented (partial), CI-verified | Review queue and decisions exist; complete lifecycle, field-level evidence and end-to-end permission coverage remain required. |
| Hourly observation entry | No entry screen found in reviewed Flutter feature files | Not found in reviewed Flutter source; blocked on requirements | Extract every field, unit, precision, missing marker, UTC/local mapping, psychrometric rules, validation and submission lifecycle from authoritative sources. |
| Daily observation entry/reports | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Extract field map, date/time rules, aggregation definitions, filters and exports. |
| Weather phenomena | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Identify phenomenon codes, severity, timing, location, validation and approval rules. |
| Rainfall / precipitation | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Identify gauge/manual/automatic sources, units, accumulation periods, quality rules and reporting. |
| Climate hourly / climate reports | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Extract variables, period definitions, climatological calculations, quality rules and exports. |
| Agricultural observations | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Map all agricultural variables, units, precision, validation and source workflows. |
| Soil temperature | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Map depths, sensor/manual sources, time series, validation and reports. |
| Forecast-centre workspace | `lib/features/forecast_centres/forecast_centre_screen.dart` | Implemented (partial), CI-verified | Compares 2–4 catalogue stations using verified coordinates/elevation and provenance; live telemetry and bulletins remain unavailable pending approved source/API contracts. |
| Station audit history | `lib/features/stations/station_audit_log_screen.dart` | Implemented (partial), CI-verified | Read-only station/assignment audit history. This is not the electronic meteorological-record audit workspace. |
| AI intelligence workspace | No dedicated Flutter feature screen found | Not found in reviewed Flutter source | Define approved data scope, provenance, model identity, uncertainty, redaction, human review and backend AI gateway before UI integration. |
| Climatol homogenization | No dedicated Flutter feature screen found | Not found in reviewed Flutter source | Build job configuration/status/results/diagnostics/report UI around isolated server-side jobs; preserve raw series unchanged. |
| Reports and analytics | `lib/features/reports/reports_hub_screen.dart`, `lib/features/reports/observation_archive_screen.dart` | Partial / contract-blocked, CI-verified | Reports hub and read-only observation archive UI exist. Daily/monthly/annual/climate aggregation and export remain blocked on approved API/domain contracts; do not treat placeholder report categories as complete. |
| Account settings | Basic account identity and sign-out in `metra_home.dart` | Implemented (partial) | Profile, security/session controls and approved account lifecycle features. |
| Offline / sync experience | Not established by reviewed screen code | Blocked on requirements and architecture | Define safe draft persistence, conflict resolution, idempotent retries and device data protection before adding offline writes. |

## API capabilities observed in the reviewed client

The current `MetraApiClient` exposes:
- Station directory reads with pagination and optional station-type filtering.
- Station directory pagination helper.
- Station observation review queue read.
- Observation approve / return-for-correction decision.
- Observation submission with an idempotency key and UTC timestamp conversion.

These methods do **not** establish complete coverage for every METRA workflow. API contracts, domain rules, permissions and database support must be traced per screen before a feature is marked complete.

## Cross-cutting requirements for every operational screen

1. Arabic RTL labels and consistent design tokens; one shared application shell.
2. Explicit loading, empty, error, offline, validation, forbidden and stale-data states.
3. Server-authoritative user identity, roles, station scope and permissions.
4. No direct client writes to privileged operational tables; use the ASP.NET Core API.
5. No service-role secret in mobile source, build artifacts or client logs.
6. Every weather value must identify source, station/region, observation/valid time, unit and quality where applicable.
7. Distinguish observations, numerical forecasts, derived calculations and AI interpretations.
8. No fabricated measurements, coordinates, elevations, approval states or bulletin content.
9. Preserve immutable audit history and source observations.
10. Tests must cover widget behavior, API contract, permission boundaries, validation and end-to-end workflow.

## Requirements-source blocker

The repository contains `10-5-2026 برنامج ادارة البيانات الجوية مع الربط على.rar` (629,492 bytes). The available GitHub file retrieval path cannot decode this binary RAR archive as UTF-8; the archive contents have not been inspected. The complete requirements traceability matrix remains provisional until the archive is extracted and its documents/screenshots are indexed. No requirements are inferred from the archive filename.

## Work log

- Task: **FLT-001** — requirements and Flutter screen traceability baseline.
- Status: **In progress / blocked** on binary archive inspection and full legacy source indexing.
- Review timestamp (UTC): `2026-11-11T15:02:47.370Z`.
- Evidence reviewed: current Flutter bootstrap, auth, home shell, station directory, observation review, API client, Flutter test source, workflow inventory, role-permission matrix and API deployment guide.
- Verification update (2026-11-12): Flutter Client CI #1133 passed on code commit `f3e6e730b26cb1e874c93657ff342c79abc2aaa2` (Flutter analyze; 27 Flutter tests; Angular build). Client CI #1134 passed on documentation follow-up head `2b446bdb757bf7590c73752687bcd9a9bfcd862d`. Backend CI #1549 passed on `cc190dbd29b3b81d4833cbf8d714080f31846346` (PostgreSQL 17 isolated integration/security tests, .NET build/tests and container build). These are CI checks for the respective commits, not full end-to-end or visual sign-off.
- Database changes: **none**.
- Flutter implementation changes: **none in this inventory-only round**.
- Next: complete authoritative requirements extraction, then implement the Flutter shared navigation/access context and one complete observation workflow end-to-end with tests before expanding to the remaining modules.

## Verified implementation update — 2026-11-12

The current Flutter branch now contains these additional screens/components beyond the earlier static baseline:
- Responsive shared navigation (`core/widgets/metra_adaptive_navigation.dart`).
- Forecast-centre station comparison (`features/forecast_centres/forecast_centre_screen.dart`).
- Read-only station audit history (`features/stations/station_audit_log_screen.dart`).
- Reports hub and observation archive (`features/reports/reports_hub_screen.dart`, `observation_archive_screen.dart`).
- Station directory detail metadata and station-scoped observation archive reads.

Exact-head CI evidence:
- Client CI #1133: success; Flutter analyze passed; 27 Flutter tests passed; Angular build passed.
- Client CI #1134: success on documentation follow-up head.
- Backend CI #1549: success; isolated PostgreSQL 17 tests, .NET build/tests and container build passed.

Important limits:
- These checks do not prove every Flutter screen is complete or visually identical to the original reference.
- Reports hub categories remain contract-blocked where backend/domain contracts are absent.
- Forecast-centre live measurements and bulletins remain unavailable until a verified feed/API contract exists.
- Station audit history is not the electronic meteorological-record audit module.
- AI intelligence and Climatol workflows are still not implemented as complete operational modules.
- The RAR requirements archive remains uninspected; full authoritative traceability is therefore blocked.
## Forecast-centre widget test addition — 2026-11-12

- Added `mobile/metra_mobile/test/forecast_centre_screen_test.dart`.
- Test coverage: station-directory API loading, geographic comparison and coordinate provenance display, reference-station switching, and permission-specific API failure state.
- Commit: `557435c6674466c3b13866af833c976ee4a0f12b`.
- CI status for this commit: **not yet observed**. The test source is committed, but no passing analyze/test result is claimed for this new head.