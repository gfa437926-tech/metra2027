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

1. Inspect Flutter source files individually and map dependencies/API contracts.
2. Port one vertical slice at a time (domain model + service + screen + tests) into `mobile/metra_mobile`.
3. Port backend hardening patterns only where missing and add tests.
4. Compare all non-identical migrations by content, dependency, and chronology; produce a no-write migration reconciliation report.
5. Run target CI and review the resulting draft PR. Keep all changes unmerged pending review.

## Safety record

No database was connected to or queried. No SQL was executed or applied. No legacy database or legacy repository was accessed. No deployment was performed. No repository or source file was deleted.
