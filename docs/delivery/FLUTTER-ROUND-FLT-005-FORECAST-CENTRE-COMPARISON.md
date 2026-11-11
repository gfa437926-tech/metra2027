# FLT-005 — Forecast-centre station comparison workspace

- **UTC timestamp:** 2026-11-11T15:37:35.040Z
- **Task:** FLT-005
- **Status:** In progress — catalogue comparison UI and test source committed; execution and live-data integration blocked.
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `main`

## Objective

Start the dedicated forecast-centre workspace with a defensible first slice: compare approved station-catalogue metadata by location and elevation, without presenting invented telemetry as live observations.

## Changes committed

1. Added `mobile/metra_mobile/lib/features/forecast_centres/forecast_centre_screen.dart`.
   - Loads station records through the existing ASP.NET Core-backed `getAllStationDirectory()` client method.
   - Allows selection of two to four stations.
   - Compares verified catalogue elevation, latitude/longitude, coordinate source and accuracy.
   - Allows a selected reference station and computes great-circle distance using the Haversine formula only when both coordinate pairs pass existing range validation.
   - Provides loading, API error, empty catalogue and retry states.
   - Includes a scientific caution that location/elevation alone do not establish weather conditions or justify measurement correction.
   - Explicitly marks live observations and bulletins unavailable; no sample readings are fabricated.
2. Integrated the new screen into the main Flutter navigation as **مراكز التنبؤ**. Existing destinations remain present; review/report/settings indices are shifted consistently with the inserted page.
3. Added widget-test source coverage using two fixture station catalogue records, checking the unavailable-live-feed guard and geographic/elevation comparison.

## Commits

- Screen implementation: `1d3286cd1981102ad0afb15ff9f31e3421408754`
- Dart compatibility cleanup: `9dce065ae5ba36c154163e0dd54fcae2e55f6051`
- Main navigation integration: `bfe0282a3c9541375d85b7f0c4a398fe03fefc8e`
- Widget test source: `6271ce521d46ae7772bca50e60ee408153e26e9f`
- Source formatting repair: `a08613f05593bedafaba839cc1191e58b7b4fba0`

## Verification

- Re-fetched the committed home shell, forecast-centre screen and widget-test source from GitHub.
- Static source inspection confirmed balanced curly-brace counts in the reviewed files and no remaining escaped-newline artifacts in the forecast-centre source.
- **Not run:** `flutter analyze`, `flutter test`, Android/iOS builds, runtime interaction or visual regression tests. The current execution environment does not provide Flutter/Dart.
- The widget test is committed as source only and is not claimed to pass.
- No CI workflow result is claimed for this round.

## Data contract and blockers

- The reviewed station-directory API supplies catalogue identifiers, coordinates, coordinate provenance/accuracy and `elevation_m`.
- The reviewed API client has no telemetry query, latest station observations, rainfall/wind/temperature/humidity/pressure feed, bulletin list/detail, quality flag or freshness contract.
- Therefore the live measurement/bulletin panel is explicitly unavailable. Building live cards or charts requires an approved provider/ingestion contract and backend authorization, provenance, timestamp, quality and stale-data semantics.
- The role-specific access-context endpoint remains unverified; this screen relies on the API's existing authorization for the station directory and does not infer a user's role.

## Remaining work

1. Run Flutter analyzer and widget tests in a Flutter-enabled CI environment; fix any reported issues.
2. Verify RTL, accessibility, large station lists and mobile/tablet/desktop behavior.
3. Define the telemetry/bulletin source and server-side read contract, including station/time/source/quality/freshness provenance.
4. Implement live readings and bulletin details only after that contract is reviewed and approved.
5. Continue FLT-001 requirements archive extraction and full requirement traceability.

## Data and security statement

- New Supabase database: unchanged.
- Legacy database: untouched.
- No migration, RLS, policy, RPC, permission grant, credential or backend endpoint changes.
- No direct database access or operational writes added to Flutter.
