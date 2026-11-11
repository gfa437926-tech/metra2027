# METRA 2027 — Scientific Reporting, Homogenization and Export Contract Draft v1

- Date: 2026-11-11
- Repository: `gfa437926-tech/metra2027`
- Branch: `work/backend-api-audit-assistant-2`
- Status: **Draft / domain-owner approval required**. This document establishes API boundaries and a field-inventory baseline; it does not certify scientific semantics or authorize database changes.
- Database scope: read-only inspection facts from the METRA 2027 project only. No DDL, migration, seed, data mutation or permission grant is authorized by this draft.
- Legacy boundary: the project named `INSERT` and all METRA OLD resources are out of scope and must not be queried or changed.

## 1. Evidence and non-invention rules

The read-only schema review found the imported historical envelope table `public.metra_observation_records` with 58,059 rows across hourly, daily, climate, agricultural, fieldclimate, soil and phenomenon types. It contains 1,251 rows with NULL `station_id` and 13 with NULL `observed_at`. Station-scoped endpoints must exclude unlinked rows and must not infer station identity from source labels.

A top-level JSON-key scan identified representative source payload fields:

| Domain | Observed keys (not yet semantically certified) |
|---|---|
| Hourly | `dry_temp`, `wet_temp`, `relative_humidity`, `dew_point`, `station_pressure`, `sea_level_pressure`, `wind_direction`, `wind_speed`, `visibility`, `precipitation_amount`, cloud-layer fields, `raw_data` |
| Daily | `max_temperature`, `min_temperature`, `max_humidity`, `min_humidity`, `precipitation`, `snow_thickness`, `sunshine_duration`, `evaporation`, weather-phenomenon flags |
| Climate | `dry_temperature`, `wet_temperature`, `relative_humidity`, `dew_point`, `vapor_pressure`, `wind_speed`, `wind_direction`, `total_cloud_cover` |
| Field climate | `measurements`, `recorded_at`, `fetched_at`, coordinates, altitude and station labels |
| Soil | `soil_temp_5cm`, `soil_temp_10cm`, `soil_temp_20cm`, `soil_temp_50cm`, `observation_date` |
| Agricultural | Air/soil temperature, humidity, wind, evaporation, precipitation, sunshine and phenomenon fields |
| Phenomenon | `phenomenon_type`, `phenomenon_date`, `start_time`, `end_time`, `phenomenon_duration`, `phenomenon_status` |

This is a structural key inventory only. It does not establish units, precision, code lists, sentinel/missing values, UTC boundary, duplicate policy, quality rules, averaging method or scientific formula. Fields such as `status`, `validation_status`, `phenomenon_status`, `is_draft` and `data_validated` inside JSON payloads are source data, not the authoritative archive/workflow status.

**Mandatory rule:** preserve raw source payloads. Do not calculate, relabel, convert, average, aggregate, homogenize or export derived scientific values until the relevant field dictionary and formula have written meteorological-owner approval and executable fixtures.

## 2. Shared report query contract

All station report reads are proposed under:

`GET /api/v1/stations/{stationId}/reports/{domain}`

Common query parameters:
- `fromUtc`: inclusive UTC timestamp; ISO-8601 with zero offset only.
- `toUtc`: exclusive UTC timestamp; ISO-8601 with zero offset only.
- `limit`: default 100; proposed bounded range 1–500.
- `offset`: default 0; non-negative and bounded.
- `qualityState`: optional only after an approved quality-state vocabulary exists.
- `includeRawPayload`: false by default; if supported, requires an explicit permission and response-size bound.

Common rules:
1. Require an authenticated actor, active account, approved station assignment and explicit read permission for the requested report domain.
2. Enforce station identity and authorization in the same database statement/transaction snapshot.
3. Validate `fromUtc < toUtc`; reject local/ambiguous timestamps rather than silently converting them.
4. Apply a deterministic order using observed timestamp and stable record ID.
5. Return data provenance and quality/availability metadata; do not silently drop incomplete rows.
6. Keep imported archive envelopes separate from operational submitted/approved observations.
7. If the source contains no eligible records, return a valid empty page, not synthetic/demo data.
8. Fail closed on authorization, storage or dependency errors.

Common response envelope (shape only; exact DTO fields require implementation review):
```json
{
  "stationId": "uuid",
  "domain": "hourly",
  "period": {
    "fromUtc": "2026-11-01T00:00:00Z",
    "toUtc": "2026-11-02T00:00:00Z"
  },
  "items": [],
  "page": {
    "limit": 100,
    "offset": 0,
    "returned": 0,
    "hasMore": false
  },
  "provenance": {
    "sourceKind": "imported_archive",
    "generatedAtUtc": "server timestamp"
  }
}
```
The example values are illustrative, not a certified daily boundary or live response.

## 3. Hourly scientific report

Proposed route: `GET /api/v1/stations/{stationId}/reports/hourly`.

Initial data source: station-linked imported archive records with `observation_type = 'hourly'`; unlinked rows and records without an observation timestamp are excluded from station/time queries and counted only in a separately authorized data-quality report.

