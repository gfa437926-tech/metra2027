# Identity persistence implementation decision

Status: repository inspection; no production persistence selected or implemented.

## Findings in the current branch

- The API project targets .NET 10 and references ASP.NET Core OpenAPI packages only.
- The API project has no Entity Framework Core, Npgsql, Dapper, or other PostgreSQL client package.
- The test project has no PostgreSQL test container or database integration-test dependency.
- No API `DbContext`, database connection registration, repository adapter, migration directory, or SQL migration convention was found in the backend project.
- The current identity-link implementation is an application service plus an `IIdentityLinkStore` contract and in-memory test doubles. It is not connected to persistence.
- The repository documentation says database integration is planned and that no database schema or Supabase settings are changed by the scaffold.
- The canonical METRA account table and primary key are not established in the inspected backend.

## Decision

Do not add a speculative PostgreSQL adapter or executable migration in this change.

Adding Npgsql/EF Core before the project selects database ownership, canonical account schema, deployment connection management, migration authority, and integration-test environment would create a persistence path that could accidentally become treated as production-ready. A hand-written SQL file with a guessed account foreign key would be similarly unsafe.

The next implementation increment should first establish an explicit persistence decision:
1. Confirm PostgreSQL is the authoritative application database and identify whether it is managed directly or through Supabase.
2. Inspect and approve the existing canonical account schema and primary key.
3. Select the migration mechanism and designate who owns migration execution.
4. Define runtime database roles separately from schema-owner/migration credentials.
5. Decide whether identity subjects are stored as plaintext protected by platform encryption at rest, or envelope-encrypted with a KMS-backed deterministic lookup fingerprint.
6. Provide an isolated PostgreSQL integration-test service in CI.
7. Only then add the concrete adapter, constraints, transaction and append-only audit controls.

## Non-negotiable implementation requirements

- Runtime API database credentials must not own the schema and must not be able to alter migration history.
- Identity linking must re-check active account state inside the transaction.
- Exact issuer+subject uniqueness must be enforced by the database, not just application code.
- Identity-link row and audit event must commit atomically.
- Runtime API role must not update or delete audit rows.
- Only expected uniqueness conflicts may be translated into a safe domain outcome; unrelated database failures must propagate to centralized error handling.
- Tests must exercise concurrent inserts, account suspension races, audit rollback, exact comparison semantics, and least-privilege database grants.

## Scope and limits

This inspection and decision document make no live database connection and change no Supabase project, Auth settings, RLS policies, schema, data, credentials, or deployment configuration. No PostgreSQL adapter or migration is available yet.
