# METRA 2027 — Supabase Edge Function compatibility review

**Inspection date:** 2026-11-15  
**Project:** `tbdnklyxjvbrilvnwgmq`  
**Method:** read-only inspection of deployed Edge Function source and PostgreSQL catalogue. No function deployments, secret changes or database writes were performed.

## 1. Executive result

All five deployed Edge Functions are reported `ACTIVE` with `verify_jwt=true`, and each source verifies the user token with `auth.getUser`. However, all five still query the previous public-schema data model. The live project now uses normalized `iam`, `catalog`, and `observations` schemas. The table and RPC names referenced by the functions are absent from the live schema.

These functions must not be treated as operational merely because their deployment status is ACTIVE or JWT verification is enabled.

## 2. Deployed function dependency inventory

| Function | Version | Old table dependencies | Old RPC dependencies |
|---|---:|---|---|
| `station-directory` | 7 | `authority_memberships`, `metra_account_states`, `metra_role_catalogue`, `metra_role_permissions`, `permission_grants`, `station_catalogue`, `station_coordinates` | none |
| `registration` | 5 | `meteorological_authorities`, `metra_account_states`, `metra_role_catalogue`, `registration_requests`, `station_catalogue` | `submit_metra_registration` |
| `registration-approvals` | 9 | `metra_account_states`, `metra_role_catalogue`, `metra_user_profiles`, `permission_grants`, `registration_audit_events`, `registration_requests`, `station_assignments`, `station_catalogue` | `decide_metra_registration` |
| `observations` | 6 | `metra_account_states`, `metra_observations`, `station_assignments`, `station_catalogue` | `metra_decide_observation`, `metra_submit_observation`, `metra_user_has_station_permission` |
| `station-review` | 3 | `metra_account_states`, `permission_grants`, `station_catalogue`, `station_coordinates` | `decide_station_catalogue_review` |

## 3. Live model equivalents — candidates only

The live physical model includes:
- Identity/access: `iam.user_profiles`, `iam.memberships`, `iam.roles`, `iam.role_permissions`, `iam.permission_grants`, `iam.registration_requests`, `iam.registration_decisions`, `iam.role_assignments`.
- Station catalogue: `catalog.stations`, `catalog.station_locations`, `catalog.station_identifiers`, `catalog.station_reviews`, `catalog.station_operating_periods`, `catalog.station_capabilities`.
- Observation workflow: `observations.submissions`, `observations.values`, `observations.revisions`, `observations.review_decisions`, `observations.quality_flags`, `observations.attachments`.
- Audit and organizations: `audit.events`, `iam.organizations`, `iam.organization_units`.

These are candidate domain mappings, not confirmed one-to-one replacements. In particular, the new schema separates account/profile state, authority membership, station role assignment, permission grants, observation submission/value/revision/review, and station coordinate history. Do not replace old table names mechanically; map each use case to the approved ERD and enforce the correct authority/station/time scope.

## 4. Shared runtime and CORS findings

All five deployed function versions:
- Require JWT verification at the Edge gateway.
- Call `auth.getUser(token)` before proceeding.
- Read `SUPABASE_SERVICE_ROLE_KEY` and use a privileged admin client for database reads/writes.
- Set `Access-Control-Allow-Origin: *`.

JWT verification is a positive identity check, but the admin client still bypasses ordinary RLS controls. The current schema has no old data dependencies required by these functions, and the current `metra_api_runtime` role is not wired into this path. The wildcard CORS setting is broader than necessary for a production web client; replace it with an explicit approved-origin allow-list after the actual client origins are finalized. CORS is not an authorization mechanism.

## 5. Required repair sequence

1. Keep these deployed functions unchanged until a reviewed replacement plan exists; do not make live changes as part of a source-only audit.
2. Create a use-case matrix from every function action to the normalized ERD entities and required actor, authority, station, validity-period and approval predicates.
3. Design versioned .NET/API contracts and database RPCs against the new schemas. Derive the actor from a verified caller JWT and reject actor-ID spoofing.
4. Select a least-privilege runtime identity; avoid using the Supabase service-role key for routine station-scoped reads.
5. Rebuild the functions or consolidate the workflows into the .NET API, but do not leave two competing authorization implementations.
6. Add integration tests for unauthenticated requests, pending accounts, expired/revoked grants, cross-authority/station access, idempotency, audit atomicity, and malformed database responses.
7. Restrict CORS to approved origins and test browser preflight behavior.
8. Validate all changes against a disposable database replay before any hosted deployment.

## 6. Release gate

The five current Edge Functions are deployed but schema-incompatible. Registration, station directory, station review and observation workflows must remain disabled/unavailable until the replacement implementation is connected to the live greenfield model and passes integration/security tests.

No Edge Function was deployed, disabled or modified during this inspection.