Initial read behavior:
- Return source-preserving hourly records and raw payload, with an explicit imported/archive source label.
- Preserve recorded timestamp as UTC and expose source identifiers.
- Do not calculate derived humidity, dew point, vapour pressure, pressure reductions, wind averages or cloud totals from raw fields until formulas and units are approved.
- Do not equate a source payload's validation flag with a current METRA quality decision.

Required approval before a normalized DTO or derived values:
- Exact field dictionary, Arabic/English labels, unit, scale/precision and valid range for every hourly field.
- Missing/sentinel values and nullable-field rules.
- Station-time convention, observation timestamp interpretation and UTC/local conversion rules.
- Dry/wet-bulb psychrometric source/table version and validation fixtures, if those derived fields are required.
- Wind direction/speed coding, pressure conventions, cloud coding, visibility and precipitation accumulation periods.
- Quality-control flags, cross-field checks, rounding and duplicate handling.

## 4. Daily scientific report

Proposed route: `GET /api/v1/stations/{stationId}/reports/daily`.

Initial read behavior:
- Return source-preserving daily archive records and raw payload.
- Do not derive daily extrema or precipitation totals from hourly records until the official daily observation period and missing-data policy are approved.
- The daily report must not be assumed to mean calendar midnight-to-midnight UTC. Existing hourly bulletin times do not establish the daily period boundary.

Required approval:
- Official start/end time and whether the period is station-local, UTC or another specified convention.
- Required observations and minimum completeness for a valid daily record.
- Definitions of daily maximum/minimum, precipitation/snow/evaporation/sunshine totals and phenomenon flags.
- Handling of trace precipitation, missing values, late corrections and duplicate observations.
- Independent reference fixtures with known expected daily results.

## 5. Monthly and annual climate summaries

Proposed routes:
- `GET /api/v1/stations/{stationId}/reports/monthly`
- `GET /api/v1/stations/{stationId}/reports/annual`

These are **deferred**. No averages, totals, normals, anomalies, maxima/minima, frequency counts or completeness percentages may be computed until the domain owner approves:

1. Whether inputs are approved daily records, raw hourly records, climate observations or a specifically versioned combination.
2. Calendar/time-zone convention and treatment of leap days/month lengths.
3. Per-variable aggregation operator and units (mean, sum, max, min, count, vector mean, circular direction, etc.).
4. Minimum completeness thresholds and exact denominator.
5. Missing/trace/invalid-value treatment and quality-state inclusion policy.
6. Homogeneous-series requirements and handling of station relocation/instrument changes.
7. Rounding, significant digits and output notation.
8. Versioning of formulas and historical reproducibility.

Monthly and annual response DTOs must carry the aggregation-definition version and data-quality/completeness metadata. A number without its method and source window is not an acceptable scientific result.

## 6. Rainfall and specialist domains

Rainfall, snow, agricultural, soil-temperature, field-climate and weather-phenomenon reports remain distinct domain contracts. They must not be collapsed into generic climate totals.

For each domain, approve:
- Field dictionary and units.
- Observation period and accumulation/reset convention.
- Missing/trace/zero distinction.
- Valid ranges and quality rules.
- Duplicate and correction policy.
- Source hierarchy when imported and operational records coexist.
- Aggregation and export fixtures.

No specialist-domain calculation is enabled by this baseline.

## 7. Climatol homogenization workflow

Climatol must run server-side or in an isolated worker; never in Flutter. Proposed API lifecycle:

| Method | Route | Purpose |
|---|---|---|
| POST | `/api/v1/climatol/jobs` | Create a validated analysis job |
| GET | `/api/v1/climatol/jobs/{jobId}` | Read status, progress and configuration |
| GET | `/api/v1/climatol/jobs/{jobId}/diagnostics` | Read diagnostic outputs and candidate breaks |
| GET | `/api/v1/climatol/jobs/{jobId}/artifacts` | List reproducible outputs |
| POST | `/api/v1/climatol/jobs/{jobId}/review` | Record authorized scientific review decision |

Proposed job states: `queued`, `running`, `succeeded`, `failed`, `cancelled`, `awaiting_review`, `approved`, `rejected`. This vocabulary is a proposal and requires workflow-owner approval before persistence.

Every job must record:
- User/authority/station scope and explicit Climatol permission.
- Station series, variable, time window and reference-station selection.
- Input dataset fingerprint and immutable source references.
- Climatol/software version, parameters, environment and execution timestamp.
- Diagnostics, candidate breakpoints, adjustment factors/series and quality warnings.
- Output artifact hashes and storage provenance.
- Reviewer, decision, reason and review timestamp.

Raw observations remain immutable. Adjusted series are separate versioned products and cannot replace raw source values. An approved result must be reproducible from its recorded input fingerprint, software version and parameters. Break candidates and adjusted values are not automatically accepted as scientific truth.

## 8. Export job contract

Proposed routes:
- `POST /api/v1/stations/{stationId}/reports/exports`
- `GET /api/v1/stations/{stationId}/reports/exports/{exportId}`
- `GET /api/v1/stations/{stationId}/reports/exports/{exportId}/download`

