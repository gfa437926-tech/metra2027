# FLT-004 — Station catalogue metadata details

- **UTC timestamp:** 2026-11-11T15:34:26.685Z
- **Task:** FLT-004
- **Status:** In progress — implementation committed; Flutter execution and visual acceptance pending.
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `main`

## Objective

Expose station metadata already returned by the authoritative ASP.NET Core station-directory projection, with clear provenance and without implying that catalogue metadata is live telemetry.

## Source contract inspected

`GET /api/v1/stations` reads the non-demo `station_catalogue` projection and selects:
- station identity, local/WMO identifiers and Arabic/English names;
- station type, operational and approval status;
- `elevation_m`;
- active coordinate relation fields `latitude`, `longitude`, `coordinate_source`, `accuracy_m`.

No database schema, migration or endpoint contract was changed in this task.

## Changes committed

1. Extended `StationDirectoryItem` in `mobile/metra_mobile/lib/core/api/metra_api_client.dart` to parse `elevation_m`, coordinate source and coordinate accuracy while preserving the existing coordinate validation behavior.
2. Added a station details bottom sheet in `station_directory_screen.dart` showing the station identifiers, type, verified catalogue elevation, coordinates, coordinate source/accuracy and approval/operational states.
3. Added explicit UI wording that station catalogue metadata is not a live meteorological measurement or device-connectivity status.
4. Extended the station-directory widget-test source with a fixture containing elevation and coordinate provenance, and assertions for the details sheet.

## Commits

- Model metadata: `0f6dd687dc2760b60601185518063772a72c5259`
- Details sheet: `e399ea2e6f21fae3f2623ad34a0fa29dade2c13a`
- Test fixture and assertions: `5de8d7815baa0d5dd6f5ed3691947aee1ee7f7ce`
- Source formatting/metadata parsing corrections: `549b14780f5223fa44b8eecae641056eb6cdbf30`, `8e136e3f3df9c86b63fdccc98f2bd496d1e8f99a`

## Verification

- Re-fetched the committed Flutter API model, station screen and widget-test source from GitHub.
- **Not run:** `flutter analyze`, `flutter test`, Android/iOS builds, device runtime checks or visual regression tests. Flutter/Dart executables are not available in the current execution environment.
- The test additions are source-level only and are not reported as passing.
- No live station data or live telemetry was queried.

## Remaining work

1. Execute analyzer and tests in a Flutter-enabled CI/development environment; fix any compile/runtime failures.
2. Verify metadata rendering on mobile, tablet and desktop layouts, including missing elevation/coordinates and invalid coordinate values.
3. Build the forecast-centre comparison workspace only against the approved station catalogue and future approved telemetry contract; clearly distinguish static station metadata from live observations.
4. Keep role-specific navigation blocked until the API provides an authoritative current-user access context or an equivalent validated server contract.
5. Continue requirements archive inspection and field/rule traceability (FLT-001 remains in progress).

## Data and security statement

- New Supabase database: unchanged.
- Legacy database: untouched.
- No migrations, RLS, policies, RPC grants, credentials or backend endpoints changed.
- Flutter continues to read station data through the ASP.NET Core API.
