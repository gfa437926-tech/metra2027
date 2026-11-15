# METRA greenfield station directory projection contract

**Status:** executable domain mapper and unit tests exist; no database adapter, endpoint or hosted operation is wired.
**Source of truth:** the read-only physical dictionary for `catalog.stations`, `catalog.station_types` and `catalog.station_locations`.
**Security:** the projection is only safe behind a server operation that derives the actor from a validated JWT and applies approved directory visibility rules. The mapper does not authorize access.

## Physical mapping

| Projection field | Physical source |
|---|---|
| `id`, `station_code`, `name_ar`, `name_en`, `wmo_identifier` | `catalog.stations` |
| `approval_status`, `operational_status` | `catalog.stations` |
| `station_type_code`, `station_type_name_ar`, `station_type_name_en` | `catalog.station_types` via `station_type_id` |
| `latitude`, `longitude`, `location_source`, `horizontal_accuracy_m` | Current `catalog.station_locations` row |
| `elevation_m`, `timezone_name` | Current `catalog.station_locations` row; station-level values may be used only under an explicit, tested fallback rule |

The current location is selected by a validity predicate (`valid_to IS NULL`) and the query must guarantee at most one current row per station. The mapper independently rejects duplicate station IDs/codes so a faulty join cannot silently multiply directory entries.

## Flat response contract

The future `stations.directory.v1` operation returns a bounded JSON array of flat records using the exact field names above. It must not return legacy fields such as `local_station_code`, `is_demo`, or nested `station_coordinates`. No demo flag is inferred.

The domain mapper:
- Requires a valid non-empty UUID, station code, localized names, station type and lifecycle states.
- Exposes only `approval_status = approved` and `operational_status IN (active, temporarily_closed)`; planned, inactive, decommissioned, rejected, pending and suspended rows fail closed.
- Validates coordinate ranges, coordinate pairing, non-negative horizontal accuracy, bounded strings, optional numeric types, duplicate identity and a maximum of 500 rows.
- Rejects the entire projection on any malformed row rather than returning a partial catalogue.
- Preserves WMO identifier, station type localization, location source, elevation, timezone and horizontal accuracy as separate typed fields.

## Implemented code

- `backend/Metra.Api/Domain/Stations/GreenfieldStationDirectoryMapper.cs`
- `backend/Metra.Api.Tests/Domain/GreenfieldStationDirectoryMapperTests.cs`

These are provider-neutral mapping and unit-test components. They do not connect to Supabase, execute SQL, perform station authorization, or make `/api/v1/stations` operational.

## Remaining integration gates

1. Approve the exact station visibility rule and whether temporarily closed stations appear in general pickers.
2. Approve the caller-scoped runtime identity and operation boundary; do not use `service_role` for user-scoped reads.
3. Build the operation against a curated disposable greenfield schema and prove one-current-location semantics.
4. Add integration tests for anonymous access, cross-organization scope, pending/rejected station exclusion, duplicate current locations and pagination.
5. Replace the legacy adapter only after those tests pass; keep the legacy feature flag disabled.
6. Do not apply migrations or write to the hosted database until the schema and access matrix are approved.

No hosted database, old database, credentials, grants, RLS policies, storage or deployment settings were changed by this increment.