A request must name a report domain, time window, approved format, selected columns and locale. Allowed formats (CSV/XLSX/PDF/print) must be enabled only after the owner approves their templates and dependency/licensing requirements.

Export security:
- Re-check actor permission and station scope at job creation and download.
- Use short-lived, non-guessable download references; never expose storage service credentials.
- Enforce row, file-size and execution-time limits.
- Redact private user information and protected audit metadata.
- Record requester, filters, data-source snapshot, template/definition version, artifact hash and expiry.
- Prevent cross-station download even if an export ID is known.
- Fail closed if the actor's grant or station assignment is revoked before download.

Exports must reproduce the same query and aggregation version shown in the application. Do not export unapproved derived calculations.

## 9. Flutter screen binding

The Flutter client may expose these destinations as contract-aware screens, but a screen is not considered complete merely because it renders controls:
- Hourly reports: filter, raw/normalized record detail, provenance and quality state.
- Daily reports: period filter, record completeness, detail and approved summaries.
- Monthly/annual: only after aggregation definitions and fixtures are approved.
- Climatol: job creation, progress, diagnostics, artifact provenance and scientific review.
- Exports: request, status, download, expiry and error states.

Each screen must provide loading, empty, invalid-filter, unauthorized, unavailable, stale-data and retry states. It must label imported archive records distinctly from operational submissions and live station telemetry.

## 10. Test contract

Before a domain is enabled:
- Unit tests for DTO parsing, UTC validation, pagination and domain validation.
- API tests for authentication, explicit permission, station isolation, revoked/expired grant, account state and bounded query behavior.
- Database integration tests against an isolated disposable database for row-level station isolation and authorization/data-read snapshot consistency.
- Golden fixtures for each approved scientific formula, including missing, trace, leap-year, boundary and rounding cases.
- Reconciliation tests comparing report totals with independently computed expected fixtures.
- Export tests proving scope, filters, output metadata and no private-field leakage.
- Climatol reproducibility tests using a fixed, approved sample series and pinned software version.

No tests in this draft are represented as passing.

## 11. Approval checklist — blockers

| ID | Required decision/evidence | State |
|---|---|---|
| SCI-01 | Complete meteorological field dictionary with labels, units, precision and ranges | Blocked |
| SCI-02 | Missing/sentinel/trace-value semantics by field and source | Blocked |
| SCI-03 | Hourly timestamp and UTC/local observation convention | Blocked |
| SCI-04 | Official daily period boundary and completeness rules | Blocked |
| SCI-05 | Psychrometric and other derived-field formulas/version | Blocked |
| SCI-06 | Monthly/annual aggregation operators and denominator | Blocked |
| SCI-07 | Rainfall/snow/agriculture/soil domain-specific rules | Blocked |
| SCI-08 | Climatol workflow, parameters, software version and review authority | Blocked |
| SCI-09 | Export templates, formats, limits and retention | Blocked |
| SCI-10 | Role/permission catalogue for each report and specialist workflow | Blocked |
| SCI-11 | Isolated database integration environment and CI evidence | Blocked |

## 12. Explicit non-actions and next steps

- No migration, SQL, DDL, RLS, grants, RPC or database writes were performed.
- No role was granted archive/report/Climatol/export permissions.
- No live telemetry or AI-generated scientific result is implied by this document.
- No access was made to project `INSERT` or METRA OLD.
- Next: extract and index the authoritative requirements archive; approve the field dictionary and time conventions with the meteorological owner; then convert each approved domain section into versioned DTOs, validation rules, fixtures and endpoint tests.


## 13. Implementation readiness update (2026-11-11)

- The archive reader is implemented as a source-preserving, station-scoped read path and its Flutter screen displays the original payload without scientific conversion.
- A disposable PostgreSQL 17 CI service now applies the proposed archive RPC migration and runs static/integration SQL checks. This is a focused PostgreSQL fixture for the verified authorization schema surface, not a complete Supabase stack.
- The integration fixture covers explicit individual grants, missing grant, inactive account, expired grant, revoked grant, expired station assignment, cross-station denial, demo/unlinked exclusion, pagination and UTC range filters.
- The migration's server-role guard uses the current Supabase JWT claim helper `auth.jwt() ->> 'role'`; the deprecated `auth.role()` helper is no longer used.
- Backend CI run #1542 is queued. These tests are not marked passed until GitHub Actions reports success.
- Archive permission eligibility is documented separately in `docs/security/OBSERVATION-ARCHIVE-READ-PERMISSION-SCOPE.md`: station_head, station_auditor and chief_auditor are eligible, but each user still requires an explicit approved, time-valid, revocable grant. No grants or role mappings are automatically created.
- The grant-issuance workflow and verification of the assignment role field are still blocked. Therefore no real user grant may be issued.
- Scientific calculations remain deferred until the authoritative requirements archive is extracted and the meteorological owner approves units, missing/trace semantics, daily period, quality rules, aggregation formulas, and Climatol review policy. This document does not claim the scientific reporting implementation is complete.
