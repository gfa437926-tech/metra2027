# METRA repository consolidation audit

Date: 2026-11-10
Target repository: `gfa437926-tech/metra2027`
Source repository: `gfa437926-tech/metra-weather-intelligence2026`
Branch: `integration/repository-consolidation-audit`

## Decision

Use `metra2027` as the canonical application repository. It already contains the integrated ASP.NET Core 10 business API, Angular client, Flutter client, PostgreSQL/Supabase migration history, and CI coverage. Keep the source repository intact as an archival/reference repository until every approved transfer is verified.

This is a repository-source consolidation only. It does not authorize database connections, SQL execution, migration replay, deployment, deleting either repository, or merging any pull request.

## Evidence checked

- `metra2027` main was inspected at commit `87f71356083843b2abdef76baf011a82510686be`.
- `metra-weather-intelligence2026` main was inspected at commit `5823231a6bf6eafcb82ea9839d506be75a22f44f`.
- The source repository's draft PR #1 adds an ASP.NET Core 10 minimal API foundation. Its CI run `42710338206` passed both the `aspnet-api` and `flutter-and-supabase` jobs. This is a small identity/health API foundation, not a replacement for the business API in the target repository.
- The target repository's inspected CI runs `42702124254` and `42702124243` passed Flutter, Angular, Chromium PWA/IndexedDB, disposable PostgreSQL RLS isolation, .NET build, and API tests.
- The target repository's Flutter tree is compact and API-oriented (`mobile/metra_mobile`), while the source repository has additional weather/station domain models, weather services, station clustering, registration and station-review screens, and corresponding tests.
- Both repositories contain three identical operational-observation migration files (same path and Git blob SHA):
  - `20261103164003_create_operational_observation_submission.sql`
  - `20261103164045_deny_client_access_to_operational_observations.sql`
  - `20261103164638_index_operational_observation_foreign_keys.sql`
- The source repository contains additional migrations and six documented source-recovery gaps. These must not be copied or replayed as a batch.

## Transfer classification

### Copy now: security evidence and test plans

The source repository's security audit evidence has been copied into `docs/security/source-audits/` without rewriting its findings. These are provenance-preserving reference documents, not proof that the findings have been remediated:

- `2026-11-10-authorization-audit-followup.md`
- `2026-11-10-authorization-write-path-trace.md`
- `2026-11-04-migration-source-reconciliation.md`
- `role-authorization-negative-test-plan.md`
- `staging-acceptance-plan.md`

### Retain in target repository

- `backend/`: keep the existing ASP.NET Core 10 business API and its authorization/service implementation.
- `angular-app/`: keep the existing Angular application and its test/build pipeline.
- `mobile/metra_mobile/`: keep the existing Flutter app as the canonical integration target.
- `supabase/migrations/` and `database/`: preserve the target's current migration/schema history; no migration changes in this audit branch.
- `.github/workflows/`: preserve the existing CI checks.

### Candidate Flutter transfers: inspect and port, do not copy wholesale

Source-only Flutter areas worth porting after API-contract review:

- `lib/domain/station_record.dart`, `station_cluster.dart`, `weather_station.dart`, `weather_snapshot.dart`, `access_context.dart`
- `lib/data/station_directory_service.dart`, `weather_service.dart`
- `lib/screens/observations_page.dart`, `registration_flow.dart`, `station_review_page.dart`
- tests covering access context, registration eligibility, station clustering, station records/status, weather service/snapshot/station.

These must be adapted to the target app's `.NET API client`, authentication abstraction, routing, state management, RTL/UI conventions, and station catalogue contract. Do not introduce a second direct-to-Supabase business authorization path in Flutter. Preserve tests and port them with the adapted implementation.

### Candidate backend security transfers: selective cherry-pick/port only

The source PR #1 contains useful hardening patterns (rate limiting, strict HTTPS CORS allow-list, HSTS, security headers, JWT claim handling). Review each against the target's existing `Program.cs`, middleware order, endpoint policies, hosting requirements, and tests. Do not replace the target API with the source minimal API foundation.

