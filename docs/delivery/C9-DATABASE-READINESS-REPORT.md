# C9 — Database Readiness Report

| Item | Status |
|------|--------|
| Path N baseline runner | Verified on empty isolated DBs (C8/C9) |
| Compat patches (Path N only) | Present under `database/baseline/compat/` (local) |
| R4 / grant unique SQL proposals | `database/proposals/c25_readiness/` — apply only after approval |
| Archive isolation fixtures | `database/isolated/` |
| Hosted Supabase | **Unchanged** — no DDL/RLS/RPC/backfill in this program |

**Ready for isolated rebuild and review. Not ready as applied production schema without approved change window.**
