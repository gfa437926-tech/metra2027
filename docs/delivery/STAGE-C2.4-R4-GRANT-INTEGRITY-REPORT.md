# METRA 2027 — Stage C2.4 R4 Security Remediation & Permission Grant Integrity

**Branch:** `work/backend-db-integration-phase`  
**Parent:** `4f150f1b9f2cb1dfd1a1cf3069b51359cbe7f83f`  
**Constraint:** local proposals + isolated tests only. **No hosted apply. No original migration rewrite.**

## 1. R4 analysis

### Consumers of `metra_user_has_station_permission`
| Layer | Path |
|-------|------|
| Supabase RPC name | `metra_user_has_station_permission` |
| .NET | `SupabaseStationAuthorizationService.HasStationPermissionAsync` → RPC |
| API | Archive, queue, submission, station authz extensions |

### Before (migration 020)
Grant join: `user_id` + **`authority_id`** + `permission_code`  
Station isolation via **assignment** only → archive grant at authority scope + assignment to B can authorize B.

### After (proposal file only)
`database/proposals/R4_archive_station_bind_function.sql`  
For `observation.archive.read` **only**:
```sql
OR (g.station_id IS NOT NULL AND g.station_id = p_station_id)
```
Other permission codes unchanged (authority-scoped grant).

### Alignment
| Layer | Station archive policy |
|-------|------------------------|
| Domain `ObservationArchiveAuthorizationPolicy` | ArchiveRead + station match |
| API archive endpoint | permission code + Domain; still **503** data path |
| Table CHECK | archive requires non-null station_id |
| Proposed RPC | station_id equality for archive.read |

### Rollback
Re-run `CREATE OR REPLACE` from migration 020 function body (authority join only).

## 2. PostgreSQL isolated results (`metra_c24`)

Path N apply: **exit 0**. Proposal function applied **only** on this DB.

| Test | Result |
|------|--------|
| Archive A with station grant | **PASS** allow |
| Archive B same authority | **PASS** deny |
| Archive after revoke | **PASS** deny |
| Null station_id insert | **CHECK violation** |
| station_head without archive grant | **false** |
| Expired assignment | **false** |
| Restore assignment | **true** again |

## 3. Grant integrity policy (proposal)

Documented in `database/proposals/GRANT_ACTIVE_UNIQUENESS_POLICY.md`.

Partial unique index (tested **only** on isolated DB):
```sql
CREATE UNIQUE INDEX … ON permission_grants (user_id, station_id, permission_code)
WHERE approval_status='approved' AND revoked_at IS NULL AND station_id IS NOT NULL;
```

| Scenario | Result on isolated DB |
|----------|------------------------|
| 5 concurrent duplicate active inserts | **5 unique violations**; active count stays **1** |
| Revoke then re-grant | **allowed**; active count **1** |
| Historical revoked rows | retained |

**Not applied** to production migrations or hosted DB.

## 4. .NET

| Command | Result |
|---------|--------|
| `dotnet build` Metra.Api Release | **Success** |
| `dotnet test` Metra.Api.Tests.dll | **Passed 237 / Failed 0 / Skipped 0** |

## 5. CI

Branch still **not on remote** in prior C2.3 assessment; this environment has no push auth. **No Actions run URL.**

## 6. Files

- `database/proposals/R4_archive_station_bind_function.sql`
- `database/proposals/GRANT_ACTIVE_UNIQUENESS_POLICY.md`
- `database/isolated/04_r4_and_grant_integrity_tests.sql`
- this report

## 7. Explicitly not done

Hosted RPC apply, backfill, archive 503 removal, Flutter, Angular, PR merge, original migration edits.

## 8. Stop

Await approval before any hosted remediation or Stage E.
