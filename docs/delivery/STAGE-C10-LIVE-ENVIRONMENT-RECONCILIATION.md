# Stage C10 — Live Environment Reconciliation

**Reviewed:** 2026-11-13  
**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `work/backend-db-integration-full-2026-11-13`  
**Baseline at report creation:** `b5e89d4e6ccb2026bf761b889ad416560d755656`  
**Supabase project inspected read-only:** `tbdnklyxjvbrilvnwgmq`  
**Change boundary:** no hosted SQL, data, grants, policies, migrations, users, or station statuses were changed.

## 1. Executive decision

The application branch now contains:
- actor-bound atomic read RPC proposals and API adapters;
- an actor-bound observation submission/decision proposal;
- a real .NET archive service and Flutter archive client;
- hourly and daily 24-hour Flutter forms connected to the .NET submission endpoint;
- server-side scientific validation and idempotent writes;
- an archive readiness probe that deliberately fails until both atomic archive RPC entry points are installed.

However, the currently configured Supabase project does **not** have the atomic read helper or the atomic read RPCs installed. Its existing observation write RPCs still use the non-locking `metra_user_has_station_permission` predicate. Consequently, hosted archive reads and write authorization are not yet production-ready.

## 2. Read-only Supabase findings

### Operational catalogue and archive

| Measure | Observed value |
|---|---:|
| Station catalogue rows | 65 |
| Approved + active + non-demo stations | **0** |
| Pending + unverified + non-demo stations | 62 |
| Pending + unverified demo stations | 3 |
| Current coordinate rows | 50 |
| Historical archive rows | 58,059 |
| Archive rows linked to a station and non-demo | 56,808 |
| Unlinked archive rows | 1,251 |
| Demo archive rows | 0 |
| Distinct archive source tables | 7 |

The archive contains records from hourly, daily, climate, soil-temperature, agricultural, field-climate, and weather-phenomena sources. The 1,251 unlinked records are intentionally not eligible for station-scoped reads.

**Operational blocker:** all 65 catalogue stations are pending/unverified; none satisfy the approved-active station predicate required by the archive authorization policy. The archive cannot be opened to a real station user until station review is completed by an authorized owner.

### Identity and authorization rows

| Relation | Rows |
|---|---:|
| `auth.users` | 0 |
| `metra_account_states` | 0 |
| `authority_memberships` | 0 |
| `station_assignments` | 0 |
| `permission_grants` | 0 |

There is no real user, approved membership, station assignment, or permission grant in this project. A real identity-provider end-to-end station authorization test cannot pass against this current data state. No user or grant was created.

### RPC installation state

The following functions were **not found** in the inspected project:
- `private.metra_lock_authorized_station_read`
- `public.get_station_user_directory_atomic`
- `public.get_station_audit_log_atomic`
- `public.get_station_observation_review_queue_atomic`
- `public.get_station_observation_archive_atomic`
- `public.get_station_observation_archive_item_atomic`

The existing `public.metra_submit_observation` and `public.metra_decide_observation` functions exist and are restricted to `service_role`, but their current definitions call `public.metra_user_has_station_permission` without locking the authorization rows. They therefore do not provide the atomic revocation semantics implemented by proposal 034.

The branch proposals `033_atomic_actor_station_read_rpcs.sql` and `034_atomic_observation_write_authorization.sql` remain unapplied to the hosted project. They have been exercised only through isolated PostgreSQL CI.

### Supabase advisors

- Security: 5 RLS-enabled tables have no policies. This is default-deny for client roles, not evidence of public exposure; confirm whether those tables are intentionally server-only before adding policies.
- Security: 2 audit trigger functions have mutable `search_path`. Both are invoker trigger functions that only raise an exception; a small hardening proposal is included separately.
- Performance: 10 foreign keys lack covering indexes; 46 indexes are currently reported unused. No index was dropped or added because the project has little operational usage and the advisor result alone is not sufficient evidence for index removal.
- Health advisor: no findings returned.

## 3. Archive implementation status

The .NET archive service is registered and calls:
- `get_station_observation_archive_atomic`
- `get_station_observation_archive_item_atomic`

The API readiness endpoint now checks the configuration and probes both RPC entry points using an all-zero actor/station pair. The expected healthy response is a database authorization denial (403); a missing function, missing helper, network error, or unexpected successful response keeps readiness closed.

This does **not** enable the archive by itself. Until the SQL proposal is approved and applied to a staging database, the archive endpoint correctly remains unavailable. After SQL installation, the current production catalogue still has zero approved-active stations and zero users/grants, so no real station user can yet retrieve records.

## 4. Scientific observation contracts

The Flutter hourly form now includes the source-derived UTC hour and the individual temperature, pressure, humidity, wind, visibility, weather, cloud-layer, cover, and precipitation fields. The daily 24-hour form includes the individual temperature, precipitation, snow, trace, evaporation, sunshine, gust, humidity-time, and weather-phenomena fields. Both submit through .NET and retain the server-side validation boundary.

