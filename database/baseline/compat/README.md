# Path N compatibility patches

These files exist so an **empty PostgreSQL** database can reach the same structural end-state as applying production migrations on a legacy hosted shape, **without editing** `database/migrations/*` or `supabase/migrations/*`.

| Patch | Original migration | Path N action | Path H |
|-------|-------------------|---------------|--------|
| `020_path_n_skip_add_authority_id.sql` | 020 | Skip original 020; apply this | Apply original 020 |
| `022_path_n_revocation_check.sql` + `022_path_n_revocation_functions.sql` | 022 | Skip original 022; apply these | Apply original 022 |
| `027_path_n_authority_code_column.sql` | 027 | Apply **before** 027 | Usually no-op if column exists |

Runner: `database/baseline/path_n_apply.sh`
