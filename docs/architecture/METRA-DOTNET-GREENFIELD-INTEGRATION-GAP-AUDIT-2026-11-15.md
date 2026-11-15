# METRA .NET API — Greenfield Integration Gap Audit

**Inspection date:** 2026-11-15  
**Audited branch:** `work/metra-all-workspaces-ui-2026-11-15`  
**Database target:** New normalized METRA schemas (`iam`, `catalog`, `ref`, `observations`, `files`, `audit`, `weather`, `alerts`, `operations`, `integration`)  
**Status:** Evidence-backed gap inventory; no database or production changes.

## 1. Executive finding

The current ASP.NET Core API compiles and its existing tests pass, but its persistence adapters still target the earlier `public.*` model and its RPC vocabulary. The inspected new database inventory contains the normalized greenfield schemas and does not show the legacy public tables used by these adapters. Therefore the current API is **not greenfield-integrated** and must not be deployed as if its operational endpoints are ready against the new database.

The current adapter pattern also uses `Supabase:ServiceRoleKey` for directory reads and RPC calls. The key remains server-side (not in Flutter), but service-role access bypasses ordinary RLS enforcement. Actor IDs passed as RPC parameters are safe only if each database function independently derives/validates authority against trusted records and performs all scope checks. This legacy implementation is not a substitute for the greenfield JWT/RLS and least-privilege design.

## 2. Observed adapter-to-schema mismatches

| API area | Current code target | Greenfield logical target | Status |
|---|---|---|---|
| Station directory | `public.station_catalogue`, joined `station_coordinates` | `catalog.stations`, `catalog.station_types`, `catalog.station_locations`, `catalog.station_identifiers`, `catalog.station_capabilities`, `catalog.station_operating_periods` | Not mapped |
| Station catalogue review | `public.decide_station_catalogue_review` | `catalog.station_reviews` plus audited catalogue transition operation | Not mapped |
| User registration submission | `public.metra_role_catalogue`, `get_metra_registration_status`, `submit_metra_registration_for_active_station` | `iam.registration_requests`, `iam.registration_decisions`, `iam.roles`, `iam.memberships` | Not mapped |
| Registration review | `get_station_registration_queue`, `get_station_system_registration_queue`, `decide_metra_registration_for_station` | `iam.registration_requests`, `iam.registration_decisions`, memberships and scoped reviewer permissions | Not mapped |
| Station assignment | `public.metra_role_catalogue`, `request_station_assignment`, `decide_station_assignment`, `revoke_station_assignment` | `iam.memberships`, `iam.role_assignments`, `iam.roles`, `iam.permission_grants` | Not mapped |
| Authority access | `request_authority_membership`, `decide_authority_membership`, `revoke_authority_membership`, authority-specific RPC family | `iam.organizations`, `iam.organization_units`, `iam.memberships`, `iam.role_assignments`, `iam.permission_grants`, `iam.access_reviews` | Not mapped |
| Station users | `get_station_user_directory_atomic` | `auth.users`, `iam.user_profiles`, memberships and scoped role assignments | Not mapped |
| Station audit | `get_station_audit_log_atomic` | `audit.events` with an authorized station-scoped projection | Not mapped |
| Observation submit | `metra_submit_observation` | `observations.submissions`, `observations.values`, `ref.observation_types`, `ref.parameters`, `ref.units` | Not mapped |
| Observation decision | `metra_decide_observation` | `observations.review_decisions`, `observations.revisions`, `observations.quality_flags` | Not mapped |
| Observation queue | `get_station_observation_review_queue_atomic` | Scoped projection over `observations.submissions`, review decisions and IAM scope | Not mapped |
| Observation archive | `public.metra_observation_records`, `get_station_observation_archive_atomic`, `get_station_observation_archive_item_atomic` | Authorized archive projection over `observations.submissions`, values, revisions, decisions and attachments | Not mapped |
| Attachments | No verified greenfield object adapter in the inspected endpoints | `observations.attachments`, private `files.objects` storage metadata | Not implemented |

This table is a mapping audit, not a claim that every logical target must be exposed as a direct table query. Most write and sensitive read workflows should be implemented as narrow server operations or carefully scoped projections.

