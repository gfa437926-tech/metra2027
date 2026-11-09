# METRA 2027 — Legacy UI migration audit

Audit date: 2026-11-08  
Reference repository: `gfa437926-tech/metra-old` (read-only)  
Current repository/branch: `gfa437926-tech/metra2027` / `work/legacy-ui-migration-audit`  
Audited current HEAD: `652bc09626db401630a795e3e07a79e30ca41b13`  
Legacy HEAD: `12a96f301102fb75bd053dd7be188a04ed38b408`

## Scope and safety

- This document records a source-level inventory only; it is not user acceptance or proof of production readiness.
- The legacy repository and legacy databases were not modified.
- No Supabase schema or data was changed.
- Presence of a screen is not equivalent to an end-to-end implementation. Each item must pass API, authorization, persistence, and UI tests before being marked complete.

## Verified CI correction

- Updated `.github/workflows/client-ci.yml` so Flutter CI uses `flutter-app/`, runs `flutter pub get`, `flutter analyze`, and `flutter test`, and triggers on `flutter-app/**`.
- Corrected the working directory in `flutter-app/DEPLOYMENT.md`.
- On HEAD `652bc096`, Client CI and Backend build completed successfully. Angular build succeeded; Flutter package restore, analyze, and test steps completed under the corrected workflow; backend build and domain/API test job completed successfully.
- These CI results do not prove mobile platform packaging or end-to-end production integration.

## Legacy-to-current feature inventory

| Legacy module / source | Angular current branch | Flutter current branch | Audit status / next work |
|---|---|---|---|
| Authentication / `index.html`, `js/auth-manager.js`, `js/login.js` | Login and registration routes/components exist | Supabase auth/session client exists | Verify full role lifecycle, recovery, lockout, and API authorization |
| Main dashboard / `main.html`, `managers/manager-dashboard.html` | Dashboard component exists | Home overview exists | Reconcile role-specific widgets and legacy workflows |
| Station catalogue | Station API and station-related UI exist | Station directory/map exists | Verify only the approved new station catalogue is used; validate pagination and coordinates |
| Hourly observation entry / `pages/hourly/hourly_send/hourly_reports.html` | `reports/hourly` component has API submission, offline queue and executable hourly validator | `ObservationSubmitScreen` exposes hourly entry and `HourlyObservationContract`; shared hourly fixtures and all 24 UTC-hour conditional rules are tested | Continue field-by-field legacy formatting parity, optional cloud/vapor widget tests, and UTC/local date semantics; not yet full visual/interaction parity |
| Daily observation entry / `pages/daily/daily_send/daily.html` | `reports/daily` has API-backed submission, offline queue and executable report-type validator | `DailyObservationSubmitScreen` and `DailyObservationContract` exist; six canonical daily fixtures are executed | Verify phenomenon/observer metadata mapping, three report-type date boundaries, offline replay and end-to-end persistence |
| Hourly reports / `view-data/pages/hourly_reports.html` | Hourly reports component exists | No reports screen identified | Verify query filters, station scoping, charts/tables, export, and API-backed data |
| Daily reports / `view-data/pages/daily_reports.html` | Daily reports component exists | No reports screen identified | Verify date/station filters, calculations, summaries, and export |
| Climate hourly / `pages/h_climate/h_climate_send/h_climate_send.html`, `view-data/pages/climate_hourly_reports.html` | Climate reports component exists | No screen identified | Verify full field model, statistics, persistence, and reporting |
| Rainfall / `pages/rain/rain_send/rainfall_reports.html`, `view-data/pages/rainfall_reports.html` | Rainfall reports component exists | No screen identified | Verify data entry, accumulated totals, report filters, and exports |
| Agricultural reports / `pages/arg/send-argicultural/agricultural_reports.html`, `view-data/pages/agricultural_reports.html` | Agriculture component exists but explicitly labels itself preview-only; submit/share disabled and no persistent API | No screen identified | Implement backend/API persistence and authorization; remove preview-only status only after tests |
| Soil temperature / `pages/soil/soil_send/soil-send.html`, `view-data/pages/soil_temperature.html` | Soil component exists but explicitly labels itself preview-only; DB/API submit and share disabled | No screen identified | Implement backend/API persistence, depth/field validation, historical display, and export |
| Weather phenomena / `view-data/pages/phenomena.html` | Phenomena list and input components/routes exist | No screen identified | Verify complete event workflow, attachments if required, authorization, and reports |
| Weather analytics / `view-data/pages/weather_analytics.html` | No dedicated analytics route/component identified in current Angular route table | No screen identified | Rebuild analytics using approved data sources and scientific calculation review |
| IT incidents / `pages/fix/it.html` | Support incidents component exists (scope equivalence needs review) | Support incident screen exists | Confirm separate IT incident categories, assignment, status lifecycle, and permissions |
| Equipment faults / `pages/fix/fix.html` | Equipment fault workflow exists | Equipment fault screen exists | Verify full old fields, attachments, workflow, and audit trail |
| Telecom issues / `pages/fix/fix-tel.html` | Support incidents component may cover this; no distinct telecom route identified | No distinct telecom screen identified | Preserve as explicit telecom workflow unless documented role-aware consolidation is approved |
| Workshop manager / `managers/workshop-manager.html` | No dedicated workshop route identified | No dedicated workshop screen identified | Implement workshop queue, assignments, work orders, and closure evidence |
| Telecom manager / `managers/telecom-manager.html` | No dedicated manager route identified | No dedicated manager screen identified | Implement telecom dashboard and role-scoped operational reporting |
| Network manager / `managers/manag-net.html` | No dedicated manager route identified | No dedicated manager screen identified | Inventory actual responsibilities and implement role-specific screens |
| IT manager / `managers/it-maneger.html` | User directory/authority access components exist; no dedicated IT manager route identified | No management screen identified | Map admin responsibilities, access lifecycle, and audit view |
| User/authority administration | Users and registration review components/routes exist | No administration screen identified | Verify every legacy role and approval/revocation lifecycle |
| Soil/agriculture/phenomena/report viewing | Partial route coverage in Angular | Not identified in Flutter | Complete feature parity by platform, not merely route presence |

