# METRA 2027 — Selected Supabase Target Project

Status: target project identified and inspected read-only on 2026-11-02. This document does not authorize schema changes or production cutover.

## Selected target

| Property | Verified value |
|---|---|
| Supabase project ref | `tbdnklyxjvbrilvnwgmq` |
| Project name | `metra2027-angular` |
| Project status | `ACTIVE_HEALTHY` |
| Region | `eu-west-2` |
| Database engine | PostgreSQL 17 |
| Project API URL | `https://tbdnklyxjvbrilvnwgmq.supabase.co` |

The user explicitly identified this project as the database target for METRA 2027. Supabase Auth is now the recommended identity provider after inspecting the managed Auth subsystem; this remains a recommendation pending Auth settings and signing-key review.

## Read-only inspection findings

The following were checked using Supabase project metadata, schema inspection, migration listing, and project advisors:

- No application base tables exist in the `public` schema at inspection time.
- No application views exist in `public`.
- No RLS policies exist in `public`, because there are no application tables yet.
- No migrations are recorded in the Supabase migration history.
- The Supabase-managed `auth` and `storage` schemas exist; they are platform schemas and must not be treated as METRA application-owned schema.
- The Supabase `auth.users` table has UUID primary key `id`; this is the identity-provider account identifier, not yet an approved METRA application account model.
- Security and performance advisor queries returned no lint findings at inspection time. This is not a penetration test, a complete security assessment, or proof that a future schema will be secure.

## Architecture decision

- Supabase PostgreSQL is the selected target for METRA application persistence.
- Angular and Flutter must continue to call the versioned ASP.NET Core API. They must not connect directly to PostgreSQL or use a privileged Supabase key.
- The API will own business authorization, transaction orchestration and audit semantics.
- The API's database connection string must be supplied at deployment through a managed secret named/configured as `ConnectionStrings__MetraDatabase`; never commit it, print it, or place it in frontend environment files.
- Use a dedicated least-privilege runtime database role, separate from the schema migration/owner role. Do not use a Supabase service-role key as a substitute for database least privilege.
- Schema changes must be versioned as reviewed migrations and applied deliberately. Do not run ad-hoc DDL in production.
- RLS is required as defense in depth for any exposed application tables, but it does not replace API authorization. Prefer keeping privileged application tables outside exposed schemas where practical; if tables are exposed through the Data API, enable and test RLS before granting client access.
- No browser or mobile client may receive a database password, direct Postgres connection string, service-role key, or other privileged credential.

## Still requiring explicit design approval

1. Supabase Auth is now the recommended identity provider. Confirm its enabled providers, signing-key state, issuer/audience and session/security settings before production activation. See IDENTITY-PROVIDER-DECISION.md.
2. The canonical METRA account/profile model and relationship to `auth.users.id` (if Supabase Auth is selected).
3. Account state, station assignments, canonical role/permission catalogue, registration and approval lifecycle.
4. Database runtime role, grants, network restrictions, secret delivery and migration ownership.
5. Audit retention, immutable/append-only enforcement, backup and restore procedures.
6. Identity-subject protection and encryption/key-management approach.
7. Whether to create a separate Supabase development branch/project for migration and integration testing.

## Scope and safety

This was a read-only inspection. No tables, columns, policies, grants, users, Auth settings, secrets, keys, migrations, functions, or deployment settings were changed. No legacy user data was queried or migrated. The selected project is not yet connected to the application runtime, and no production persistence adapter exists.