## 3. Authentication and authorization findings

### Existing strengths

- JWT Bearer validation checks issuer, audience, signature, lifetime and only allows RS256/ES256.
- The API derives actor identity from the validated `sub` claim in the inspected operational endpoints.
- Rate limiting, bounded Supabase HTTP client timeouts, security response headers and fail-closed HTTP error mapping are present.
- The service-role key is read from server configuration and is not embedded in Flutter or committed appsettings.
- Sensitive operations use RPCs instead of exposing arbitrary client-side table writes.

### Greenfield blockers

1. A service-role bearer token bypasses ordinary RLS. The greenfield implementation must use caller JWT propagation for user-scoped reads/writes wherever possible, or a narrowly privileged operation with explicit authorization and audited ownership.
2. A request parameter such as `p_actor_user_id` is not proof of identity. A privileged RPC must independently bind it to a validated JWT identity or be called only through a server boundary that cannot be spoofed.
3. The normalized IAM permission model must be the single authority for organization/station scope; legacy role-code allow-lists cannot be carried over without a reviewed mapping.
4. Every child-resource read (attachments, quality flags, event rows) must re-check authorization against its parent station/organization.
5. The 21 tables with RLS enabled and no direct policies must remain closed until each has an approved access decision. Private backend-only tables may intentionally have no client policy.
6. The API must never trust caller-supplied organization, station ownership, role, reviewer, uploader or audit actor values.

## 4. Readiness semantics

The current `GET /api/v1/ready` probes the old station catalogue and old archive/write RPC entry points. A green response only means those legacy contracts answered the probes. It does **not** prove that the normalized greenfield schema, greenfield IAM policies, or new API adapters are ready.

Until the greenfield adapters and isolated replay suite exist:
- Treat current readiness as legacy-contract readiness only.
- Do not use a successful legacy probe as a greenfield deployment gate.
- A greenfield deployment gate must probe the exact new schema version, required operation contracts, least-privilege database role, and negative authorization cases without creating business data.

## 5. Required implementation sequence

### Phase A — freeze and specify contracts

1. Approve the ERD and data dictionary for the new schema.
2. Approve the table-by-table RLS matrix.
3. Finalize versioned operation contracts for station directory, registration, station assignment, authority access, observation submit/review/queue/archive, file metadata and audit projections.
4. Define actor identity, organization/station scope, permission code, idempotency, concurrency and audit semantics for each operation.
5. Mark legacy public-table adapters as legacy-only; do not silently redirect their SQL/RPC names.

### Phase B — isolated database and security tests

1. Build a disposable PostgreSQL database from the canonical approved greenfield migrations.
2. Verify migration replay from empty database and deterministic reference data.
3. Create least-privilege runtime roles and narrowly scoped functions only after review.
4. Test anonymous, unauthorized, cross-organization, cross-station, expired membership/grant, suspended account, self-approval, stale state and duplicate idempotency cases.
5. Test direct PostgREST access separately from API calls.
6. Run Security Advisor and verify no unintended public/Data API access.

### Phase C — .NET greenfield adapters

Implement typed interfaces and dedicated adapters for:
- `catalog` station directory and review
- `iam` registration, membership, role assignment, permission grant and authority access
- `observations` submit, review, queue, archive and quality flags
- private file metadata and signed object access
- station-scoped audit projection

Use caller JWT/RLS for ordinary user operations. Where a privileged server operation is justified, bind the actor to validated identity, enforce scope inside the database transaction, use fixed `search_path`, revoke PUBLIC execute, grant only to the intended role, and append audit atomically.

### Phase D — end-to-end validation

1. Add contract tests for each adapter against the disposable database.
2. Add API integration tests with real JWT claims and two organizations/two stations.
3. Add Flutter integration tests for approved, pending, denied and expired access states.
4. Add greenfield replay and authorization jobs to CI; retain the existing legacy/synthetic fixture tests but label their scope.
5. Deploy only after approved migrations, policy tests, adapter tests, secret management, HTTPS, CORS and monitoring are verified.

## 6. Release decision

**Current decision: NOT GREENFIELD READY.**