## Flutter packaging and feature gaps

- Flutter source and package configuration are present.
- Android and iOS runner source trees are now present under `flutter-app/android/` and `flutter-app/ios/`; this does not yet prove signed release builds or real-device installation.
- The mobile shell currently exposes Home, Stations, Review, Entry, Operations, and Settings. Review and entry require a selected station; current README states station selection and live weather/operational reports are not fully connected end-to-end.
- Dedicated Flutter pages now exist for daily/hourly entry, observation review, equipment faults, support incidents and station operations. Dedicated Flutter analytics, climate/rainfall/agriculture/soil/phenomena reporting and full manager dashboards remain absent or incomplete.
- Before release: generate and commit required platform runners, configure signing and app identifiers, then build and install on real Android devices; build/test iOS on macOS if iOS is in scope.

## Next implementation sequence

1. Expand the audit into a field-by-field mapping for hourly and daily forms, including validation rules and conditional fields.
2. Complete backend contracts and persistence for agriculture and soil; these Angular screens currently state that they are preview-only.
3. Inspect and verify all Angular report components for API-backed data, role scoping, export, and empty/error states.
4. Implement missing Flutter modules in dependency order: hourly/daily entry, reports, rainfall/climate, agriculture/soil, phenomena/analytics, then manager/admin workflows.
5. Add explicit telecom and workshop workflows unless approved functional mapping demonstrates a true equivalent.
6. Generate Android/iOS runners and validate release builds.
7. Run cross-client contract, role-permission, persistence, regression, and UAT tests.
8. Update this table only with evidence from code and passing tests; do not mark items complete based on file existence.

## Release gates

- No legacy feature is removed without an approved replacement and passing regression test.
- No production data or schema change without prior review and approval.
- All apps use the approved new station catalogue and backend authorization.
- No preview-only form is considered production-ready.
- No release is declared complete until the field-level migration matrix and end-to-end tests are signed off.


## High-priority field-contract findings (2026-11-08)

### Hourly observation form mismatch: Flutter vs authoritative API validator

The current Flutter `ObservationSubmitScreen` exposes and submits only:
`dryTemp`, `wetTemp`, `windSpeed`, `windDirection`, `relativeHumidity`,
`stationPressure`, `visibility`, `cloudCover`, and `remarks`.

The backend `HourlyObservationValidator` requires `utcTime` and, at minimum,
`dryTemp`, `wetTemp`, `stationPressure`, `seaLevelPressure`,
`windDirection`, `windSpeed`, `visibility`, `totalCloudCover`,
`relativeHumidity`, `dewPoint`, `cover12`, and `cover123`.
It conditionally requires `precipitationAmount` at UTC hours 00, 06, 12, 18,
and `pressureSlope`, `pressureShape`, and `pastWeather` at synoptic hours
00, 03, 06, 09, 12, 15, 18, 21.

Therefore the current Flutter hourly form is a partial prototype, not a complete
legacy hourly-entry replacement. It also sends `cloudCover`, while the validator
expects `totalCloudCover`. Before release, align field identifiers and formats
across legacy source, Angular, Flutter, API request guard, and backend validator;
add tests for every required and conditional field and the local-to-UTC hour mapping.

