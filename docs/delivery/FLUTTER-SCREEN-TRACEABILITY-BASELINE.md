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
| Main navigation shell | `lib/features/home/metra_home.dart` | Implemented (partial) | Replace limited five-destination shell with role-aware navigation driven by server access context; keep one shell and no duplicate sidebar. |
| Home dashboard | `_HomeOverview` in `metra_home.dart` | Implemented (partial) | Add only source-backed operational KPIs, status, alerts and role-specific actions. |
| Station catalogue | `lib/features/stations/station_directory_screen.dart` | Implemented (partial) | Verify full catalogue metadata, search, pagination, detail, elevation, coordinate provenance/history, approvals and station-scoped actions. |
| Station map | `StationDirectoryScreen._map` | Implemented (partial) | Verify map UX, clustering/performance, tile policy, coordinate quality and accessibility. |
| Observation review | `lib/features/observations/observation_review_screen.dart` | Implemented (partial) | Confirm full detail/field differences, lifecycle, review permissions, decision history and immutable audit evidence. |
| Hourly observation entry | No entry screen found in reviewed Flutter feature files | Not found in reviewed Flutter source; blocked on requirements | Extract every field, unit, precision, missing marker, UTC/local mapping, psychrometric rules, validation and submission lifecycle from authoritative sources. |
| Daily observation entry/reports | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Extract field map, date/time rules, aggregation definitions, filters and exports. |
| Weather phenomena | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Identify phenomenon codes, severity, timing, location, validation and approval rules. |
| Rainfall / precipitation | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Identify gauge/manual/automatic sources, units, accumulation periods, quality rules and reporting. |
| Climate hourly / climate reports | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Extract variables, period definitions, climatological calculations, quality rules and exports. |
| Agricultural observations | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Map all agricultural variables, units, precision, validation and source workflows. |
| Soil temperature | No dedicated Flutter feature screen found | Not found in reviewed Flutter source; blocked on requirements | Map depths, sensor/manual sources, time series, validation and reports. |
| Forecast-centre workspace | No dedicated Flutter feature screen found | Not found in reviewed Flutter source | Design station/region comparisons by verified coordinates/elevation; show live values only with source, timestamp, quality and stale status; bulletin details/revisions. |
| Electronic meteorological audit | No dedicated Flutter feature screen found; existing station audit is a distinct backend capability | Not found in reviewed Flutter source | Build audit work queue, record detail, field-level differences, evidence and server-authorized decisions; preserve append-only history. |
| AI intelligence workspace | No dedicated Flutter feature screen found | Not found in reviewed Flutter source | Define approved data scope, provenance, model identity, uncertainty, redaction, human review and backend AI gateway before UI integration. |
| Climatol homogenization | No dedicated Flutter feature screen found | Not found in reviewed Flutter source | Build job configuration/status/results/diagnostics/report UI around isolated server-side jobs; preserve raw series unchanged. |
| Reports and analytics | Placeholder `_InformationPage` in `metra_home.dart` | Placeholder | Implement role-scoped filters, reconciled aggregations, PDF/Excel and export tests against approved data contracts. |
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
- Tests executed in this round: **none**. This was a static inspection; no `flutter analyze`, `flutter test`, .NET tests or live API checks are claimed.
- Database changes: **none**.
- Flutter implementation changes: **none in this inventory-only round**.
- Next: complete authoritative requirements extraction, then implement the Flutter shared navigation/access context and one complete observation workflow end-to-end with tests before expanding to the remaining modules.
