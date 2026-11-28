# METRA 2027 database assets

This folder contains reviewed, repeatable database seed assets for the **new** METRA 2027 Supabase project.

## Safety boundary

- Target project: `tbdnklyxjvbrilvnwgmq` (`metra2027-angular`).
- The legacy `INSERT` project is read-only for this development effort. Do not apply any SQL, migrations, imports, updates, or deletes to it.
- Seed scripts in this folder are additive and idempotent. They use `INSERT ... ON CONFLICT DO NOTHING` and do not overwrite existing rows.
- Never commit Supabase secret/service-role keys, database passwords, or user credentials.

## Seed files

- `seeds/001_role_catalogue.sql`: baseline bilingual role catalogue. Only the weather observer role is self-requestable. Elevated roles must be granted through an authorized approval workflow.

Apply seed scripts only to the new project after checking the active project reference. Verify inserted rows with a SELECT query.