### Daily observation

The backend daily validator currently recognizes field codes including
`minTemp`, `maxTemp`, `precipitation`, `snowThickness`, `evaporation`,
`sunshineDuration`, `sunshinePercentage`, `maxGustSpeed`,
`maxGustDirection`, `maxGustTime`, `maxHumidityTime`, `minHumidityTime`,
`maxHumidity`, and `minHumidity`, with `#` as a missing-value marker and
`T/t` for precipitation trace. Required fields are supplied separately by
report type. Flutter currently has no daily entry screen. The Angular daily
component must be checked against every original daily field and the report-type
required-field sets before it is treated as complete.

### Preview-only Angular features

The Angular agriculture component explicitly says it has no API/database
connection and disables submission and WhatsApp sharing. The soil-temperature
component also explicitly states that it is preview-only and disables database
submission and sharing. These are UI prototypes, not production workflows.
Backend contracts, persistence, role authorization, list/detail/report queries,
and export behavior remain to be implemented and tested for these modules.

### Flutter platform release readiness

The Flutter README says Android/iOS runners are not currently included and must
be generated. Passing Dart analyze/tests does not create installable APK/AAB/IPA
artifacts. Android/iOS runner generation, signing, release builds, and real-device
installation tests remain open.


### Validation API wiring — current status (2026-11-09)

The write endpoint now calls
`ObservationFieldContract.ValidateSubmission` before invoking persistence.
That contract delegates hourly payloads to `HourlyObservationValidator` and
daily payloads to `DailyObservationValidator`, selects the report-type-specific
required fields, and requires the daily responsibility acknowledgement.
Direct submission therefore cannot bypass those field checks by skipping the
separate validation endpoints.

The clients now have executable local mirrors:
- Flutter runs the six daily and two hourly canonical JSON fixtures against
  `DailyObservationContract` and `HourlyObservationContract`.
- Angular runs the same fixtures against its daily and hourly executable
  validators, and the hourly/daily submit handlers call those validators before
  submission.
- .NET runs the shared manifest through `ObservationFieldContract`.

Remaining validation work:
1. Add endpoint-level tests that submit invalid direct requests and prove the
   persistence service is never called.
2. Extend shared fixtures to cover the full hourly optional cloud/vapor field
   matrix, all UTC-hour condition combinations, and additional daily boundary
   values.
3. Compare client auto-formatting and user-facing validation behavior against
   every original legacy JavaScript helper; fixture parity alone does not prove
   visual/interaction parity.
4. Consider server-side validation-preview client methods only if a workflow
   needs them; the authenticated write endpoint already enforces the contract.

### Daily report-type behavior and persistence — current status

The legacy daily form has three report types: `24h`, `06utc`, and `18utc`.
The backend contract now applies the report-specific required-field set and
requires responsibility acknowledgement at the write boundary. Angular has
API-backed daily submission and offline queuing, and Flutter has a daily entry
screen with its own client contract and canonical submission envelope.

Still open:
- Verify the original phenomenon checkboxes and observer metadata are mapped
  into the persisted payload and read model without loss.
- Test local/UTC report-date semantics for all three report types at day
  boundaries.
- Test offline replay and server rejection/retry behavior for every report type.
- Confirm persisted values and review/read-model projections against a
  disposable integration database before production use.

## Unified hourly/daily field contract — implementation record (2026-11-08)

- Added `backend/Metra.Api/Features/Observations/ObservationFieldContract.cs` as the shared API contract authority (version 1.0).
- The contract standardizes the nested `payload.values` object and requires meteorological values to be strings, preserving fixed-width codes, decimal precision, `#`, and `T/t`.
- Hourly submission now invokes `HourlyObservationValidator` at the write boundary, so callers cannot bypass required and UTC-hour-conditional field checks by skipping the separate validation endpoint.
- Daily validation now requires one of `24h`, `06utc`, or `18utc`, requires responsibility acknowledgement, and selects the correct report-type required-field set.
- Daily submission enforces the same report type, acknowledgement, and field rules before calling the existing persistence service.
- Added `backend/Metra.Api.Tests/Features/Observations/ObservationFieldContractTests.cs` for report-type field counts, daily acknowledgement, daily required fields, hourly conditional requirements, and rejection of non-string values.
- Added `docs/contracts/OBSERVATION-FIELD-CONTRACT-V1.md` with canonical request examples, field names, conditional requirements, and UTC conversion semantics.
- No database schema, database records, legacy repository, or Supabase project was changed.

### Remaining integration and verification work