Remaining scientific approvals:
1. Resolve the hourly temperature range conflict: the extracted source validator uses `-20.0..+50.0°C`, while an earlier requirements note says `-50.0..+50.0°C`.
2. Supply the authoritative psychrometric lookup table or approve a calculation method. The table was not recovered; RH/dew point must not be auto-calculated by guesswork.
3. Resolve the daily 06/18 UTC conflict: the old UI hides fields that the old validator still requires, while the old serializer drops precipitation/snow fields.
4. Run the full observation forms against staging and verify source-to-payload parity.

Daily 06/18 UTC remains disabled. Daily 24-hour and hourly submission code exists, but a real hosted/staging workflow has not been verified.

## 5. AI, Climatol, and forecast products

The repository currently contains Flutter workspace screens for AI, Climatol, and forecast-centre comparison, but no corresponding .NET API feature endpoints or real provider adapters. The UI correctly labels these capabilities unavailable/mock and does not fabricate results.

A real implementation still needs approved external contracts:
- AI: provider/model, data classes permitted to leave the METRA boundary, redaction policy, prompt/task contract, retention policy, and service credentials.
- Climatol: approved package/version and runtime, input series schema, variable metadata, reference-station selection, job resource limits, output schema, and immutable raw-series policy.
- Forecast: authoritative provider/feed, products and variables, forecast cycles, spatial/temporal resolution, update cadence, licence/redistribution rights, provenance, and fallback policy.

No provider was guessed, no secrets were created, and no mock result was re-labelled as live.

## 6. Staging and identity-provider gate

A separate Supabase branch was not created. The Supabase control plane quoted **USD 0.01344 per hour** for a branch. Creation requires explicit cost approval.

The current project has zero Auth users and no station assignments/grants. A staging run with a real IdP therefore needs:
1. approval for the quoted staging-branch cost;
2. a dedicated staging identity/test account and synthetic approved station/authority fixtures;
3. staging-only service configuration and API credentials;
4. the atomic SQL proposals applied and verified on staging;
5. Flutter/.NET end-to-end tests using a JWT issued by the real Supabase Auth service.

No production service-role key or test password is stored in the repository.

## 7. PR sequence and release boundary

- PR #34 remains open and unmerged.
- PR #36 remains open and unmerged, targeting `main`.
- PR #36 includes PR #34 as an ancestor and currently represents a much larger combined diff than the Flutter PR alone.
- Safe sequence: review/merge PR #34 first only with owner approval; then re-evaluate PR #36 against the updated `main`, review the reduced diff, and rerun all CI.
- No merge, deployment, hosted SQL, or station approval was performed.

## 8. Next execution order

1. Obtain staging branch cost approval; create isolated staging.
2. Apply proposals 033 and 034 only to staging after precheck; run archive, station-read, write, and revocation concurrency tests there.
3. Create a staging-only test user and approved synthetic station/membership/assignment/grants; test Supabase Auth JWT through the .NET API and Flutter.
4. Approve the hourly temperature range, psychrometric method/table, and daily 06/18 contract.
5. Select and provision the AI, Climatol, and forecast providers using approved data and licensing contracts.
6. Fix remaining Supabase advisor findings in reviewed migrations, then rerun advisors.
7. Review PR #34 first, then PR #36; obtain explicit merge and deployment approval.

**Release verdict: NOT PRODUCTION READY.** The branch has meaningful code and isolated-test progress, but hosted atomic RPCs, approved operational stations, identity records/grants, real providers, and staging verification remain outstanding.


## 9. Verification update — 2026-11-13

**Latest branch head:** `85a6581798371b2f8883ac367c34dfe702052359`

- Backend build: success — [run 43502605218](https://github.com/gfa437926-tech/metra2027/actions/runs/43502605218)
- Flutter C7 CI: success — [run 43502605177](https://github.com/gfa437926-tech/metra2027/actions/runs/43502605177)
- Flutter Client CI: success — [run 43502605107](https://github.com/gfa437926-tech/metra2027/actions/runs/43502605107)

The archive readiness implementation was strengthened to check the archive table through a zero-row PostgREST request, then verify both atomic archive RPCs. It treats only the RPC's explicit `station_observation_archive_forbidden` response as the expected policy denial; a service-role EXECUTE ACL denial does not mark the API ready. Unit tests cover missing table, missing RPC, unexpected success, ACL denial, and the expected actor-policy denial.

Proposal `035_harden_audit_trigger_search_paths.sql` was added and is executed in the isolated PostgreSQL CI path; its verification asserts both trigger functions pin `search_path=pg_catalog` and remain `SECURITY INVOKER`. No hosted SQL was applied.

PR #36 remains open and unmerged. The current head is mergeable/clean, but neither PR #34 nor PR #36 has review approvals or review comments. The PR sequence and owner-approval boundary remain unchanged.
