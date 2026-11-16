# METRA 2027 — Stage C2.8 GitHub Delivery & CI Closure Readiness

**Branch:** `work/backend-db-integration-phase`  
**HEAD at report authoring:** `c1a7aa9673b982b88dc964abbc3fbd0c475c8ad4` (+ CI path-filter commit if landed after)  
**Constraint:** **No push, no PR, no hosted SQL, no Stage E.**

## 1. Commit chain C2.4 → C2.7 (verified)

| Stage | SHA | Parent | Subject |
|-------|-----|--------|---------|
| C2.4 | `be5529073cf649b777f49af77a788b009fb547ad` | `4f150f1…` | R4 proposal + grant integrity |
| C2.5 | `ca3f7fc7bf987c568146f90dff43c63d3d157215` | `be55290…` | Production change readiness pack |
| C2.5+E prep | `e7ccf6637253c980253fc8781c990cf35e0e0042` | `ca3f7fc…` | Independent verification + Stage E prep doc |
| C2.6 | `4bba6229abf6f214f544a8a3833ad163858154dd` | `e7ccf66…` | 23505 → HTTP 409 |
| C2.7 | `c1a7aa9673b982b88dc964abbc3fbd0c475c8ad4` | `4bba622…` | Final security regression audit |

Linear parent chain: **valid**. Working tree: clean before C2.8 edits (only intentional CI path updates).

## 2. Delivery artifacts present

Reports: `STAGE-C2` / `C2.1` … `C2.7`, `STAGE-E-PREPARATION-…` under `docs/delivery/`.

Proposals: R4 function, grant uniqueness policy, `c25_readiness/` (6 SQL + README), `c26_decide_grant_unique_conflict.sql`.

Baseline + Path N runner: `database/baseline/**`, `path_n_apply.sh`, `compat/**`.

## 3. Secrets scan (pre-push)

- Backend tests use **placeholder** keys (`server-only-test-key`, example URLs) — acceptable.
- Application code reads **configuration** `Supabase:ServiceRoleKey` — not hardcoded production secrets in C2.x commits reviewed.
- `deploy-pages.yml` references `secrets.METRA_SUPABASE_URL` and embeds a project host string for Angular pages deploy — **out of C2.8 backend path**; do not trigger deploy-pages as part of this branch delivery without separate review.
- **backend-ci.yml** uses only local Postgres service credentials (`metra_test` / `metra_test_isolated`) — **no hosted Supabase write**.

## 4. GitHub Actions coverage (`backend-ci.yml`)

| Capability | Job / step | Notes |
|------------|------------|-------|
| `dotnet build` | `build` | Release API |
| `dotnet test` | `build` | Metra.Api.Tests |
| Path N empty DB | `path-n-empty-db` | service postgres:16 + `path_n_apply.sh` |
| Archive isolation | `isolated-archive-authz` | isolated SQL suite |
| Grant uniqueness / concurrency | **Not a dedicated job** | Covered locally in C2.6; indexes are **proposal** files not applied in Path N by default |
| Hosted Supabase | **None** | No service-role against production |

### CI fix prepared (local only)
Path filters previously **omitted** `database/baseline/**`, `database/proposals/**`, `database/seeds/**`, `docs/delivery/**`, so PR changes limited to those paths might skip backend-ci jobs. Filters updated in both `push` and `pull_request` blocks.

**Still required after push (with approval):** open Draft PR and capture real Actions URLs — not claimable until then.

Triggers: `pull_request` (path-filtered), `push` to `main` only, `workflow_dispatch`. Feature-branch **push alone** does not run on `main` paths until PR or dispatch.

## 5. Readiness answers

| Question | Answer |
|----------|--------|
| Branch ready to **push**? | **Technically yes** (documented chain, no embedded prod secrets in C2 backend commits, CI improved) — **only after your explicit approval** |
| All commits documented? | **Yes** (C2.4–C2.7 reports + this file) |
| CI ready? | **Mostly** — build/test/Path N/archive jobs exist; uniqueness concurrency not separate CI job; **no green run until remote exists** |
| Needs approval? | Push branch; create Draft PR; any hosted Stage E SQL; deploy-pages secrets usage |
| Residual risks | Remote 404 today; Path N does not apply R4/unique proposals automatically; archive still 503; Flutter mocks remain |

## 6. Explicit non-actions

No `git push`. No PR. No Stage E. No hosted SQL. No METRA OLD / Flutter / Angular changes.

## 7. Decision

**جاهز للمراجعة وقرار الرفع** — Ready for your go/no-go on **push + Draft PR only**.  
**غير جاهز** لاعتبار CI أخضر أو للتطبيق المستضاف.