- CI for the current branch HEAD `c4abebd9ad10425e684636ffc48346a1a681a2a6` has started; results must be inspected before this contract implementation is considered build/test verified.
- Angular daily still creates page-local previews and must be connected to the station-scoped submission API using `reportType`, `responsibilityAgreement`, and `values`.
- Angular and Flutter clients must use the exact same field names and string serialization. Flutter daily UI is not yet implemented.
- Review whether the existing persistence RPC accepts and stores the canonical `reportType` and nested `values` shape without transformation; this must be confirmed from its current implementation before any database contract migration is proposed.
- Add endpoint-level integration tests proving invalid direct submission returns HTTP 400 and does not call the persistence service.
- Add explicit UTC date-rollover tests for local-hour-to-UTC conversion, then wire the same conversion into both clients.


### CI evidence update

- On code commit `c4abebd9ad10425e684636ffc48346a1a681a2a6`, GitHub Actions completed the `.NET API build` step successfully and the `Run domain and API tests` step successfully, including the new observation contract tests.
- The same Backend build workflow was still running its production container image step at the time of this update; therefore the full workflow is not yet marked successful.
- The Client CI run for the earlier code commit was cancelled when newer branch commits superseded it. The latest branch-head Client CI run is queued/pending and must be checked separately.


## Angular daily report API integration — implementation record (2026-11-08)

- Updated `angular-app/src/app/features/reports/daily-reports.component.ts` to submit the form through `ObservationApiService.submitObservation()` on both the explicit send action and normal form submission (Enter key). The previous local-only submission handler is now used only by the explicitly labelled local-draft action.
- The request uses the existing authenticated station-scoped endpoint `POST /api/v1/stations/{stationId}/observations`, with a fresh idempotency key, `observationType: daily`, report-type-specific UTC timestamp, and `submit: true`.
- The request payload now follows the v1 contract exactly: `reportType`, boolean `responsibilityAgreement`, and `values` containing only canonical meteorological field keys. Observer/station labels, notes and selected phenomena remain metadata outside `values`; form-only controls are no longer passed to the meteorological validator.
- `06utc` and `18utc` observations are timestamped at 06:00Z and 18:00Z respectively; `24h` retains the existing date-at-00:00Z convention pending confirmation of the meteorological reporting-day boundary.
- A success message is displayed only when the server returns a persisted observation `id`. If the server returns no identifier, the UI reports that persistence was not confirmed. HTTP 400 field issues are mapped to the visible validation list.
- The session list is explicitly labelled as a local display cache. It is not represented as a persistent history. The local-draft action remains separate and explicitly warns that it does not write to the server.
- No SQL migrations, database schema, database records, or Supabase project configuration were changed.

### Remaining verification

- Client CI for branch head `81d2281a0b526c1bd957b6efa79e1602cadc722e` has been queued/pending; the Angular build result is not yet available.
- A live authenticated end-to-end submission has not been performed; actual persistence must be confirmed in the configured environment by checking the returned observation ID and the station review queue.
- Confirm the correct reporting-day timestamp convention for `24h` before treating the timestamp semantics as final.
- Add automated Angular component/API tests once a test runner is configured for `angular-app`.


## Current branch status superseding historical notes (2026-11-10)

Current branch: `work/legacy-ui-migration-audit`. Current audit is source-level
and CI-backed only; it is not staging/UAT acceptance.

- The Flutter hourly and daily entry screens and their client contracts now exist.
  The shared fixture manifest is executed by Flutter, Angular and .NET for the
  implemented daily/hourly contract cases.
- Angular now executes its daily/hourly validators rather than only checking
  source structure. The all-24-UTC-hour conditional field matrix is covered.
- The authenticated .NET observation write boundary validates canonical daily
  and hourly payloads before persistence.
- Android/iOS runner source trees are present. Signed release builds, device
  installs, biometric/passkey flows, and store-ready packaging have not been
  evidenced by the current CI workflow.
- PostgreSQL 17 disposable CI validates station isolation, assignee permission,
  Npgsql column grants, and the separate Supabase `service_role` boundary.
  Current tests confirm the REST service role has SELECT-only access to
  operational records, no direct audit-table access, and RPC-only write access.
- The support/maintenance manager dashboards, attachment handling, exports,
  full analytics, climate/rainfall/agriculture/soil persistence, and complete
  visual parity remain open.
- No real staging host or authenticated staging test identity is currently
  configured. Docker smoke tests in CI are not a hosted deployment.
- No hosted database has been changed; the legacy database remains untouched.

Historical implementation notes above are retained as dated audit history;
where they conflict with this section, this 2026-11-10 status is authoritative.
