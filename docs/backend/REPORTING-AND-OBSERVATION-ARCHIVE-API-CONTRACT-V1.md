# METRA 2027 — Reporting and Observation Archive API Contract Baseline v1

- Date: 2026-11-11
- Backend: ASP.NET Core 10 / .NET
- Status: API interface baseline drafted under the owner's instruction to proceed with report/archive contracts; database implementation remains gated by schema and permission review.
- Scope: station-scoped read-only observation archive and reporting read surfaces.
- Exclusions: no database writes, SQL, migration, RPC deployment, RLS, seed, production access, or legacy repository/database changes.

## 1. Source facts used

The current backend source confirms the observation persistence boundary already uses `metra_observations` and the queue read selects these existing fields:

- `id`
- `station_id`
- `created_by`
- `observation_type`
- `observed_at`
- `payload`
- `status`
- `submitted_at`
- `created_at`

The current submission request accepts observation types `hourly`, `daily`, and `phenomenon`. The existing GET `/api/v1/stations/{stationId}/observations` is specifically the submitted review queue, not a general archive. No general detail/version-history/report-aggregation endpoint was found in the reviewed Backend source.

This baseline intentionally does not infer any additional database columns, version tables, audit tables, status values, report formulas, or observation field catalogues.

## 2. API surface baseline

The following route family is the target interface. Routes marked **deferred** must not be advertised as operational until their persistence and permission dependencies have passed review.

| Method | Route | Contract | State |
|---|---|---|---|
| GET | `/api/v1/stations/{stationId}/observations/archive` | Filtered, paged archive list | Interface defined; implementation gated |
| GET | `/api/v1/stations/{stationId}/observations/{observationId}` | One observation and its raw submitted payload | Interface defined; implementation gated |
| GET | `/api/v1/stations/{stationId}/observations/{observationId}/history` | Immutable version/event history | Deferred: version/event persistence not established |
| GET | `/api/v1/stations/{stationId}/reports/hourly` | Hourly report read model | Deferred: report projection and period rules |
| GET | `/api/v1/stations/{stationId}/reports/daily` | Daily 24-hour report read model | Deferred: daily boundary and required-field approval |
| GET | `/api/v1/stations/{stationId}/reports/monthly` | Monthly climate summary | Deferred: approved statistic/completeness rules |
| GET | `/api/v1/stations/{stationId}/reports/annual` | Annual climate summary | Deferred: approved statistic/completeness rules |
| GET | `/api/v1/stations/{stationId}/reports/exports/{exportId}` | Export job/result retrieval | Deferred: export job and storage contracts |

The existing review queue and decision routes retain their current meaning and are not repurposed as archive endpoints.

## 3. Archive list request

Query parameters:

- `type`: optional; only `hourly`, `daily`, or `phenomenon`.
- `status`: optional; must match a persisted status returned by the data source. The API must not invent or silently normalize status values.
- `fromUtc`: optional ISO-8601 timestamp with zero UTC offset; inclusive.
- `toUtc`: optional ISO-8601 timestamp with zero UTC offset; exclusive.
- `limit`: default 50, range 1–100.
- `offset`: default 0, non-negative and bounded by the implementation's documented maximum.

Validation rules:

1. Reject non-zero timestamp offsets with `400 utc_offset_required`; do not silently convert local timestamps.
2. Reject `fromUtc >= toUtc`.
3. Apply exact station ID and all validated filters in the data query itself.
4. Use deterministic ordering `observed_at DESC, id DESC`.
5. Never allow caller-supplied SQL, PostgREST fragments, sort expressions, or column names.
6. Do not return a partial result as a successful complete archive when the dependency fails.

## 4. Archive list response

The stable envelope is:

```json
{
  "items": [
    {
      "id": "uuid",
      "stationId": "uuid",
      "createdBy": "uuid",
      "observationType": "hourly",
      "observedAtUtc": "2026-11-10T18:00:00Z",
      "status": "submitted",
      "payload": {},
      "submittedAtUtc": "2026-11-10T18:01:00Z",
      "createdAtUtc": "2026-11-10T18:00:12Z"
    }
  ],
  "page": {
    "limit": 50,
    "offset": 0,
    "returned": 1
  }
}
```