The UI catalogue and numerous request guards/domain policies exist, but the .NET persistence boundary is still legacy-shaped. Do not enable operational Flutter workflows, mark the API ready for the new schema, or claim production deployment until Phases A–D are completed. No DDL, grants, RLS policies, data writes, storage changes or production deployment were performed by this audit.

## 7. Concrete live-schema column mapping notes

A second read-only verbose table inspection confirmed the following actual columns. These are the live schema names, not proposed aliases.

### Station directory projection

- `catalog.stations`: `id`, `owner_organization_id`, `station_type_id`, `station_code`, `name_ar`, `name_en`, `wmo_identifier`, `approval_status`, `operational_status`, `elevation_m`, `timezone_name`, `opened_on`, `closed_on`.
- `catalog.station_types`: `id`, `type_code`, `name_ar`, `name_en`, `is_active`.
- `catalog.station_locations`: `station_id`, `latitude`, `longitude`, `elevation_m`, `timezone_name`, `location_source`, `source_reference`, `horizontal_accuracy_m`, `valid_from`, `valid_to`.
- `catalog.station_identifiers`: `station_id`, `identifier_scheme`, `identifier_value`, `valid_from`, `valid_to`.

Required transformation: join station type by `station_type_id`; select the location valid at the requested observation time (or current location for the directory); project identifier schemes explicitly. The old adapter's `station_type` string and `station_coordinates` nested relation are not direct matches. Do not infer approval from `operational_status`, or operational readiness from approval alone.

### IAM and registration

- `iam.user_profiles`: `user_id`, `email`, `display_name`, `given_name`, `family_name`, `father_name`, `phone_e164`, `preferred_locale`, `timezone_name`, `profile_state`.
- `iam.memberships`: `user_id`, `organization_id`, `unit_id`, `membership_state`, `valid_from`, `valid_to`, `approved_at`, `approved_by`.
- `iam.roles`: `role_code`, `is_assignable`, `is_requestable`, `role_state`; it is not the legacy `public.metra_role_catalogue`.
- `iam.role_assignments`: `membership_id`, `organization_id`, `unit_id`, `station_id`, `role_id`, `scope_type`, `assignment_state`, validity interval.
- `iam.permissions`: `permission_code`, `permission_domain`; `iam.role_permissions` maps roles to permissions.
- `iam.permission_grants`: user, permission, organization/unit/station scope, `scope_type`, `grant_state`, validity interval, `granted_by`, reason.
- `iam.registration_requests`: `applicant_user_id`, `organization_id`, `requested_unit_id`, `requested_station_id`, `requested_role_id`, `request_state`, `terms_version`, `idempotency_key`.
- `iam.registration_decisions`: `request_id`, `stage`, `decision_sequence`, `reviewer_user_id`, `decision`, `reason`, `decided_at`.

Required transformation: resolve role codes to `iam.roles.id`, and resolve organization/unit/station scope before creating a registration request. Registration decisions are staged and sequenced, not a single legacy status transition. Membership, role assignment and explicit permission grant are distinct records and must not be collapsed into one role field.

### Scientific observations

- `ref.observation_types`: `type_code`, `schema_version`, `cadence_code`, `is_active`.
- `ref.parameters`: `parameter_code`, `value_kind` (database check allows `decimal`, `integer`, `text`, `boolean`), `canonical_unit_id`, `precision_scale` (nullable, otherwise 0–12), `definition_version`, `is_active`.
- `ref.units`: `unit_code`, `symbol`, `dimension_code`, bilingual names and `is_active`.
- `observations.submissions`: `station_id`, `author_user_id`, `observation_type_id`, `observed_at`, `timezone_name`, `submission_state`, `revision_number`, `idempotency_key`, `submitted_at`.
- `observations.values`: `submission_id`, `parameter_id`, `value_kind`, typed value columns (`value_decimal`, `value_integer`, `value_text`, `value_boolean`), `unit_id`, `sequence_number`, `quality_state`.
- `observations.revisions`: immutable revision snapshot and reason.
- `observations.review_decisions`: reviewer, decision, reason and decision time.
- `observations.attachments`: submission-to-file relation; `files.objects` stores private object metadata, SHA-256, classification and object lifecycle state.

