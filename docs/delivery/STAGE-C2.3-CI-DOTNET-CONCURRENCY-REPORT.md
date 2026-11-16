# METRA 2027 — Stage C2.3 CI, .NET & Concurrency Verification

**Branch:** `work/backend-db-integration-phase`  
**Local HEAD:** `63199f90f17e75496ea0fb8bc8765653190d4e6d` (+ this report commit)

## 1. GitHub Actions

| Check | Result |
|-------|--------|
| Remote `origin` | `https://github.com/gfa437926-tech/metra2027.git` |
| Branch on GitHub `work/backend-db-integration-phase` | **Not found** (API `git/ref` → 404) |
| Local commits ahead of remote | Branch exists only locally in this workspace |
| `backend-ci.yml` jobs | Contains `isolated-archive-authz`, `path-n-empty-db`, `dotnet test` step, `dotnet-version: 10.0.x` |
| Workflow run URL | **None** — cannot dispatch Actions without pushing the branch and authentication |

**Blocker:** No credentials/`gh` auth to push branch or trigger `workflow_dispatch`.  
**Conclusion:** CI was **not** executed on GitHub for this commit. Do not claim green Actions.

Repo workflows list (remote main) includes `Backend build` at `.github/workflows/backend-ci.yml` among others; Path N jobs exist in **local** workflow file and will only run after push.

## 2. .NET

| Item | Value |
|------|-------|
| TargetFramework | `net10.0` |
| CI pin | `10.0.x` |
| SDK used here | **10.0.404** (`dotnet --version`) |
| `dotnet restore` | Success (Api + Tests) |
| `dotnet build` Metra.Api Release | **Success** — 0 warnings, 0 errors |
| `dotnet test` Metra.Api.Tests Release `--no-build` | **Passed: 237, Failed: 0, Skipped: 0** |
| Domain archive policy subset | 12/12 passed |

Note: full `dotnet build` on the test project sometimes hung in this sandbox; CoreCompile was up-to-date and tests ran successfully with `--no-build` against the produced test assembly.

## 3. Concurrency probes (isolated Path N DB `metra_conc`)

Schema applied via `path_n_apply.sh` (exit 0).

### Parallel grant inserts (20 concurrent)
- Same `(user, station A, observation.archive.read, approved)`
- **Result: 20 rows** persisted
- Constraints on table: PK, FKs, archive station CHECK, revocation CHECK — **no UNIQUE/EXCLUDE** observed for `(user_id, station_id, permission_code)` among approved grants
- **Finding:** race can create **duplicate concurrent grants**; not a station-scope bypass by itself, but operational ambiguity (which grant is revoked?)
- **Proposal (not applied):** deferred unique/exclusion on approved non-revoked grants per (user, station, permission) or (user, authority, permission) per product rules — requires separate approval

### Parallel revoke same grant id (5 concurrent)
- Pattern: `UPDATE … SET revoked_at=now() WHERE id=:id AND revoked_at IS NULL`
- **Result:** one session updated 1 row; others 0 rows; final state **revoked once**
- Acceptable optimistic concurrency for revoke

### Cross-station
- Count of grants on station B after only inserting for A: **0**
- Table CHECK still rejects archive grant with `station_id IS NULL`

### Audit
- Path N retains append-only triggers on authority audit (prior C2.2)

## 4. R4 review (no apply)

Production function on Path N DB (`metra_user_has_station_permission`) body references **`g.authority_id`**, not **`permission_grants.station_id`**.

| Question | Answer |
|----------|--------|
| Is `station_id` required in RPC for `observation.archive.read`? | **No** in current production RPC text |
| Can authority-scoped grant + assignment to B open B archive? | **Yes risk** under RPC alone if grant is authority-level and user assigned to B |
| Do current tests catch it? | Domain + isolated SQL predicate with `station_id` equality catch intended policy; **production RPC path does not yet match** isolated predicate |
| RPC 031 | Proposal only — **not applied** |

Mitigations already in tree without 031: table CHECK for archive grants requiring `station_id`; API still **503**; Domain archive policy station match.

## 5. Explicitly not done

- Push branch / open PR / merge  
- GitHub Actions live run  
- Hosted Supabase / METRA OLD  
- Original migration edits  
- Backfill / RPC 031 / archive service enablement  
- Flutter mock removal / Angular  

## 6. Residual risks

1. Duplicate concurrent permission grants (no unique/exclude)  
2. R4 production RPC authority-scoped vs station-scoped ArchiveRead policy  
3. CI evidence pending push  

## 7. Stop

Stage E not started. Awaiting review.
