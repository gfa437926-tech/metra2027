# METRA 2027 — Stage D Security Audit Report

**Branch:** `work/backend-db-integration-phase`  
**Date:** 2026-11-11  
**Scope:** Backend (.NET), Domain policies, isolated PostgreSQL authorization predicates, API surface  
**Out of scope:** Hosted Supabase writes, Flutter mock removal, Angular, PR merge  

## 1. Authentication & JWT

| Control | Finding | Severity |
|---------|---------|----------|
| Fallback authorization policy requires authenticated user | Present in `Program.cs` | OK |
| JWT Bearer: ValidateIssuer, ValidateAudience, ValidateLifetime, ValidateIssuerSigningKey | Present | OK |
| `RequireHttpsMetadata = true` | Present | OK |
| `MapInboundClaims = false`; `NameClaimType = sub` | Present | OK |
| ClockSkew 60s | Present | OK |
| Health/Ready anonymous | Explicit `.AllowAnonymous()` | OK |
| Service role key in committed `appsettings.json` | **Not present** (empty of secrets) | OK |
| Service role used only server-side via config + HttpClient | Pattern consistent across features | OK |
| All Supabase HttpClients timeout 8s | Covered by `ApiAuthenticationTests` | OK |

**Risk residual:** Live JWT signature validation against real Supabase JWKS not re-executed in this sandbox (no .NET host run this session). Existing test project uses `WebApplicationFactory` patterns for health/ready.

## 2. Authorization model

### Station-scoped permissions
- RPC-style evaluation via `IStationAuthorizationService.HasStationPermissionAsync` → Supabase RPC `metra_user_has_station_permission` (production path).
- Domain `ObservationAuthorizationPolicy` enforces assignment match + permission set + owner checks for edit/submit.

### ArchiveRead (approved policy)
| Layer | Enforcement |
|-------|-------------|
| Domain | `ObservationArchiveAuthorizationPolicy.AuthorizeArchiveRead` — explicit `ArchiveRead`, station match, active assignment |
| API | `GET .../observation-archive` → `HasStationPermissionAsync(..., "observation.archive.read")` + domain double-check + **503** if service unconfigured |
| SQL (isolated) | Grant row must include **`permission.station_id = requested station`**; role allow-list + membership + assignment + active account |

**Consistency:** Domain, API route policy text, and isolated SQL all implement **per-station explicit grant**. No authority-wide archive grant in these layers.

## 3. Negative test results (re-run Stage D)

### Domain (xUnit source — executed in CI when SDK available)
Covered in `ObservationAuthorizationPolicyTests`:
- allow with ArchiveRead on matching station  
- deny review/approve without ArchiveRead  
- deny other station  
- deny unauthenticated  
- deny inactive assignment  

### Isolated PostgreSQL (live this session — PG 16.15)

```
PASS: observer archive A allowed
PASS: observer archive B denied (same authority)
PASS: role-only archive denied
PASS: revoked grant denies archive A
PASS: expired assignment denies archive
PASS: audit update blocked
PASS: audit delete blocked
ALL ARCHIVE ISOLATION TESTS PASSED
```

| Scenario | Domain | SQL isolated | API |
|----------|--------|--------------|-----|
| Archive A with grant | allow | allow | would 503 after authz if service off (fail-closed data) |
| Archive B same authority | deny | deny | 403 expected before service |
| Role only | deny | deny | 403 |
| Revoked grant | (domain N/A) | deny | 403 via RPC |
| Expired assignment | deny inactive | deny | 403 |
| Unauthenticated | deny | N/A | 401 via FallbackPolicy + RequireAuthorization |
| stationId swap | deny | deny | path stationId checked |

API 401/403 against full JWT host were **not** re-run in this sandbox (no `dotnet test` SDK). Documented as residual verification for CI.

## 4. Audit log integrity

| Store | Protection observed |
|-------|---------------------|
| `metra_observation_audit_events` (supabase migration) | Trigger rejects UPDATE/DELETE |
| Isolated `permission_grant_audit` | Trigger rejects UPDATE/DELETE — **verified live** |
| Station audit read model | Read API; mutations not exposed on client routes reviewed |
| Authority access audit (020–022 docs) | Documented append-only + revoke of direct service-role writes |

**Gap:** Unified “electronic meteorological record audit” module is not a single table; observation audit ≠ station catalogue audit ≠ permission grant audit. UI electronic audit remains presentation-only until read models are approved.

## 5. API surface protection

- Default deny unless authenticated  
- Station routes pass `stationId` from path into server-side permission checks (not client-supplied role claims)  
- Archive endpoint documents and enforces explicit grant code  
- Validation endpoints exist for hourly/daily/phenomena (scientific rules from legacy sources in Domain validators — not expanded inventively in Stage D)

## 6. Secrets & sessions

- No service-role secrets in repo `appsettings.json`  
- CORS allow-list config-driven  
- Supabase session on Flutter side uses secure storage patterns (prior Flutter work); Stage D did not change Flutter  

## 7. Vulnerabilities / risks (honest)

| ID | Risk | Status |
|----|------|--------|
| R1 | Empty-DB migration replay impossible without baseline pack | Documented; **not fixed** (awaiting approval) |
| R2 | Archive production read-model absent → 503 | **Intentional** fail-closed |
| R3 | Full JWT integration tests for archive 401/403 not re-run here | Residual → CI |
| R4 | Permission grant without station_id in production RPC (if any legacy grants) | Isolated SQL **requires** station_id match; production RPC in 003 must be reviewed before hosted archive enablement to ensure grant.station_id predicate exists there too |
| R5 | Electronic audit UI vs multiple audit tables | Product clarity risk, not auth bypass |

**R4 action:** Before enabling hosted archive, confirm production `metra_user_has_station_permission` (or archive-specific RPC) joins `permission_grants` with **station_id equality** for `observation.archive.read`. Isolated test function already does.

## 8. Fixes implemented in Stage D

- Security audit documentation  
- Baseline schema gap proposal (no CREATE pack)  
- Re-executed live isolated archive isolation suite (evidence above)  
- No behavior change to hosted systems  
- Archive endpoint remains **503 fail-closed**

## 9. Decisions needing your approval

1. Approve scope of future `database/baseline/` pack (see companion doc).  
2. Approve review of production RPC text for `permission_grants.station_id` binding before any hosted archive enablement.  
3. Optional: prioritize CI job that boots isolated PG and runs `database/isolated/02_test_archive_isolation.sql`.

## 10. Commits

Stage D documentation commit follows on branch `work/backend-db-integration-phase`.  
Push/PR creation requires credentials not available in this sandbox.
