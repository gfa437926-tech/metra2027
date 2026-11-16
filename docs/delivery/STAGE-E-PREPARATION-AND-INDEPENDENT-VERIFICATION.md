# METRA 2027 — Independent Verification of C2.5 & Stage E Preparation

**Date:** 2026-11-12  
**Branch (local):** `work/backend-db-integration-phase`  
**Local HEAD:** `ca3f7fc7bf987c568146f90dff43c63d3d157215`  
**C2.5 report:** `docs/delivery/STAGE-C2.5-PRODUCTION-CHANGE-READINESS.md`

## 1. Branch & commit on GitHub

| Check | Result |
|-------|--------|
| Local HEAD | `ca3f7fc7bf987c568146f90dff43c63d3d157215` — C2.5 readiness pack |
| API `…/git/ref/heads/work/backend-db-integration-phase` | **404 Not Found** |
| API commit `ca3f7fc…` | **422 No commit found** |
| Conclusion | Branch and commit exist **only locally** in this workspace; **not** on `origin` |

**CI:** Cannot run or claim success on GitHub Actions for this branch until it is **pushed**. No Actions URL.

## 2. C2.5 package file verification

All six SQL files + README present under `database/proposals/c25_readiness/`:

| File | Present | Matches report role |
|------|---------|---------------------|
| `01_precheck.sql` | yes | pre-apply read checks |
| `02_r4_apply.sql` | yes | proposed R4 function |
| `03_r4_rollback.sql` | yes | restore 020 body |
| `04_grant_unique_apply.sql` | yes | two partial unique indexes |
| `05_grant_unique_rollback.sql` | yes | DROP INDEX only |
| `06_postcheck.sql` | yes | post-apply verification |
| `README.md` | yes | order/safety |

Report `STAGE-C2.5-PRODUCTION-CHANGE-READINESS.md` is present and consistent with package contents.

## 3. R4 vs Migration 020 (independent review)

- **Signature / name / return type:** unchanged.
- **Preserved gates:** active account, station approved/active/non-demo, authority/country active, membership window, assignment on `p_station_id`, role allow-list, grant approved/unrevoked/time window.
- **Delta only:** for `observation.archive.read`, require `g.station_id IS NOT NULL AND g.station_id = p_station_id`.
- **Other permission codes:** still authority-scoped grant join only (no forced station_id).
- **Consumers:** `HasStationPermissionAsync` → RPC; observation queue/submit/archive; station authz extensions — call shape unchanged.

Prior isolated evidence (C2.5): archive A true / B false; `observation.create` true on A and B with authority-scoped grant.

## 4. Partial unique indexes

| Index | Covers |
|-------|--------|
| `permission_grants_active_station_unique` | Active approved unrevoked grants with **station_id NOT NULL** |
| `permission_grants_active_authority_unique` | Active approved unrevoked grants with **station_id IS NULL** (authority-scoped) |

History and post-revoke re-grant remain possible. Not all permissions forced to station scope.

## 5. Backend handling of unique violation

| Finding | Detail |
|---------|--------|
| Grant APIs | `AuthorityAccessEndpoints` call RPCs (`request_authority_permission_grant`, decide, revoke) |
| Mapped RPC statuses | Includes `"conflict"` → `Results.Conflict` |
| Explicit `23505` / Postgres unique mapping | **Not found** in C# grant path |
| Risk | If unique index rejects INSERT inside RPC without translating to `conflict`, API may surface as **500** instead of 409 |

**Recommendation (not implemented — needs approval):** ensure grant RPCs catch unique_violation and return `conflict`; optionally map PostgREST/DB unique errors in the service client. No code change in this verification pass (no Stage E execution).

## 6. Integration test coverage (from C2.4/C2.5 evidence)

| Scenario | Covered in isolated runs |
|----------|---------------------------|
| Archive A allow / B deny | yes |
| Non-archive consumers still authorize | yes (`observation.create`) |
| Null station archive insert | CHECK reject |
| Concurrent duplicate active grant | unique_violation after index |
| Revoke + re-grant | yes |
| Append-only audit | prior C2.x (authority audit / grant audit triggers) |

## 7. .NET / CI (this verification session)

| Item | Result |
|------|--------|
| GitHub Actions | **Not runnable** (branch not on remote) |
| `dotnet test` this session | SDK/DLL may be unavailable after environment reset; **last recorded success: 237 passed** (C2.4) |

Do **not** treat local history as CI green.

## 8. Gaps / fixes in this pass

| Gap | Action taken |
|-----|----------------|
| Branch not on GitHub | Documented only — push requires user credentials |
| Backend 23505 mapping | Documented residual; **no code change** without approval |
| Hosted apply | Explicitly **not** done |

No original migrations modified. No hosted SQL. No archive endpoint enablement.

## 9. Stage E preparation (not started)

### Preconditions before any hosted apply
1. **Push** `work/backend-db-integration-phase` and open Draft PR; obtain CI green on `backend-ci` (including Path N / archive jobs if configured).  
2. **Backup** hosted schema + `permission_grants` / audit tables (operator-owned).  
3. Run **`01_precheck.sql`** read-only on a **clone** or approved read path; **zero** duplicate active groups preferred.  
4. If duplicates exist: **manual** product decision (which grant remains active); **no automatic backfill/DELETE** in the pack.  
5. Maintenance window + rollback owner assigned.  
6. Explicit written approval for hosted apply of `02` then `04`.

### Proposed hosted order (future)
1. Precheck  
2. Manual duplicate resolution if needed  
3. `02_r4_apply.sql`  
4. `04_grant_unique_apply.sql` (consider `CONCURRENTLY` under ops policy)  
5. `06_postcheck.sql` + smoke: archive deny cross-station; one non-archive permission still works  
6. **Stop** on any postcheck failure → `05` then `03`

### Rollback
- Indexes: `05_grant_unique_rollback.sql`  
- Function: `03_r4_rollback.sql`  
- **Never** delete grant or audit rows as rollback

### Security gates still closed until separate approval
- Archive HTTP endpoint remains **503** / unconfigured service  
- Flutter mock removal / real API binding = Stage E product work, not this SQL pack  
- Angular out of scope  

### Production transition risks
1. Duplicate active grants block unique index creation  
2. RPC/API may return 500 on unique until mapped to conflict  
3. R4 tightens archive only — mis-issued authority-level archive rows already blocked by table CHECK if present  
4. Applying without backup or postcheck  

## 10. Decision

| Criterion | Status |
|-----------|--------|
| C2.5 SQL package complete & consistent | **Yes** |
| Independent review R4 scope-limited | **Yes** |
| Indexes cover station + authority active grants | **Yes** |
| Local isolated evidence documented | **Yes** |
| Branch/commit on GitHub + CI proof | **No** |
| Backend unique→409 hardened | **Not yet** (optional follow-up) |
| Approved for hosted apply | **No — awaits explicit user approval** |

### Overall readiness for *review*
**جاهز للمراجعة التقنية لحزمة SQL وخطط النشر** (Ready for technical review of the SQL pack and deploy plan).

### Overall readiness for *hosted Stage E apply*
**غير جاهز للتطبيق المستضاف** حتى:
1. رفع الفرع ونجاح CI بروابط حقيقية، و  
2. موافقة صريحة منك بعد precheck/backup، و  
3. (موصى به) معالجة mapping التعارض في مسار المنح.

**Stage E not started.** Stopped pending your approval.
