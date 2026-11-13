# Stage C8.2 — Backend Verification (local tree)

**Verified against local HEAD:** `6e1f4205e4f67e02cb73fac7296740c939de4bf8`

## Commands and results

| Command | Exit / Result |
|---------|----------------|
| `dotnet build backend/Metra.Api/Metra.Api.csproj -c Release` | **Success** (0 errors) |
| `dotnet test backend/Metra.Api.Tests/Metra.Api.Tests.csproj -c Release` | **Passed 264 / Failed 0 / Skipped 0** (Duration ~13s) |
| Path N `path_n_apply.sh` on DB `metra_c82` | **exit 0** |
| Grant uniqueness SQL (`05_grant_uniqueness_concurrency.sql`) | **ALL GRANT UNIQUENESS TESTS PASSED** |
| R4 apply / rollback / reapply | **exit 0** each |
| Archive isolation (`00`→`01`→`02` on `metra_c82a`) | **ALL ARCHIVE ISOLATION TESTS PASSED** |

## Coverage exercised

- Authority access / station scope / grant conflict 409 mapping (in 264 tests).
- PostgreSQL 23505 uniqueness (SQL + API detector tests).
- Archive station isolation and append-only audit (isolated SQL).
- Path N empty-database schema apply (isolated only; no hosted).

## Note

These results apply to the **local** Backend tree. Remote branch tip does **not** yet contain this Backend work (see C8.1).
