# METRA 2027 — .NET API / live Supabase schema compatibility review

**Inspection date:** 2026-11-15  
**Project:** `tbdnklyxjvbrilvnwgmq`  
**Method:** source review plus read-only PostgreSQL catalogue checks. No database writes or API deployments were performed.

## 1. Executive result

The current .NET API's Supabase integration is **not compatible with the current live database schema**. The API code still targets legacy `public` table/RPC names, while the live project now uses normalized application schemas such as `catalog` and `observations`.

Verified live catalogue results:

| Expected by current API | Live project |
|---|---|
| `public.station_catalogue` | absent |
| `public.station_coordinates` | absent |
| `public.metra_observations` | absent |
| `public.metra_user_has_station_permission(uuid,uuid,text)` | absent |
| `public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)` | absent |
| `public.metra_decide_observation(uuid,uuid,uuid,text,text)` | absent |
| `public.get_station_audit_log(uuid,integer)` | absent |
| `catalog.stations` | present |
| `catalog.station_locations` | present |
| `observations.submissions` | present |

A full application-function catalogue query found only three application helper functions in the custom `private` schema (`handle_auth_user_created`, `reject_mutation`, `set_updated_at`); the expected public METRA RPCs were not present.

## 2. Source-side evidence

The .NET source still:
- Calls `/rest/v1/station_catalogue` from `SupabaseStationDirectoryService`.
- Calls public RPCs such as `metra_user_has_station_permission`, `metra_submit_observation`, and `metra_decide_observation`.
- Uses these services in `Program.cs` readiness checks and endpoint dependency registrations.

The live database instead contains the normalized catalogue and observation tables under `catalog` and `observations`. This is not a mere naming alias: the new physical model has different entities, relationships and column names.

## 3. Operational impact

- Station directory reads through the current `public.station_catalogue` path cannot succeed against the inspected schema.
- Station-scoped authorization calls fail closed because the expected permission RPC is absent.
- Observation submission and review calls cannot succeed because the expected RPCs are absent.
- The current `/api/v1/ready` endpoint probes the station directory and protected observation RPCs; it should remain unready until those contracts are restored or the API is migrated to the approved new schema.
- A green .NET build or unit-test run does not establish live database compatibility.

## 4. Required implementation path

1. Freeze any attempt to reintroduce the old `public.metra_*` tables or RPCs as a shortcut.
2. Review the live `catalog`, `iam`, `ref`, and `observations` schemas and map each required API use case to the new domain model.
3. Design a new versioned .NET persistence contract and narrow RPC/function surface for the new schemas. Bind the actor to the validated JWT subject; never trust a body-supplied user UUID.
4. Decide the Data API exposed-schema configuration and least-privilege runtime identity before implementation. Current `service_role` usage bypasses RLS and is not the desired production boundary.
5. Add isolated PostgreSQL tests for the new RPC contracts, station/authority scoping, idempotency, concurrency, and audit atomicity.
6. Implement matching .NET adapters and endpoint integration tests against the same disposable schema.
7. Only after ERD review/approval and clean replay verification, prepare hosted migrations for explicit approval.

## 5. Safety boundary

No RPCs, tables, grants, policies or Data API settings were created or changed during this review. The legacy database was not accessed. Do not restore the old public schema from archived SQL into the new project; use the reviewed greenfield domain model as the source of truth.
