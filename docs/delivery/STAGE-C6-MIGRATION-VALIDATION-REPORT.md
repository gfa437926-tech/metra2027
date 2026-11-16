# Stage C6 — Migration Validation

## Path N evidence
- `path_n_apply.sh` → exit **0**
- Unique index apply + concurrency SQL → **ALL GRANT UNIQUENESS TESTS PASSED**
- R4 rollback script applied successfully on isolated DB after apply

## Path H (preparatory only)
1. Backup hosted DB  
2. `01_precheck.sql`  
3. Resolve duplicate active grants manually  
4. Apply R4 then unique indexes  
5. `06_postcheck.sql`  
6. Keep rollback scripts ready  

**Forbidden:** applying baseline onto existing hosted schema; mixing Path N rebuild with Path H.

## Conflicts
Original migrations remain untouched; Path N uses compat layer only.
