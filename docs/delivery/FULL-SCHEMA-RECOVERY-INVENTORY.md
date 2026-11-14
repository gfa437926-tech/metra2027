# METRA — Full schema recovery inventory

**Recovery branch:** `work/metra-full-schema-recovery-2026-11-14`  
**Pinned baseline source:** `9a0cfea423a4934a0bc28a49b613f12838afb53d`  
**Scope:** isolated PostgreSQL only. No hosted Supabase changes, no METRA OLD import, no production migration, no merge.

## Verified authoritative table definitions available in the pinned baseline

The baseline defines these 16 public tables:

| Group | Tables |
|---|---|
| Geography / stations | `countries`, `meteorological_authorities`, `station_catalogue` |
| Roles / permissions | `metra_role_catalogue`, `metra_permission_codes`, `metra_role_permissions` |
| Identity / authorization | `metra_account_states`, `authority_memberships`, `station_assignments`, `permission_grants`, `metra_user_profiles` |
| Registration / audit | `registration_requests`, `registration_audit_events`, `station_audit_log`, `permission_grant_audit`, `authority_access_audit_events` |

The baseline also creates an isolated-only `auth.users` stub. It is not a hosted Supabase Auth replacement.

## Additional authoritative operational definitions

The approved migration
`supabase/migrations/20261103164003_create_operational_observation_submission.sql`
defines two additional public tables:

- `metra_observations`
- `metra_observation_audit_events`

These remain owned by that migration and must not be duplicated in baseline SQL.

## Important completeness finding

This is a verified inventory of the definitions available from the pinned baseline commit and the identified operational-observation migration. It is **not evidence that every table in every approved migration has been recovered**.

The existing baseline implementation report explicitly records unresolved linear-replay conflicts in later migrations (including missing catalogue role seed values and a duplicate `authority_id` column assumption). Forecast, AI, Climatol, notification and broader electronic-record schemas were previously marked as lacking approved operational definitions. They must not be fabricated.

Accordingly, the complete migration bundle still needs to be enumerated from the repository at a single pinned commit before claiming total schema recovery. No migration was silently skipped or rewritten here.

## Catalog-level verification

Run the read-only inventory against the isolated database after applying the approved SQL. It exports actual columns, defaults, comments, constraints, indexes, RLS policies, triggers and routine definitions:

```bash
psql "$METRA_ISOLATED_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -f database/baseline/verify_full_schema_catalog.sql \
  > full-schema-catalog.txt
```

Compare two independent empty-database restores by normalizing and diffing their catalog exports. This verifier does not apply DDL and must never be pointed at a hosted database.

## Required acceptance gates

1. Pin one source commit and enumerate every file under `database/baseline/` and `supabase/migrations/`.
2. Parse every `CREATE TABLE`, `ALTER TABLE`, index, policy, trigger, type, sequence and routine definition.
3. Assign exactly one authoritative owner to each object; reject duplicate table ownership.
4. Resolve migration ordering and baseline/migration compatibility without changing production migrations silently.
5. Restore twice into fresh isolated PostgreSQL databases.
6. Compare catalog exports and run all existing SQL authorization / audit tests.
7. Record actual command output and CI run URLs; do not infer a pass.

## Safety status

- Hosted Supabase: **not touched**.
- Legacy METRA database: **not touched**.
- Production RPCs / archive enablement: **not changed**.
- Main branch / existing working branch: **not modified**.
- Full recovery acceptance: **pending** the complete migration-bundle enumeration and compatibility pass above.


## Expanded migration bundle extraction

The full repository tree also contains 29 ordered files in `database/migrations/003–031` and 5 files in `supabase/migrations/`. The pinned extraction, source classifications, and verified replay blockers are recorded in [COMPLETE-MIGRATION-BUNDLE-EXTRACTION-REPORT.md](COMPLETE-MIGRATION-BUNDLE-EXTRACTION-REPORT.md).

The read-only two-database comparison runner is `database/tests/compare_isolated_schema_snapshots.sh`. It compares schema-only dumps and catalog inventories from two already-restored isolated databases. It does not apply DDL or connect to hosted environments.

**Acceptance remains blocked:** source inspection confirms baseline/migration conflicts. Do not run a linear empty-database replay until the canonical table shapes are reconciled.


## Baseline-to-migration reconciliation

The relation-by-relation discrepancy register is maintained in [SCHEMA-RECONCILIATION-MATRIX.md](../../database/baseline/SCHEMA_RECONCILIATION_MATRIX.md). It distinguishes verified baseline columns from migration dependencies and marks unresolved schema contracts as blocked rather than inventing definitions. This is a static review artifact; it does not authorize DDL execution.