### Do not transfer

- Duplicate migration files listed above.
- The source repository's full `supabase/migrations/` tree as a bulk copy.
- Supabase Edge Functions as parallel business endpoints where the target already has corresponding .NET API services.
- Source `pubspec.yaml`, app entrypoint, routing shell, or app-wide configuration wholesale; reconcile dependencies and architecture first.
- Any secrets, environment files, keys, real user data, or legacy station datasets.

## Deletion assessment

No application or migration file is approved for deletion by this audit. The target PR #12 proposes removal of 79 root-level legacy duplicates from `metra-old`; its verification report claims 79/79 Git blob matches and no references from current Angular, Backend, Flutter, database, docs, Supabase or CI trees. It is a candidate cleanup, not yet merged. Before merge, rebase/re-target it onto current `main`, re-run its dependency scan and CI, and confirm the exact 79 paths and no required archival assets. Do not delete the source repository.

## Unresolved release blockers carried forward

1. ASP.NET service-role RPC caller identity must always be derived from a verified JWT; never trust a client-supplied actor UUID.
2. Administrator permission-grant delegation ceiling and authority-level management-role assignment must be proven in the authoritative database transaction.
3. Six migration-source candidates, especially the role-permission allow-list and seed files, remain unrecovered; do not fabricate them as historical originals.
4. Authorization composition differs between some endpoints (role AND direct grant versus role OR direct grant); the policy owner must choose and document the canonical rule.
5. The 43 negative authorization scenarios and staging acceptance matrix are plans, not executed staging tests.
6. No production hosting/deployment or live staging acceptance is claimed by this consolidation.

## Implemented in the current draft PR

The following first integration slice has now been added to this branch:

- Added immutable coordinate clustering for the existing `StationDirectoryItem` model.
- Updated the existing station directory map to display a count marker for co-located stations and let the user choose a station from that cluster. Stations without valid coordinates remain in the list and are excluded only from map markers.
- Added Flutter tests for coordinate grouping, invalid/missing coordinates, record preservation, and immutability.
- Ported selected API hardening patterns from the source ASP.NET foundation: a global fixed-window rate limit of 120 requests per minute per authenticated subject (or client IP before authentication), HSTS outside Development, and defensive response headers.
- Added an API integration test asserting the defensive response headers.

These are adaptations to the existing target architecture, not wholesale copies of the source Flutter app or minimal API.

## Next controlled phases

1. Flutter source feature review is complete for the main candidate screens/services; see `docs/security/source-audits/flutter-transfer-decisions.md`.
2. Adapt the registration and observation screens to the existing .NET endpoints rather than copying Supabase Edge Function calls.
3. Continue checking the API's verified-actor binding and the database-side delegation ceiling; the current code/SQL evidence does not close those audit blockers.
4. Complete the no-write reconciliation of remaining source-only migrations and the missing tracked `metra_role_permissions` definition/allow-list source.
5. Run target CI after each code slice and keep all changes in draft PRs until review. Do not merge automatically.

## Safety record

No database was connected to or queried. No SQL was executed or applied. No legacy database or legacy repository was accessed. No deployment was performed. No repository or source file was deleted.


## Follow-up authorization trace (2026-11-10)

### Verified API actor provenance

The target ASP.NET API validates JWT issuer, audience, signature and lifetime with `MapInboundClaims = false`. The reviewed write endpoints obtain the actor UUID from the validated `sub` claim (`HttpContext.User`) and pass that server-derived UUID to the server-only Supabase service. The reviewed routes do not accept an actor UUID in their request DTOs:

- Registration submission/status: `RegistrationSubmissionEndpoints.cs`
- Observation submission/decision: `ObservationSubmissionEndpoints.cs`
- Station assignment request/decision/revocation: `StationAssignmentEndpoints.cs`
- Authority membership/permission-grant actions and audit reads: `AuthorityAccessEndpoints.cs`

The service-role credential is read from server configuration and is not sent by Flutter. This closes the API-boundary question for these inspected routes only; it does not establish that every endpoint in the repository follows the same rule.

