# METRA 2027 — Stage B Report (Domain, API contracts, OpenAPI, authz tests)

**Branch:** `work/backend-db-integration-phase`  
**Date:** 2026-11-11  

## Decisions applied

1. Archive read = **explicit per-station grant only** (`observation.archive.read`).
2. OpenAPI inventory documented; Development `MapOpenApi` retained.
3. Migration proposal file only — **not applied** to hosted Supabase.

## Changes

### Domain
- `ObservationPermission.ArchiveRead` added.
- `ObservationArchiveAuthorizationPolicy.AuthorizeArchiveRead` enforces:
  - authenticated user
  - active station assignment
  - exact station match
  - explicit ArchiveRead permission
  - denies cross-station (same-authority scenario)

### API
- `GET /api/v1/stations/{stationId}/observation-archive`
  - JWT + station permission RPC check for `observation.archive.read`
  - Domain policy double-check
  - Default service: `UnconfiguredObservationArchiveService` → **503**, no fake data

### Tests
- Extended `ObservationAuthorizationPolicyTests` with archive allow/deny cases including cross-station denial.

### Database
- `database/migrations/023_observation_archive_read_permission_proposal.sql`  
  Proposal only (`SELECT` status marker). No hosted apply.

### Docs
- `docs/api/OPENAPI-INVENTORY-STAGE-B.md`
- This report

## What was NOT done (by design)

- No Angular work
- No hosted Supabase migration/RLS/RPC/grant writes
- No removal of Flutter mocks (Stage E gate)
- No invented scientific validation bounds
- No claim that archive returns real historical rows yet

## Test execution note

This sandbox may not have the .NET 10 SDK available for a live `dotnet test` run. Tests are written in the existing xUnit style and should be executed in CI / a .NET 10 environment:

```bash
dotnet test backend/Metra.Api.Tests/Metra.Api.Tests.csproj -c Release
```

## Readiness for Stage C

- Archive permission policy is encoded and tested at domain level.
- Migration proposal is isolated and non-destructive.
- Stage C can design isolated PostgreSQL verification scripts for grant evaluation without touching hosted project.

## Residual gaps

1. Wire real archive read-model after isolated tests + your approval for hosted apply.
2. Full OpenAPI document generation artifact in CI (optional enhancement).
3. Flutter binding remains Stage E.
4. Scientific field rules beyond existing validators still blocked on source authority.
