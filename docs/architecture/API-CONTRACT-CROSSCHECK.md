# METRA 2027 — API contract cross-check (source-level)

**Audit date:** 2026-11-11  
**Branch:** `assistant-12/system-integration-audit`  
**Scope:** Angular/Flutter client DTOs and route construction compared with ASP.NET Core endpoint declarations, request guards and PostgREST projections.  
**Evidence type:** Static source inspection only. Database migrations/RPC definitions and live runtime responses have not yet been reconciled.

## 1. Endpoint alignment

| Operation | Angular caller | Flutter caller | ASP.NET Core endpoint | Result |
|---|---|---|---|---|
| Station directory | `GET /api/v1/stations?limit=&offset=` | `GET /api/v1/stations?limit=&offset=&stationType=` | `GET /api/v1/stations` with query parameters `limit`, `offset`, `stationType` | Path, verb and query names align |
| Observation submission | `POST /api/v1/stations/{stationId}/observations` | Same path and verb | `MapObservationSubmissionEndpoints` | Path and camelCase request property names align |
| Review queue | `GET /api/v1/stations/{stationId}/observations?limit=` | Same path and query | `MapObservationQueueEndpoints` | Path, verb and `limit` align |
| Decision | `POST /api/v1/stations/{stationId}/observations/{observationId}/decision` | Same path and verb | `MapObservationDecisionEndpoints` | Path, verb and `decision` / `note` properties align |
| Daily validation | No call found in inspected daily component/service | No call found in inspected Flutter screen tree | `POST /api/v1/observations/daily/validate` | Endpoint exists, but inspected clients do not invoke it |
| Hourly validation | No call found in inspected hourly component/service | No call found in inspected Flutter screen tree | `POST /api/v1/observations/hourly/validate` | Endpoint exists, but inspected clients do not invoke it |
| Phenomenon validation | Phenomenon input/list pages remain local/unconnected | No phenomenon-entry screen found in inspected navigation tree | `POST /api/v1/observations/phenomena/validate` | Endpoint exists; no connected submission workflow evidenced |

## 2. Confirmed client DTO mismatch — station directory

**Finding: Flutter rejects nullable fields that Angular models as nullable.**

- Angular `StationDirectoryItem` declares `local_station_code: string | null` and `name_en: string | null`.
- Flutter `StationDirectoryItem.fromJson` requires both `local_station_code` and `name_en` to be non-null strings in its required-key loop, and then casts them to `String`.
- The ASP.NET Core directory projection selects these catalogue columns directly; the endpoint does not normalize null values into strings.
- Result: any valid station row containing a null local code or English name can fail Flutter directory parsing and prevent the list from loading. This is a source-level incompatibility; a runtime fixture test has not yet been executed.

**Recommended resolution for the owning Flutter/API assistant:** model optional fields as nullable in Flutter (preferred, matching Angular and data semantics), or explicitly make the API contract guarantee non-null values only after confirming the authoritative schema and catalogue rules. Do not invent placeholder codes/names.

## 3. Observation submission DTO and validation boundary

### Request shape

Both clients construct the following camelCase shape:

- `idempotencyKey`
- `observationType`
- `observedAt`
- `payload`
- `submit`

ASP.NET Core binds the matching `ObservationSubmissionRequest` record. The Flutter client serializes `observedAt` as UTC ISO-8601; Angular constructs an ISO string for the selected observation time. The endpoint uses `DateTimeOffset?` for `ObservedAt`.

### Validation gap to verify

The submission endpoint guard currently enforces:
- non-empty trimmed idempotency key up to 128 characters;
- observation type in `daily`, `hourly`, `phenomenon`;
- non-null observation time;
- JSON object payload up to 65,536 characters.

Separate daily/hourly/phenomena validation endpoints and domain validators are mapped by the API. However, the inspected Angular observation client does not call these validation endpoints, and the submission endpoint shown does not invoke those domain validators before calling `metra_submit_observation`.

**Risk:** the client-side meteorological form checks can be bypassed by a direct API caller. It is not yet proven whether the database RPC independently enforces all domain rules. Treat this as a P0/P1 verification item: ensure authoritative validation runs server-side in the persistence path, then add negative contract tests for range, required-field, cross-field and unit/time semantics.

## 4. Review queue and decision contracts

- Queue projection selects `id`, `station_id`, `created_by`, `observation_type`, `observed_at`, `payload`, `status`, `submitted_at`, and `created_at`, filtered to the requested station and `status= submitted`.
- Angular queue item fields align with the selected projection. Flutter parser validates the required ID, station, type and observation timestamp and reads payload.
- Queue authorization checks a station-scoped grant for one of `observation.review`, `observation.approve`, or `observation.return_for_correction`.
- Decision endpoint validates `approve` / `return_for_correction`, requires a nonblank note for return, and checks the corresponding station-scoped permission before invoking `metra_decide_observation`.
- The clients use matching route and JSON property names. Actual RPC signature, transition rules, audit writes and return payload are not yet proven without migration/RPC inspection and runtime tests.

## 5. Station directory response projection

ASP.NET Core selects:
- `id`, `local_station_code`, `wmo_station_id`, `name_ar`, `name_en`, `station_type`, `operational_status`, `approval_status`, `is_demo`, `elevation_m`;
- related `station_coordinates(latitude,longitude,coordinate_source,accuracy_m)`.

Angular and Flutter both expect the related coordinate relation as a list. Flutter additionally assumes `local_station_code` and `name_en` are non-null; see finding 2.

## 6. Remaining schema/RPC verification

The following could not be confirmed from the source files inspected in this round:
1. Whether the deployed/new-project `station_catalogue` columns and nullability exactly match the API projection and both clients.
2. Whether `station_coordinates` relation cardinality and PostgREST JSON shape are identical in the target project.
3. Whether `metra_submit_observation` and `metra_decide_observation` signatures, return JSON shapes, grants and transactional behavior match the C# service payloads.
4. Whether the RPCs enforce meteorological domain validation, station ownership, idempotency and audit history independently of API guards.
5. Whether queue status values and decision transitions match the migration-defined state machine.

Migration and database test file paths were not established during this round; no schema or data was changed and no SQL was executed.

## 7. Source files inspected

- `angular-app/src/app/core/api/observation-api.service.ts`
- `angular-app/src/app/features/reports/hourly-reports.component.ts`
- `angular-app/src/app/features/reports/daily-reports.component.ts`
- `mobile/metra_mobile/lib/core/api/metra_api_client.dart`
- `backend/Metra.Api/Program.cs`
- `backend/Metra.Api/Features/Stations/StationDirectoryEndpoints.cs`
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
- `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`
- `backend/Metra.Api/Features/Observations/ObservationValidationEndpoints.cs`
- `backend/Metra.Api/Security/StationAuthorizationEndpointExtensions.cs`

## 8. Verification and safety

- Static source comparison only; no build, unit test, API call, browser/device test or database test was run.
- No workflow success is claimed.
- No migration, database, sample or production data was read or modified.
- No application source was modified; client fixes are assigned as recommendations to the responsible feature owners.
