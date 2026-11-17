# METRA 2027 — Stage C2.5 Production Change Readiness & Final Review

**Branch:** `work/backend-db-integration-phase`  
**Parent:** `be5529073cf649b777f49af77a788b009fb547ad`  
**Nature:** Review and packaging only. **Not authorization to apply on hosted Supabase.**

## 1. R4 function comparison

| Aspect | Migration 020 (current production text) | Proposed `02_r4_apply.sql` |
|--------|----------------------------------------|----------------------------|
| Signature | `(uuid,uuid,text) → boolean` | **Same** |
| Name | `metra_user_has_station_permission` | **Same** |
| SECURITY DEFINER + search_path | yes | yes |
| Active account | yes | yes |
| Station approved/active/non-demo | yes | yes |
| Authority + country active | yes | yes |
| Membership time-valid | yes | yes |
| Assignment time-valid on **p_station_id** | yes | yes |
| Role allow-list + grant approved/unrevoked/time-valid | yes | yes |
| Grant join | `user_id` + **`authority_id`** + `permission_code` | Same **plus** for `observation.archive.read` only: `g.station_id IS NOT NULL AND g.station_id = p_station_id` |
| Non-archive permissions | authority-scoped grant | **Unchanged** |

**Consumers:** .NET `HasStationPermissionAsync` → RPC; observation queue/submit/archive endpoints; station authz extensions. Signature stable → no API contract change required for call sites.

**Isolated proof non-archive unchanged:** with authority-scoped `observation.create` grant (`station_id` NULL), both station A and B returned **true** after R4 apply, while archive remained **true** only on A.

## 2. Partial unique index scope

| Index | Predicate | Intent |
|-------|-----------|--------|
| `permission_grants_active_station_unique` | approved + unrevoked + `station_id IS NOT NULL` | One active station-bound grant per (user, station, code) |
| `permission_grants_active_authority_unique` | approved + unrevoked + `station_id IS NULL` | One active authority-scoped grant per (user, authority, code) |

- Historical revoked rows excluded → re-grant allowed.
- Not all permissions are forced to station scope; authority-null station path preserved.
- Backend should treat `23505 unique_violation` on grant insert as conflict (not implemented as code change in C2.5).

## 3. Final SQL package

Directory: `database/proposals/c25_readiness/`

| File | Role |
|------|------|
| `01_precheck.sql` | Signature + duplicate active queries + archive null-station count |
| `02_r4_apply.sql` | Proposed function |
| `03_r4_rollback.sql` | Exact 020 function body restore |
| `04_grant_unique_apply.sql` | Two partial unique indexes |
| `05_grant_unique_rollback.sql` | DROP INDEX only |
| `06_postcheck.sql` | Signature, archive predicate present, indexes, zero dups |
| `README.md` | Order and safety notes |

Original `database/migrations/*` **not modified**.

## 4. Isolated integration results (`metra_c25`)

| Step | Result |
|------|--------|
| Path N apply | exit 0 |
| Precheck dups / null archive station | empty / 0 |
| R4 + unique apply | OK |
| archive A / B | **t / f** |
| create A / B (non-archive) | **t / t** |
| Duplicate active insert | **PASS** unique_violation |
| Revoke + re-grant | active count **1** |
| R4 rollback | archive predicate **absent** (`f`) |
| Index rollback | 0 active_* indexes |

## 5. Future hosted deploy plan (not executed)

1. **Precheck** on target (read-only): `01_precheck.sql`.  
2. If duplicate *active* groups exist → **manual** product decision (revoke extras); **no automatic DELETE/UPDATE of history** in this pack.  
3. Apply `02_r4_apply.sql` in a controlled window.  
4. Apply `04_grant_unique_apply.sql` (or `CONCURRENTLY` variant under maintenance policy).  
5. **Postcheck** `06_postcheck.sql` + smoke RPC calls for archive and one non-archive permission.  
6. **Stop** if postcheck fails or smoke diverges.

**Rollback:** `05` then `03` (indexes first if they block ops; function restore independent). Never delete grant/audit rows as rollback.

## 6. Residual risks

1. Existing hosted duplicate actives would block index creation until resolved.  
2. R4 does not by itself fix clients that omit station on non-archive grants.  
3. Archive API remains **503** until read-model + hosted RPC approval.  
4. Branch may still be local-only → no GitHub Actions proof for this pack.

## 7. GitHub & .NET

| Item | Status |
|------|--------|
| Remote branch ref | Check at report time (historically 404 if not pushed) |
| CI run URL | **Not claimed** without link |
| .NET tests | Re-run against existing test DLL when available; prior C2.4: 237 passed |

## 8. Stop

Await **explicit human approval** before any hosted SQL. Stage E not started.
