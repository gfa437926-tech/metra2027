# METRA 2027 — Greenfield API persistence mapping and RPC contract blueprint

**Status:** design blueprint; not executable DDL  
**Inspection baseline:** 2026-11-15 live physical dictionary and compatibility reviews  
**Target:** the existing normalized Supabase schemas `iam`, `catalog`, `ref`, `observations`, `files`, and `audit`  
**Safety:** no hosted schema, grant, policy, secret, Edge Function, or data change is authorized by this document.

## 1. Purpose and non-negotiable boundaries

The .NET API currently calls legacy `public.station_catalogue`, `public.metra_*` tables and RPCs. Those objects are absent from the inspected live project. This blueprint maps the existing HTTP use cases to the live greenfield model; it does not restore or recreate the legacy schema.

- Keep the previous database untouched and do not migrate its records.
- Do not apply recovered historical SQL as a replay sequence.
- Do not issue DDL, grant changes, seed data, storage changes, or hosted deployments from this blueprint.
- The inspected live schema is a physical baseline, not approval of every proposed workflow.
- Never trust a user ID, organization ID, role ID, or station scope supplied in a request body as the caller's authority.
- Do not use `service_role` for ordinary user-scoped API reads or writes. It bypasses RLS.
- Flutter communicates only with the authenticated .NET API; it never receives database credentials.

## 2. Physical domain mapping

| API/domain capability | Existing greenfield objects | Required mapping / invariant |
|---|---|---|
| Station directory | `catalog.stations`, `catalog.station_types`, `catalog.station_locations`, `catalog.station_identifiers` | Station ID is stable UUID; code is `station_code`; WMO identity is `wmo_identifier` or a valid `station_identifiers` row; names are `name_ar/name_en`; type joins by `station_type_id`; current location is selected by validity interval (`valid_to IS NULL`) and must not multiply stations. |
| Identity/profile | `auth.users`, `iam.user_profiles` | Auth subject is `user_profiles.user_id`; profile state must be active; identity is derived from validated JWT subject. |
| Organization scope | `iam.organizations`, `iam.organization_units`, `iam.memberships` | Membership must be active and within `valid_from/valid_to`; organization must be active; organization/unit scope must match station owner. |
| Role authorization | `iam.roles`, `iam.role_assignments`, `iam.role_permissions`, `iam.permissions` | Active role assignment + active membership + valid scope + role permission are all required. Station scope must match exact station; global/organization/unit scope must be evaluated deliberately. |
| Direct permission grants | `iam.permission_grants`, `iam.permissions` | Grant must be active, in its validity interval and scoped to the same organization/station. Define whether direct grants supplement or override role-derived permissions; deny by default. |
| Registration | `iam.registration_requests`, `iam.registration_decisions`, `iam.user_profiles`, `iam.roles`, `catalog.stations` | Derive organization from the selected station's owner; verify requested role is active/requestable; store applicant from JWT; idempotency key unique per applicant/operation; preserve decision history. |
| Observation header | `observations.submissions`, `ref.observation_types`, `catalog.stations`, `iam.user_profiles` | Use observation type ID, station ID, JWT author, UTC instant, state, revision number and idempotency key. |
| Observation values | `observations.values`, `ref.parameters`, `ref.units` | Each value references a parameter and its exact value kind; populate exactly one typed value column; preserve unit and sequence; enforce parameter active/version and unit compatibility. |
| Observation review | `observations.review_decisions`, `observations.revisions`, `observations.quality_flags` | Reviewer comes from JWT; review decision, state transition, revision snapshot and audit event commit atomically; stale revision decisions are rejected. |
| Attachments | `observations.attachments`, `files.objects` | Attachment points to a private file object; object authorization is checked per request; no public bucket or long-lived public URL. |
| Audit | `audit.events` | Append-only event with actor, action, entity, organization/station scope, outcome and correlation ID; no application update/delete path. |
| Equipment/operations | `operations` tables and station FK | Use the station's organization scope and actor authorization; no legacy station identifiers. |

### 2.1 Station directory projection

The live station table does not have the legacy `local_station_code`, `station_type`, `is_demo`, or nested `station_coordinates` fields. Do not keep the current PostgREST query and rename fields mechanically.

A new projection should:
1. Read `catalog.stations` and join `catalog.station_types`.
2. Join only the current `catalog.station_locations` row for each station (validity interval, not just an unqualified join).
3. Apply explicit policy for `approval_status = 'approved'` and allowed `operational_status` values; keep planned/closed stations out of operational pickers unless a caller has catalogue-review permission.
4. Expose station type code and localized names, station code, WMO identifier, elevation, timezone, coordinates, coordinate source and accuracy.
5. Use keyset pagination for a large catalogue, stable ordering and a bounded page size.
6. Do not invent a demo flag. If demo/test records need exclusion, define an approved provenance rule using existing catalogue metadata or a separately reviewed field.

## 3. Versioned server-side operation contracts