### Database-side checks observed

- Observation decision RPC `metra_decide_observation` checks the requested user's station permission inside the same database function/transaction, locks the observation row with `FOR UPDATE`, checks the submitted state, and writes the decision plus audit event. The API also performs a preflight permission check; the database check is the authoritative transactional check.
- Station assignment request/decision RPCs constrain the assignable role set to `observer` and `station_auditor`, require the actor's `users.station.manage` permission, validate the target's active account and approved authority membership, bind the assignment to the station's owning authority, and write audit events. The decision path locks the assignment row and prevents self-approval / approval by the original requester.
- The station-bound registration decision wrapper locks the request row and compares its requested station with the route station before delegating to the transactional registration decision function.
- Registration submission uses the active-station wrapper; the API derives `p_auth_user_id` from the verified JWT subject and only the server-side service-role client calls the privileged RPC.

### Remaining authorization gaps (not closed)

1. The authority-level membership and permission-grant RPC implementations still need a line-by-line transaction review proving the maximum authority an actor may delegate, preventing self-escalation and role/permission amplification, and checking concurrent grant/revocation changes under row locks. API actor provenance alone is not proof of the delegation ceiling.
2. Observation review-queue authorization currently calls the permission RPC and then performs a separate service-role table read. The queue read is not visibly bound to the same database transaction as the permission check. Review whether a single narrowly scoped RPC should combine authorization and queue selection to remove the revocation/read TOCTOU window.
3. Station-assignment revocation must be reviewed for consistency with the full station/authority state and scheduled-revocation rules; the inspected function checks current assignment state and station permission, but does not repeat all of the request/approval path's target-account and authority-membership checks.
4. The latest source-only migration `20261110120000_honor_scheduled_permission_revocation.sql` is not part of the target migration history. It dynamically rewrites function definitions using exact string needles; compare the target's actual tracked function definitions and test the migration on a disposable schema before deciding whether to port it. Do not apply it to any hosted database during this audit.
5. No direct database connection was made, so no live schema, migration history, role grants, or deployed function definitions have been independently confirmed.

### CI confirmation on the latest audit head

Latest PR head checked: `2cd829a6da11225a5cef649db071f4e47b353173`.

- Backend workflow run `42712994936`: completed successfully; contract checks, .NET build/tests and production container build passed.
- Client workflow run `42712994757`: completed successfully; Flutter analyze/tests and Angular build passed.

This verifies the latest PR head in CI. It does not replace database-side or staging acceptance tests.


### Authority-level delegation review — additional evidence

The target migrations `020_authority_membership_and_permission_grant_lifecycle.sql`, `021_authority_permission_grant_lifecycle.sql`, `022_harden_authority_access_revocation_and_audit_index.sql`, `023_bind_authority_access_decisions_to_route_scope.sql`, and `025_require_active_subject_for_authority_approval.sql` were inspected.

- Membership and permission-grant decisions lock the target row with `FOR UPDATE`, require an active actor, reject self-review (and the original requester), bind the operation to the authority ID from the locked target row, and require an active approved authority membership plus the `authority.access.review` role permission and a separately approved, currently valid grant for the actor.
- Permission-grant approval additionally checks that the target user's active authority membership role allows the exact requested permission code before approving it. This is a database-side ceiling tied to the target role's permission allow-list.
- Membership revocation cascades revocation to active permission grants for that subject and authority, recording audit events. Permission-grant revocation is bound to the locked grant's authority and records an audit event.
- The API routes derive the actor from the verified JWT `sub`; actor IDs are not accepted from client request bodies on the reviewed authority routes.

**Why the delegation ceiling is still not fully proven:** the tracked target SQL tree references `public.metra_role_permissions` but contains no tracked `CREATE TABLE public.metra_role_permissions` definition or complete authoritative role-permission seed/allow-list. Therefore, although the transaction functions enforce a role-based ceiling, the actual contents of that ceiling cannot be verified from the repository. The missing allow-list is a release blocker, not a reason to infer or invent permissions. The live database was not queried.