Required transformation: the existing API's generic JSON payload cannot be copied directly into a single greenfield column because the new schema is typed/EAV. A versioned observation schema must map each accepted parameter code to its reference parameter, value kind, canonical unit and validation rules, then atomically persist header, typed values, revision/audit and idempotency result. Reject unknown parameters, kind mismatch, unit-dimension mismatch and duplicate parameter/sequence keys. Keep the original validated payload only as a versioned revision snapshot if the approved retention model requires it.

### Audit

- `audit.events` is an append-oriented event record with `actor_user_id`, `action_code`, `entity_schema`, `entity_table`, `entity_id`, organization/station scope, `outcome`, `correlation_id` and structured metadata.
- It is not a drop-in match for legacy station-specific audit RPC result rows. A new projection must filter by exact station/organization scope and expose only approved metadata keys.

### Data readiness note

The verbose schema inspection confirmed that operational tables are empty at inspection time, while reference catalogues have seeded rows. This means adapter contract tests must create isolated synthetic organizations, memberships, stations, assignments and observations in a disposable database; tests must not rely on production-like records already existing in the hosted project.

## 8. First executable greenfield domain component

Added a database-independent typed value mapper:
- `backend/Metra.Api/Domain/Observations/GreenfieldObservationValueMapper.cs`
- `backend/Metra.Api.Tests/Domain/GreenfieldObservationValueMapperTests.cs`

The mapper accepts a server-loaded parameter/unit catalogue and a strict JSON array, then produces the normalized `observations.values` typed row shape. It enforces active parameter/unit definitions, supported typed value kinds, decimal scale, integer range/type, text bounds/control-character rejection, boolean type, sequence bounds, duplicate parameter/sequence rejection, and canonical-unit identity. It rejects alternate units rather than silently storing an unconverted magnitude because the inspected schema does not yet define a conversion graph.

This is a pure domain component and test seam only. It is **not wired to an endpoint or database adapter**, does not resolve catalogue data, does not persist observations, and does not make observation submission live. The API adapter still needs an approved schema-versioned payload contract, catalogue repository, unit-conversion policy, authorization boundary, idempotent transaction and audit operation.

### Mapper/schema alignment correction

The live database check constraint on `ref.parameters.precision_scale` permits null or values from 0 through 12. The mapper and its catalogue validation now enforce that exact bound (not a generic .NET decimal maximum). This constraint was confirmed from the live schema metadata in a read-only inspection; no database mutation was required.


## 8. Follow-up containment — legacy station directory fail-closed

- The legacy `SupabaseStationDirectoryService` still queries `public.station_catalogue` and authenticates PostgREST with the server-side `service_role` key. This is not a greenfield adapter and bypasses RLS.
- The adapter now reports itself unconfigured unless `Features:LegacyStationDirectoryEnabled=true` is explicitly supplied. Credentials alone no longer activate the legacy query, so the station endpoint returns its existing 503 unavailable response by default.
- Added regression tests for the default-off behavior and the explicit compatibility opt-in.
- The opt-in is intended only for a deliberately isolated legacy compatibility environment; it must not be enabled against the new greenfield project. The correct production implementation remains a typed `catalog.*` projection through the approved caller-scoped least-privilege boundary.
- No database schema, grants, RLS policies, records, credentials or deployment settings were changed by this code update. The new behavior must pass exact-head Backend CI before it is treated as validated.


### Station catalogue review containment

- The existing `SupabaseStationCatalogueReviewService` invokes the legacy `decide_station_catalogue_review` RPC using the server `service_role` credential. It is not a greenfield `catalog.*` review adapter and the supplied actor UUID does not, by itself, make a privileged RPC caller-scoped.
- The service now requires the separate `Features:LegacyStationCatalogueReviewEnabled=true` compatibility flag. Credentials alone no longer make the legacy review RPC available.
- Regression tests cover both default-off behavior and explicit opt-in. Do not enable this flag against the greenfield project; implement the reviewed catalog/IAM authorization contract before enabling station review in production.
- This containment change does not alter the hosted database or existing records.