All timestamps are UTC. The example status and payload are illustrative only. The response must serialize only fields verified to exist in the selected schema. If a nullable database timestamp is absent, the corresponding response property is nullable; the API must not synthesize it.

## 5. Detail response

The detail route returns the same persisted identity, station, type, timestamp, status and payload fields as the archive item. It may add validation or decision metadata only after the source table/view and permission policy for those fields are verified.

A record ID never grants access by itself. The station ID in the route must match the record's persisted station ID and the actor's server-verified access scope. A record from another station must not be disclosed.

## 6. Authorization and security gates

- Actor identity is derived exclusively from the validated JWT `sub`.
- The requested station ID is a selector, not authorization evidence.
- An explicit archive-read permission must be present in the authoritative permission catalogue and enforced server-side. Do not infer it from role names or reuse review/approve permissions without owner/security approval.
- Authorization and row selection must be atomic or provide a documented database isolation/locking guarantee. The known B-013 queue TOCTOU finding is not considered fixed by adding another API-side permission check.
- The service-role key remains server-only.
- Fail closed on missing configuration, denied scope, malformed database responses, timeout, or dependency failure.
- Do not expose another station's record existence; final 403/404 behavior must be consistent with the approved disclosure policy.

## 7. History, corrections and immutable versions

The currently reviewed persistence contract does not establish a version table or append-only observation event ledger. Therefore the API must not fabricate `version`, `history`, actor labels, correction notes, or decision events from `created_at`/status alone.

Before implementing history/correction routes, approve:
- version/event storage and retention;
- append-only guarantees and who can read actor/reason metadata;
- correction eligibility and transition matrix;
- expected-version convention (`If-Match`/ETag or explicit expected version);
- atomic compare-and-set semantics and 409 behavior.

Corrections must append a new version and never overwrite the prior payload. No correction endpoint is approved for implementation until that storage contract exists.

## 8. Report semantics — explicit non-invention boundary

- Daily report semantics remain a 24-hour summary. 06:00 UTC and 18:00 UTC are hourly bulletin times, not daily report boundaries.
- The exact daily UTC period boundary and daily required-field catalogue remain unresolved.
- Monthly/annual averages, totals, maxima/minima, completeness thresholds, missing-data treatment, units and aggregation version must be approved by the meteorological owner before calculations are implemented.
- Rainfall, agriculture, soil temperature, snow and specialist products remain separate report domains; no formula or requiredness is inferred here.
- Climatol outputs must be consumed as versioned worker results with input/output provenance; Flutter must not calculate homogeneity results.
- Export generation requires a server-side job/result contract and the same station authorization as the underlying report.

Until those rules are approved, the endpoints remain deferred and the existing Flutter reports hub must show an unavailable/awaiting-contract state rather than placeholder numbers or charts.

## 9. Error mapping

| HTTP | Meaning |
|---|---|
| 400 | Invalid filters, UTC timestamp, or pagination |
| 401 | Missing/invalid access token |
| 403 | Authenticated actor lacks explicit archive/report scope |
| 404 | Record is not visible under the approved disclosure policy |
| 409 | Stale version or workflow conflict (history/correction only) |
| 503 | Authorization, database, or report dependency unavailable |

Do not change existing endpoint error identifiers as part of this read-contract increment.

## 10. Approval and implementation gates

The owner's instruction to proceed authorizes this API interface design and implementation planning. It does **not** authorize changing the live database or guessing its schema.

Required before code is enabled against a real data source:

1. Read-only schema review of `metra_observations`, station grants/assignments, audit/event storage, and the least-privilege runtime role.
2. Confirm the exact archive-read permission and its station-scope source.
3. Approve the atomic read/RPC or Npgsql transaction/locking approach, including revocation semantics.
4. Confirm whether version history exists; if absent, submit a separate schema proposal for approval.
5. Approve daily period boundaries, required fields, units and monthly/annual aggregation rules.
6. Add DB-backed integration tests in an isolated schema for station isolation, revocation races, pagination and timestamp filtering.

## 11. Current status

