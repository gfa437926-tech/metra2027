# METRA API — OpenAPI / Contract Inventory (Stage B)

**Branch:** `work/backend-db-integration-phase`  
**Note:** Documentation-only expansion. Runtime behavior of existing endpoints is unchanged except for the new fail-closed archive route.

## Runtime OpenAPI

- Package: `Microsoft.AspNetCore.OpenApi` + patched `Microsoft.OpenApi`
- Development mapping: `app.MapOpenApi()` in `Program.cs` (Development only)

## Existing authenticated station-scoped routes (summary)

| Method | Route | AuthZ focus |
|--------|-------|-------------|
| GET | `/api/v1/stations` | Authenticated directory |
| POST | `/api/v1/stations/{stationId}/review` | `stations.catalogue.review` + station scope |
| GET | `/api/v1/stations/{stationId}/users` | `users.station.view` |
| GET | `/api/v1/stations/{stationId}/audit-log` | `users.station.view` |
| GET/POST | station assignments / decisions / revoke | station manage permissions |
| GET/POST | registration requests / decisions | registration permissions |
| GET | `/api/v1/stations/{stationId}/observations` | observation queue (submitted) |
| POST | `/api/v1/stations/{stationId}/observations/{id}/decision` | review/approve/return |
| POST | observation submission routes | create/submit |
| POST | `/hourly/validate`, `/daily/validate`, `/phenomena/validate` | validation only |
| GET/POST | authority memberships & permission-grants | authority-scoped |
| GET | `/api/v1/health` | anonymous |
| GET | `/api/v1/ready` | readiness (config + bounded checks) |

## New contract (Stage B)

### GET `/api/v1/stations/{stationId}/observation-archive`

- **Purpose:** List historical observation archive items for one station.
- **Auth:** JWT required (`sub` claim).
- **Authorization:** `IStationAuthorizationService.HasStationPermissionAsync(user, station, "observation.archive.read")` must be true. Domain policy also enforces station match + `ObservationPermission.ArchiveRead`.
- **Not sufficient alone:** role, authority membership, `observation.review`, grant on another station.
- **Query:** `fromUtc`, `toUtc`, `observationType`, `limit` (1–100, default 25), `cursor`.
- **Success 200:** `{ items, hasMore, nextCursor }`
- **403:** `archive_permission_denied` / `station_scope_violation` / related codes
- **503:** `archive_service_unavailable` while read-model not configured (current default)
- **401:** missing/invalid identity

Until an approved isolated read-model is enabled, the service implementation is `UnconfiguredObservationArchiveService` (fail-closed, no synthetic rows).

## Flutter mapping

| Flutter screen | Contract |
|----------------|----------|
| Observation archive UI | GET station observation-archive (above) |
| Observation review | existing queue + decision |
| Hourly/Daily entry | existing validation + submission (scientific bounds from legacy validators; unresolved rules documented separately) |
| Station directory / audit | existing station routes |
| Reports hub | archive entry + future report contracts (blocked until approved) |

## Unresolved scientific rules (not invented)

- Any field range not already present in `HourlyObservationValidator` / `DailyObservationValidator` (derived from legacy hourly/daily sources) remains **blocked** pending authoritative extraction.
- Psychrometric consistency checks beyond existing validator logic are not added in Stage B.
