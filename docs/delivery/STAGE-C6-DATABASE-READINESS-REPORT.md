# Stage C6 — Database Readiness Report

**HEAD base:** `399ff05793f0d5327064d8c6a58435c574a9104d`  
**Path N DB:** `metra_c6` (isolated, local)

## A. Structure review
- `database/baseline/` 001–008 + Path N runner + compat patches (unchanged production migrations)
- `database/proposals/c25_readiness/` R4 + unique indexes (proposal only for hosted)
- `database/isolated/05_grant_uniqueness_concurrency.sql`
- Contracts align with Domain archive station policy and AuthorityAccess 409 mapping

## B. Path separation
| Path | Status this stage |
|------|-------------------|
| **Path N** empty PostgreSQL | **Executed** — `path_n_apply.sh` exit 0; 16 public tables |
| **Path H** hosted upgrade | **Plan only** — not applied; requires preflight/backup/approval |

## C. Security checks (isolated)
- Grant uniqueness: PASS (station + authority + regrant)
- R4 apply → rollback → reapply: OK on clone
- ArchiveRead remains station-bound in proposal + Domain; production RPC still proposal until approved apply
- Audit append-only retained from baseline

## D. Hosted package (not applied)
Use `c25_readiness` 01–06 only after explicit approval. Archive endpoint stays 503.

## E. Commands
```bash
export PATH_N_DATABASE_URL=postgres://metra_test:metra_test_isolated@127.0.0.1:5432/metra_c6
bash database/baseline/path_n_apply.sh
psql "$PATH_N_DATABASE_URL" -f database/proposals/c25_readiness/04_grant_unique_apply.sql
psql "$PATH_N_DATABASE_URL" -f database/isolated/05_grant_uniqueness_concurrency.sql
```
