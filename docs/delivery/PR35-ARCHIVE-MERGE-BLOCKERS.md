# PR #35 — Merge blockers (security)

PR: https://github.com/gfa437926-tech/metra2027/pull/35  
Branch: `work/backend-api-audit-rebased-2026-11-11`

## Blocker 1 — Exact station scope

PR body admits `permission_grants` may be authority-scoped in that design, so one grant can cover multiple stations under the same authority.  
**Policy:** ArchiveRead must be `station_id`-bound only.  
**Required:** RPC equivalent to local proposal `database/proposals/c25_readiness/02_r4_apply.sql` / R4 function text; negative test station A grant denies station B under same authority.

## Blocker 2 — TOCTOU

Authorize in API then read with broad DB credentials is insufficient.  
**Required:** single DB transaction/function: verify grant + assignment + active account, then return rows for that `station_id` only.

## Blocker 3 — Least privilege

Prefer `metra_api_runtime` (or equivalent) over perpetual reliance on service_role for data SELECT after authz. Service_role only for narrow RPC invoke if unavoidable.

## Blocker 4 — Hosted apply

No migration applied to hosted Supabase until owner approval + isolated green tests.

## Local complementary work

- R4 SQL proposals under `database/proposals/`
- Isolated archive isolation tests under `database/isolated/`
- API remains 503 via unconfigured archive service

**Do not merge PR #35 until blockers 1–2 are closed with evidence.**
