# METRA 2027 — Stage C3 Backend Integration Completion Report

**Branch:** `work/backend-db-integration-phase`  
**Restore point (pre-C3 HEAD):** `12c91d30d786f247456301d42baf6a7835e8720a`  
**This stage ends at:** see `git rev-parse HEAD` after commits below.

## 1. Pre-existing work (C2.x)
- Path N baseline + compat patches; isolated archive tests; R4 + unique-index **proposals**
- Domain/API archive station policy; archive HTTP **503** fail-closed
- Grant conflict detector (23505 → 409)
- backend-ci: build, test, path-n-empty-db, isolated-archive-authz

## 2. Executed in C3
1. **Security headers** middleware (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`) on API pipeline.
2. **Domain authorization regression tests** expanded (empty station, null permissions, approve≠archive, create without permission).
3. **`database/isolated/05_grant_uniqueness_concurrency.sql`** — station + authority unique index probes, revoke/regrant.
4. **CI job `grant-uniqueness-isolation`** — Path N → apply unique indexes → run concurrency SQL (local Postgres service only).
5. **Developer docs:** `docs/backend/LOCAL-DEVELOPMENT.md`, `AUTHORIZATION-MATRIX.md`, `API-ENDPOINT-INVENTORY.md`.
6. **Delivery reports** C3 completion + remaining work.

## 3. Files touched (primary)
- `backend/Metra.Api/Program.cs`
- `backend/Metra.Api.Tests/Domain/ObservationAuthorizationPolicyTests.cs`
- `database/isolated/05_grant_uniqueness_concurrency.sql`
- `.github/workflows/backend-ci.yml`
- `docs/backend/*`
- `docs/delivery/STAGE-C3-*.md`

## 4. Defects found and fixed
| Issue | Fix |
|-------|-----|
| Domain test file brace corruption during edit | Restored from `12c91d3` and re-applied tests |
| Invalid UUID literals in uniqueness SQL (`s` nibble) | Replaced with valid hex UUIDs |
| CI path gaps for baseline/proposals (C2.8) | Already expanded; C3 adds grant uniqueness job |

## 5–7. Build and tests
| Suite | Result |
|-------|--------|
| `dotnet build` Metra.Api Release | **Success** |
| Full `Metra.Api.Tests` | **Passed 253 / Failed 0 / Skipped 0** (was 249 in C2.6/C2.7; **+4** domain cases) |
| Path N empty DB (`metra_c3b`) | **exit 0** |
| Grant uniqueness SQL | **ALL GRANT UNIQUENESS TESTS PASSED** |
| R4 proposal apply on clone | Applied successfully (local only) |

## 8–9. Security / authz
- Archive still **503** after permission check.
- Domain: archive not inferred from Approve/Review; cross-station denied.
- 23505 mapping retained from C2.6.
- Unique indexes still **proposal** for hosted; exercised in isolated CI job definition + local run.

## 10. CI coverage
| Job | Local definition | Remote run |
|-----|------------------|------------|
| build + dotnet test | yes | **Not run** (branch not pushed) |
| path-n-empty-db | yes | not run |
| isolated-archive-authz | yes | not run |
| grant-uniqueness-isolation | **added** | not run |

No workflow uses hosted Supabase credentials for DB writes.

## 11. Remaining gaps
See `STAGE-C3-REMAINING-WORK-AND-DEPENDENCIES.md`.

## 12. Risks needing independent approval
- Push branch / Draft PR / real Actions URLs  
- Hosted apply of R4 + unique indexes  
- Enabling archive read service  

## 13. How to verify locally
```bash
dotnet test backend/Metra.Api.Tests/Metra.Api.Tests.csproj -c Release
export PATH_N_DATABASE_URL=postgres://...
bash database/baseline/path_n_apply.sh
psql "$PATH_N_DATABASE_URL" -f database/proposals/c25_readiness/04_grant_unique_apply.sql
psql "$PATH_N_DATABASE_URL" -f database/isolated/05_grant_uniqueness_concurrency.sql
```

## 14–15. Git
- Working tree committed in organized commits (this stage).
- **No push / no PR.**