- API interface baseline: documented.
- Existing review queue: unchanged and still queue-only.
- Archive list/detail: not yet implemented; blocked on gates 1–3.
- Version history/correction: deferred; blocked on gate 4 and workflow approval.
- Hourly/daily/monthly/annual report calculations: deferred; blocked on gate 5.
- Flutter UI: existing screens remain unchanged; binding must follow implemented, tested API contracts.
- Database/Supabase/SQL/RLS/migrations: unchanged.
- METRA OLD: untouched.


## 12. Live schema review addendum (2026-11-11)

A read-only inspection of the selected METRA 2027 Supabase project has now been completed and recorded in `docs/backend/REPORTING-ARCHIVE-READONLY-SCHEMA-REVIEW-2026-11-11.md`.

Important correction to the initial source-only baseline:

- The imported historical archive is `public.metra_observation_records`, with **58,059 rows** and source-preserving columns (`source_system`, `source_table`, `source_record_id`, nullable `station_id`, nullable `observed_at`, `observation_type`, `payload`, `is_demo`, `imported_at`).
- It contains seven imported types: hourly, daily, climate, agricultural, fieldclimate, soil and phenomenon. There are **1,251 rows with NULL station_id** and **13 with NULL observed_at**. Station-scoped queries must not guess or expose unlinked records.
- Operational `public.metra_observations` and `public.metra_observation_audit_events` exist but each had **0 rows** at inspection time. Their current status/event columns are now schema-verified.
- The operational audit table stores workflow transition metadata, not prior payload snapshots; it does not establish a version-history API.
- The dedicated `metra_api_runtime` role has SELECT access to account state, station assignment, permission grant and station catalogue tables, but no SELECT grant or RLS SELECT policy for either observation table at inspection time. The operational migration explicitly revokes runtime access and grants only service_role.
- Observation tables have client-deny RLS policies. The backend must not solve this by exposing service-role credentials to Flutter/Angular.

Consequently, archive list/detail implementation now has a concrete source table, but remains gated on an approved least-privilege runtime SELECT migration, an explicit archive-read permission, and a single-statement/transaction station authorization predicate. The UI must distinguish imported archive envelopes from live operational observations. Scientific report calculations, version history and exports remain deferred.


## 13. Archive read implementation candidate (2026-11-11)

The Backend branch now contains:
- `GET /api/v1/stations/{stationId}/observations/archive`
- `GET /api/v1/stations/{stationId}/observations/{observationId}`
- `SupabaseObservationArchiveService`, which calls the database RPCs using the server-only service-role credential.
- UTC-only range validation, verified observation-type allow-list, limit 1–100 and offset 0–100000.
- Fail-closed 401/403/404/503 handling.
- API guard tests.

The proposed migration `20261111190000_add_station_scoped_observation_archive_read_rpcs.sql` defines a private authorization predicate and two SECURITY DEFINER RPCs. The predicate verifies active account, an approved non-expired non-revoked `observation.archive.read` user grant scoped to the station authority, an approved active station assignment, and an approved operational station. The page/detail query is executed by the same RPC after the authorization predicate and is constrained by the exact route station ID. Unlinked records and demo records are excluded. Public/anon/authenticated execution is revoked; only service_role can invoke the public RPCs. The private predicate is not directly executable by API client roles.

**No role is automatically assigned this permission.** The migration intentionally does not insert into `metra_role_permissions` and does not create user grants. This avoids granting access to station_head, station_auditor or chief_auditor before the owner confirms the intended audience. A permission grant must be issued through the existing approved permission-grant workflow.

The migration has been committed to the Backend PR branch but has **not** been applied to Supabase. It requires isolated-database migration execution and integration tests before approval for deployment. The connected production-like METRA 2027 database remains unchanged.

The Flutter PR branch now contains typed archive list/detail models, authenticated API calls, UTC/type/pagination guards, an archive list/detail screen and an entry action in the existing Reports Hub. It does not redesign the reports hub. Flutter displays authorization, empty and service-unavailable states and renders the original imported payload without calculating meteorological statistics.

### Still gated
- Apply migration only after the owner approves who may receive `observation.archive.read`.
- Run the SQL security test and DB integration tests against an isolated Supabase branch/database.
- Confirm current Backend CI and Flutter CI for the newest commits.
- Scientific hourly/daily/monthly/annual calculations, versioned payload history, Climatol and exports remain outside this archive read implementation until their domain contracts are approved.
