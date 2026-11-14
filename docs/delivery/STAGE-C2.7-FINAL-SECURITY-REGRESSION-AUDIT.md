# METRA 2027 — Stage C2.7 Final Security Regression Audit

## 1. Git reference (corrected)

| Item | Value |
|------|-------|
| **Correct HEAD SHA** | `4bba6229abf6f214f544a8a3833ad163858154dd` |
| Branch | `work/backend-db-integration-phase` |
| Working tree | Clean at audit start |
| Parent | `e7ccf6637253c980253fc8781c990cf35e0e0042` |
| Prior garbled token | **Invalid** — not a git object; discard `4bbaDcJH…` |

### C2.6 commit files
- `backend/Metra.Api/Features/Users/AuthorityAccessEndpoints.cs`
- `backend/Metra.Api.Tests/Features/Users/AuthorityAccessConflictDetectorTests.cs` (new)
- `backend/Metra.Api.Tests/Features/Users/SupabaseAuthorityAccessServiceTests.cs`
- `database/proposals/c26_decide_grant_unique_conflict.sql`
- `docs/delivery/STAGE-C2.6-GRANT-CONFLICT-HANDLING-REPORT.md`

**Remote:** `work/backend-db-integration-phase` still **404** on GitHub. Commit not on `origin`. **No CI URL.**

## 2. C2.6 implementation review

| Check | Finding |
|-------|---------|
| Detect `23505` via JSON `code` | Yes |
| Detect `unique_violation` / index names | Yes (`permission_grants_active_station_unique`, `_authority_unique`) |
| Non-unique errors → 409 | **No** — 42501/22023/connection remain Forbid/BadRequest/Unavailable |
| Leak raw PG to client | **No** — client sees `authority_permission_grant_conflict` only |
| `CallAsync` remap | Failed body inspected; unique → `StatusCode=Conflict` + `ErrorKind` |
| `MapFailure` | Unique → 409; other Conflict keeps endpoint error token |
| Pending request vs approved unique | Indexes apply to **approved + unrevoked**; pending insert does not hit them (by design) |

No code defect requiring fix in C2.7 for the detector scope.

## 3. Cross-cutting security audit

| # | Control | Evidence | Status |
|---|---------|----------|--------|
| 1 | R4 ArchiveRead station bind | Proposal `02_r4_apply.sql` + Domain `ObservationAuthorizationPolicy`; **production RPC text still authority-scoped until hosted apply** | **Partial** — Domain+API+CHECK+isolated proposal; hosted RPC not applied |
| 2 | Station vs authority grants | Dual partial unique indexes (proposal); CHECK archive requires station_id | Designed; indexes not on hosted |
| 3 | Approve / revoke / assignment expiry | RPC returns conflict/unauthorized; Domain denies inactive assignment | Covered in Domain tests |
| 4 | Duplicate active grants + concurrency | Isolated unique failures under parallel insert | OK isolated |
| 5 | 23505 Backend mapping | C2.6 detector + tests | OK |
| 6 | User/authority/station gates in RPC | Membership + assignment + account active in function body | Present in 020 / proposal |
| 7 | Audit append-only | Trigger blocks UPDATE on `authority_access_audit_events` (isolated: `authority_access_audit_is_append_only`) | OK isolated |
| 8 | Archive endpoint fail-closed | `UnconfiguredObservationArchiveService` → **503** after permission check | OK |
| 9 | Authz function consumers | Queue, submit, archive, station extensions via `HasStationPermissionAsync` | OK |
| 10 | Cross-station leak | Isolated: archive A true / B false; Domain tests deny other station | OK (with proposed R4 or Domain layer) |

### Honest residual gaps
1. **Hosted production RPC** still lacks station_id predicate for archive until approved apply of R4 package.  
2. **Unique indexes** not on hosted until approved apply.  
3. Optional RPC `EXCEPTION WHEN unique_violation` not in production migrations.  
4. Branch not pushed → no CI attestation.

## 4. Regression test results (this session)

| Suite | Result | vs C2.6 |
|-------|--------|--------|
| `dotnet build` Metra.Api Release | Success | same |
| Full `Metra.Api.Tests` | **249 passed, 0 failed** | **same as C2.6** |
| AuthorityAccess + ObservationAuthorization filter | **26 passed** | includes C2.6 + Domain archive |
| Path N isolated | exit 0 | |
| R4 proposal + unique indexes applied on clone | OK | |
| archive A / B | **t / f** | |
| create A / B (non-archive consumers) | **t / t** | |
| Audit UPDATE | blocked | |
| GitHub Actions | **not run** | no branch |

## 5. Files changed in C2.7

| File | Reason |
|------|--------|
| `docs/delivery/STAGE-C2.7-FINAL-SECURITY-REGRESSION-AUDIT.md` | This audit only |

No production/code migrations changed in C2.7 (no defect requiring in-scope fix).

## 6. Remaining risks

1. Hosted R4 + unique indexes not applied.  
2. No remote/CI proof.  
3. Archive data path still intentionally 503.  
4. Flutter still on mocks.

## 7. Readiness decision

| Purpose | Decision |
|---------|----------|
| Technical review of security stack (Domain + API + proposals + local tests) | **جاهز للمراجعة** |
| Hosted Stage E / production SQL apply | **غير جاهز** until push+CI, backup, precheck, **explicit approval** |

**Stage E not started.** Stopped pending user approval.