The names below are proposed logical operation IDs, not deployed function names. Before implementation, decide whether these live in an exposed `api` schema or are called through a dedicated .NET database connection. No function currently exists merely because it is listed here.

| Logical operation | Input (caller-derived values marked) | Atomic effects / output |
|---|---|---|
| `stations.directory.v1` | filters, cursor, page size; caller from JWT | Approved station projection and current location; read-only. |
| `iam.station-permission.v1` | station ID, permission code; actor from JWT | Boolean + reason code; evaluate profile, organization, membership, role assignment, direct grants, validity and exact station scope. |
| `iam.registration-submit.v1` | requested station, role, terms version, idempotency key; applicant from JWT | Insert registration request after deriving organization from station; replay returns original request; same key/different payload conflicts. |
| `iam.registration-decide.v1` | request ID, decision, reason, expected state/version; reviewer from JWT | Lock request, authorize reviewer, write decision, update request/membership/assignment as approved policy dictates, append audit atomically. |
| `observations.submit.v1` | station, observation type, observed-at, typed values, idempotency key; author from JWT | Authorize station, validate reference catalog/value kinds/units, insert submission and values, initial revision and audit atomically. |
| `observations.review.v1` | submission ID, decision, reason, expected revision; reviewer from JWT | Lock submission; authorize reviewer distinct from author where policy requires; write decision, update state, revision/quality flags and audit atomically. |
| `observations.queue.v1` | station, state filter, cursor, page size; actor from JWT | Return only submissions visible under exact station/organization scope. |
| `observations.archive.v1` | station, UTC range, observation type, cursor; actor from JWT | Bounded, indexed read of approved/authorized records; enforce range and row limits. |
| `audit.station-events.v1` | station, time range, cursor; actor from JWT | Read-only audit projection after station audit permission check. |
| `iam.station-users.v1` | station, cursor, page size; actor from JWT | Profiles and active assignments for exactly that station; never enumerate users outside scope. |
| `iam.station-assignment.v1` | target user, station, role/permission, validity, reason, expected version; assigning actor from JWT | Enforce grant authority/dual control; insert/revoke assignment and audit atomically. |

Every write operation must:
- Derive actor identity from validated JWT claims at the database trust boundary; ignore body actor IDs.
- Validate organization/station consistency with composite relationships and explicit authorization.
- Use idempotency uniqueness scoped to actor + operation + resource.
- Use transaction locks or optimistic version checks to prevent duplicate/conflicting transitions.
- Append audit in the same transaction as the business mutation.
- Return stable machine-readable error codes without leaking whether an unauthorized resource exists.
- Have isolated PostgreSQL tests for success, replay, key/payload conflict, stale state, cross-organization, cross-station, revoked/expired access, malformed inputs and audit rollback.

## 4. Runtime identity decision required before adapter implementation

The live inspection found `service_role` has `BYPASSRLS`; the existing `metra_api_runtime` role is `NOLOGIN`, `NOBYPASSRLS` and has no required function grants. It is not yet a usable runtime identity.

Preferred direction for review:
- .NET validates the Supabase access token and forwards the caller's user JWT to narrowly scoped server-side operations; never substitute the service-role token for the caller.
- The database operation obtains actor identity from `auth.uid()` (or a formally documented equivalent verified-claims boundary) and performs all scope checks.
- If `SECURITY DEFINER` functions are required to access protected tables, each must use a fixed safe `search_path`, schema-qualified references, explicit authorization predicates, bounded inputs, and a narrowly owned function role; revoke default PUBLIC execute and grant only the intended caller role.
- Alternatively, use a dedicated least-privilege .NET database identity with a documented transaction-local verified-subject mechanism. Do not grant `BYPASSRLS`, broad table CRUD, or membership in `service_role`.
- Confirm Supabase Data API exposed schemas and function visibility before choosing the PostgREST route.
- CORS allow-list is separate from authorization and must match approved client origins.

This is a design recommendation only. The exact runtime identity, function security mode, exposed schema and grants remain open until security review and disposable-database integration tests pass.

## 5. .NET adapter refactor sequence

1. Add typed persistence interfaces for station catalogue, identity/authorization, registration, observations, review, archive and audit.
2. Introduce versioned DTOs that reflect the greenfield domain; do not leak raw PostgREST JSON to Flutter.
3. Implement new adapters behind feature gates; keep legacy adapters unreachable in production configuration.
4. Forward caller JWT to the approved least-privilege operation boundary. Remove routine `Supabase:ServiceRoleKey` use from user-scoped operations.
5. Add integration tests using the canonical disposable schema and a non-privileged test identity.
6. Verify `/api/v1/ready` exercises the new contract and fails closed on missing schema/grants.
7. Switch Flutter repositories only after API integration tests pass; keep affected screens visibly unavailable while dependencies are not ready.

## 6. Explicit gaps not represented by the live physical schema

