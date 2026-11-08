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
| Hourly observation entry / `pages/hourly/hourly_send/hourly_reports.html` | `reports/hourly` component exists with detailed fields and API submission path | No hourly form screen identified | Port all original fields, conditional rules, UTC/local hour mapping, and server validation to Flutter |
| Daily observation entry / `pages/daily/daily_send/daily.html` | `reports/daily` component exists with field validation and API path | No daily form screen identified | Compare every original field, missing-data markers, time/sign controls, and persistence contract |
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
- At audited HEAD, `flutter-app/README.md` says Android/iOS runners must be generated with `flutter create --platforms=android,ios .`; no `android/` or `ios/` source trees were found in the repository tree.
- The mobile shell currently exposes Home, Stations, Review, Entry, Operations, and Settings. Review and entry require a selected station; current README states station selection and live weather/operational reports are not fully connected end-to-end.
- No dedicated Flutter pages were identified for hourly/daily/climate/rainfall/agriculture/soil/phenomena/analytics reports or manager dashboards.
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


### Validation API wiring gap

The backend exposes separate `POST /api/v1/observations/hourly/validate` and
`POST /api/v1/observations/daily/validate` endpoints. The current Flutter
`MetraApiClient` exposes submission but no methods for either validation route;
the Flutter hourly screen therefore performs its own smaller client-side checks
and submits directly. The Angular hourly/daily components also need a call-site
audit to prove they invoke the authoritative validators before submission.
The submission endpoint validates request shape/type/size and delegates to the
database RPC; it does not itself call `HourlyObservationValidator` or
`DailyObservationValidator`.

Additionally, the daily validation endpoint currently calls
`DailyObservationValidator.Validate(request.Values)` without a
`requiredFields` set. The validator supports report-type-specific required
fields, but this endpoint invocation does not supply them. This leaves the
required-field policy incomplete at that API boundary. Define and validate
approved daily report-type required-field sets before treating daily validation
as production-ready.

Required remediation:
1. Define one authoritative field schema and required-field policy per report type.
2. Make submission enforce that policy server-side (not merely expose a separate
   optional validation route).
3. Ensure daily report type is explicit and selects its required-field set.
4. Add Flutter and Angular API client methods for server validation where
   pre-submit feedback is required.
5. Add negative integration tests proving malformed/missing/conditional fields
   cannot be persisted by direct API submission.


### Daily report-type behavior and persistence gap

The legacy daily form has three report types: `24h`, `06utc`, and `18utc`.
For `24h`, the original client requires the minimum/maximum temperatures,
precipitation, snow thickness, evaporation, sunshine duration/percentage,
maximum gust speed/direction/time, and maximum/minimum humidity with their
occurrence times. For `06utc` and `18utc`, only minimum/maximum temperatures,
precipitation, and snow thickness are required; the 24-hour-only phenomena,
evaporation/sunshine, wind, and humidity sections are disabled/hidden.
The legacy form also requires the responsibility agreement before submission.

The current Angular daily component reproduces report-type controls and much of
the field validation, but its `submit()` handler creates a draft in the
component's in-memory `previews` array and explicitly reports that the draft is
temporary to the current page. Its `saveDraft()` also does not persist outside
the page. The displayed "API" label therefore must not be interpreted as proof
of API-backed daily persistence. Flutter has no daily form yet.

The current backend daily validator supports a set of field rules, but the
validation endpoint does not pass a report-type-specific required-field set.
Implement explicit `24h` / `06utc` / `18utc` policy in the backend and enforce
it in the submission path, then connect Angular and Flutter to the authenticated
station-scoped submission API. Preserve the responsibility acknowledgement,
phenomena selection, local/UTC date semantics, missing-value `#` handling,
and all report-specific visibility/required behavior.


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
