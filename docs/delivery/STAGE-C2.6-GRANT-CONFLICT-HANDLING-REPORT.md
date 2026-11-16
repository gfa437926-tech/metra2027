# METRA 2027 — Stage C2.6 Grant Conflict Handling (PostgreSQL 23505 → HTTP 409)

**Branch:** `work/backend-db-integration-phase`  
**Parent:** `e7ccf6637253c980253fc8781c990cf35e0e0042`

## 1. Problem

Partial unique indexes on active `permission_grants` (C2.5 proposal) raise SQLSTATE **23505** when a second **approved** active grant is inserted for the same scope. PostgREST/Supabase may surface that as HTTP 409 **or** 400/500. The Backend previously mapped only an explicit HTTP Conflict status (and RPC string `"conflict"`), so a **500-shaped** unique error could become generic **503 Unavailable** via `MapFailure` fallback.

Note: `request_authority_permission_grant` inserts **`pending`** rows, so the unique indexes (approved + unrevoked) typically fire on **approve** (`decide_authority_permission_grant` UPDATE to approved) or direct approved inserts—not on the initial pending request.

## 2. Files changed

| File | Change |
|------|--------|
| `backend/Metra.Api/Features/Users/AuthorityAccessEndpoints.cs` | `AuthorityAccessRpcOutcome.ErrorKind`; `CallAsync` reads error body; `AuthorityAccessConflictDetector`; `MapFailure` uses `authority_permission_grant_conflict` for unique |
| `backend/Metra.Api.Tests/Features/Users/AuthorityAccessConflictDetectorTests.cs` | **New** detector unit tests |
| `backend/Metra.Api.Tests/Features/Users/SupabaseAuthorityAccessServiceTests.cs` | Maps 23505@500 → Conflict; does not map 42501 |
| `database/proposals/c26_decide_grant_unique_conflict.sql` | Optional RPC-side sketch (not applied) |
| this report | |

Original migrations **unchanged**. Hosted DB **not** touched.

## 3. Mechanism

1. On non-success RPC response, read body string.
2. `AuthorityAccessConflictDetector.IsUniqueViolation`:
   - JSON `code == "23505"`
   - or tokens: `unique_violation`, named indexes `permission_grants_active_*`, or `duplicate key` + `permission_grants`
   - empty body + HTTP 409 treated as conflict (PostgREST default)
3. Remap outcome to `StatusCode = Conflict`, `ErrorKind = unique_violation`.
4. `MapFailure` → HTTP **409** with `{ error: "authority_permission_grant_conflict" }` for unique; other Conflict paths keep the endpoint error token.
5. **Non-unique** failures (403, 401, 404, 400, connection) keep prior classification—not forced to 409.

## 4. HTTP 409 tests (.NET)

| Test | Result |
|------|--------|
| Detector accepts 23505 JSON / index names | included in filter suite |
| Detector rejects 42501 / 22023 / empty@500 | yes |
| Service: unique body + HTTP 500 → Conflict + ErrorKind | yes |
| Service: Forbidden 42501 stays Forbidden | yes |
| AuthorityAccess filter | **14 passed** |
| Full suite | **249 passed, 0 failed** |

## 5. Isolated PostgreSQL concurrency

Path N + C2.5 unique indexes on `metra_c26`:

| Scenario | Result |
|----------|--------|
| 5 concurrent duplicate station active grants | **5** unique failures |
| 3 concurrent duplicate authority-scoped active grants | **3** unique failures |
| Revoke + re-grant | **1** active row |

## 6. CI / GitHub

Branch still not verified on remote in prior reports → **no Actions URL claimed**.

## 7. Residual risks

1. Indexes themselves are still **proposal-only** on hosted until approved apply.
2. Optional RPC `EXCEPTION WHEN unique_violation THEN RETURN 'conflict'` not implemented in production migrations.
3. Pending-row request path does not hit unique indexes (by design).
4. Archive endpoint remains **503**.

## 8. Stop

No Stage E. No hosted apply. No Flutter/Angular.
