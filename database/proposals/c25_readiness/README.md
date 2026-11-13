# C2.5 production change readiness package

**Not authorization to apply on hosted Supabase.**

| File | Purpose |
|------|---------|
| `01_precheck.sql` | Read-oriented duplicate/signature checks before any change |
| `02_r4_apply.sql` | Proposed `metra_user_has_station_permission` (archive station bind only) |
| `03_r4_rollback.sql` | Restore function body from migration 020 |
| `04_grant_unique_apply.sql` | Partial unique indexes for active grants |
| `05_grant_unique_rollback.sql` | Drop those indexes |
| `06_postcheck.sql` | Post-apply verification |

Recommended future order (hosted, after approval): precheck → resolve duplicate *actives* manually if any → R4 apply → unique indexes → postcheck.  
Rollback independently: drop indexes first if needed, then restore function — never DELETE grant/audit history.
