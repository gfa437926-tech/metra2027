# Recovered live Supabase migration history

**Project:** `tbdnklyxjvbrilvnwgmq`  
**Captured:** 2026-11-15  
**Source:** read-only export of `supabase_migrations.schema_migrations`.

This directory contains all **86** migration SQL statements recovered from the live project's migration-history table. Each record had exactly one non-null SQL statement. Files use the exact recorded version and name:

`<version>_<name>.sql`

The archive spans `20261102154652` through `20261114204951`.

## Important: archive only — do not apply

These files are a forensic/source-recovery snapshot, **not** the canonical Supabase CLI migration directory. Do not run `supabase db push`, `supabase migration up`, or otherwise apply this directory. Some historical migrations are context-dependent and include destructive operations against application-owned objects in the new project's `public` schema. Their presence here records what the live database says was applied; it is not approval to replay them.

The repository's existing `supabase/migrations/` directory contains a different, incomplete set of five files. Some of those files do not byte-match the live SQL for their recorded version, and two filenames use timestamps that differ from the corresponding live migration version. Preserve both sets until a reviewed reconciliation determines the canonical history.

## Reconciliation procedure

1. Compare every archive file with its candidate Git migration by exact version, SQL text and checksum.
2. Identify migration files that were never applied, were applied under a different version, or diverged after deployment.
3. Review the greenfield rebuild migration and all destructive statements independently.
4. Build a disposable PostgreSQL database and reconstruct the schema using a deliberately curated, ordered canonical migration set.
5. Compare tables, columns, constraints, indexes, triggers, functions, grants and RLS policies against the live project.
6. Only after reproducibility and security tests pass, promote an approved canonical migration set into `supabase/migrations/`.

No database writes were performed to create this archive. The live database was not changed.