The inspected 46-table model does not yet include recorder capture/image/trace lifecycle, climate homogenization and adjustment lineage, or AI dataset/experiment/model-registry domains. Those features require separately reviewed schema extensions and private object/job infrastructure. Do not simulate persisted functionality with in-memory placeholders or treat UI screens as operational.

## 7. Acceptance gates

- [ ] Logical ERD and this mapping reviewed and approved.
- [ ] Canonical 86-migration history curated and replayed on a disposable empty PostgreSQL database.
- [ ] Replay schema compared to the live physical dictionary; no destructive or historical context-dependent SQL replayed blindly.
- [ ] Runtime identity and exposed-schema decision approved.
- [ ] Versioned RPC/SQL contract designed with fixed search paths and least privilege.
- [ ] Isolated integration/security tests pass under the exact runtime identity.
- [ ] .NET adapters and readiness probe pass against that isolated schema.
- [ ] Flutter role/station workflows pass integration tests against the new API.
- [ ] Hosted migration and deployment separately approved; old database remains untouched.

**Current status:** mapping blueprint added; no executable DDL, live database write, deployment, or legacy database access performed.

## 8. CI evidence scope — do not over-interpret green checks

The current workflow suite contains isolated PostgreSQL jobs for the repository's Path N baseline and transfer-pack fixtures. The Path N restore test explicitly builds `public.station_catalogue`, `public.metra_role_catalogue`, `public.metra_observations` and the corresponding legacy RPCs. The transfer-pack end-to-end tests use synthetic fixture schemas. These jobs are useful regression evidence for those paths, but they do **not** prove that the normalized live greenfield model in `iam`, `catalog`, `ref`, and `observations` can be recreated from source or that the current .NET API is compatible with it.

A separate greenfield schema build job must be added only after the canonical greenfield migration sequence is reviewed and approved. It must start from an empty disposable PostgreSQL database, apply only the curated greenfield migrations, assert the expected normalized entities and constraints, and run the new .NET adapter integration/security tests under the selected least-privilege identity. Until then, a green CI result must not be reported as greenfield database readiness.

## 9. Live greenfield database inspection — read-only snapshot (2026-11-15)

This section records a fresh read-only inspection of Supabase project `tbdnklyxjvbrilvnwgmq`. It is operational evidence, not approval to alter the schema.

### 9.1 Migration and table inventory

- Supabase migration history reports **86 applied migration records**.
- The inspected domain schemas contain the expected greenfield table families across `iam`, `catalog`, `ref`, `observations`, `files`, `audit`, `operations`, `weather`, `alerts` and `integration`.
- RLS is enabled on every table returned by this inspection.
- Reference catalogue rows observed: 10 roles, 27 permissions, 78 role-permission links, 7 station types and 3 observation types.
- Operational identity, organization, membership, station, observation, file, audit, weather, alert, equipment and integration tables were empty at inspection time. In particular, no station rows or user profiles were present. Do not mistake reference catalogue seed rows for operational readiness.

### 9.2 Security advisor findings

The Supabase Security Advisor reported **21** `rls_enabled_no_policy` findings:

- `alerts.alert_rules`
- `catalog.station_capabilities`
- `catalog.station_identifiers`
- `catalog.station_operating_periods`
- `files.objects`
- `iam.access_reviews`
- `integration.execution_runs`
- `integration.sources`
- `observations.attachments`
- `observations.quality_flags`
- `operations.equipment`
- `operations.equipment_fault_events`
- `operations.equipment_faults`
- `operations.support_incident_events`
- `operations.support_incidents`
- `weather.forecast_parameter_mappings`
- `weather.forecast_points`
- `weather.forecast_runs`
- `weather.ingestion_runs`
- `weather.provider_payload_references`
- `weather.providers`

RLS enabled with no policies is a deny-by-default posture for ordinary table access; it is not permission to add broad policies. Each table needs an explicit access decision: private backend-only, authenticated read, scoped write, or controlled access through a narrowly authorized server operation. Views, functions, grants and storage access must be reviewed together. Do not add `USING (true)`, blanket `TO authenticated` policies, or policies based only on user-editable metadata.

### 9.3 Performance and health advisor findings

- Performance Advisor reported **76** unused-index informational findings. These are not grounds for automatic index removal: the project has no operational station/observation workload yet, so the indexes may be required for the planned query paths and foreign-key enforcement.
- Health Advisor returned no lints in this inspection.
- No advisor remediation, DDL, grants, policy changes, seed inserts, storage changes or data writes were performed.

### 9.4 Required review before any access enablement

For each of the 21 tables, the schema review must identify the intended actor classes, organization/station scope, read and write operations, audit requirements, and whether the table must remain inaccessible through the Data API. Then implement and test least-privilege policies or private server operations in a disposable PostgreSQL environment. Re-run security advisors and cross-tenant/cross-station negative tests before any hosted deployment. The current service-role-based legacy .NET adapters must not be treated as a substitute for this review.
