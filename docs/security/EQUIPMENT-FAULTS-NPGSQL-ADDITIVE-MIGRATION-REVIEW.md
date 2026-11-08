# Equipment Faults — Additive Npgsql Schema and Runtime Role Review

**Status:** draft for operator review; not applied to Supabase.  
**Target:** `tbdnklyxjvbrilvnwgmq` only.  
**Branch:** `work/equipment-fault-domain`.

## Findings from read-only inspection

- `public.station_catalogue.id` is UUID and is the approved FK target. Existing station data remains untouched.
- `public.equipment_faults` and `public.equipment_fault_audit` did not exist in the inspected schema.
- Existing public tables have RLS enabled. Existing client policies deny `anon` and `authenticated` access on sensitive METRA tables.
- `metra_api_runtime` is `NOLOGIN`, `NOBYPASSRLS`, `NOSUPERUSER`, `INHERIT`; it currently has SELECT grants on the reviewed read models/catalogue tables and no membership grant was returned. It is not a usable Npgsql login.
- The feature therefore uses separate roles: `metra_equipment_faults_runtime` (NOLOGIN, NOBYPASSRLS) and `metra_equipment_faults_login` (LOGIN, NOINHERIT, NOBYPASSRLS) with SET ROLE membership. The login receives no password in SQL; its credential must be set out-of-band and stored in the API secret manager. It is never a member of `service_role`.
- This role split avoids broadening `metra_api_runtime` and avoids giving the fault feature access to unrelated METRA tables.

## Proposed objects

1. `equipment_faults`: current state, reporter, severity, station FK, occurrence time, and optimistic version.
2. `equipment_fault_audit`: append-only event history with composite FK `(fault_id, station_id)` to prevent station mismatch.
3. Database guard triggers enforce the existing transition graph and immutable fault identity.
4. An AFTER trigger appends audit entries in the same transaction as create/status change; any audit failure rolls back the state change.
5. Both tables use ENABLE + FORCE RLS. The feature runtime policies require transaction-local `metra.actor_id` and `metra.station_id`; audit writes additionally require actor equality.
6. Client roles are explicitly denied. Runtime receives only required column/table grants. No DELETE/TRUNCATE privilege is granted.

## Runtime privilege matrix

| Principal | Login | RLS bypass | Faults | Audit | Other METRA tables |
|---|---:|---:|---|---|---|
| `metra_equipment_faults_login` | Yes, password set externally | No | No direct table grants; SET ROLE only | No direct grants | None |
| `metra_equipment_faults_runtime` | No | No | SELECT, INSERT limited columns, UPDATE(status) | INSERT only | None |
| `metra_api_runtime` | No | No | No grants | No grants | Existing grants unchanged |
| `anon`, `authenticated` | Platform roles | No | Denied by RLS and grants | Denied by RLS and grants | Existing policies unchanged |

The role login must be provisioned with a managed secret after migration; no password, JWT signing secret, or service-role key is embedded in SQL or repository files.

## Transaction contract for Npgsql adapter

For each call:
1. Open a connection using the dedicated feature login and verified TLS.
2. Begin a transaction.
3. Execute `SET LOCAL ROLE metra_equipment_faults_runtime`.
4. Set transaction-local context using parameterized `set_config('metra.actor_id', ... , true)`, `set_config('metra.station_id', ... , true)`, and `set_config('metra.reason', ... , true)`.
5. Query/update only with parameterized SQL. The transition writer locks the scoped row, compares expected state, changes status, and commits. The trigger inserts audit in the same transaction.
6. Roll back on any exception. Never set context session-wide; this is mandatory for pooled-connection safety.

Custom GUC values are API-to-database trust assertions, not cryptographic identity. The API host and dedicated database credential remain the trust boundary. The API must derive actor UUID from the validated ES256/HS256 Auth principal and station authorization from the trusted METRA authorization service.

## Important deployment prerequisite

The SQL creates a LOGIN role without a password. Before Npgsql can connect, an administrator must provision its password out-of-band (never in Git, chat, migration SQL, logs, or client configuration), store it in the server secret manager, and configure the dedicated connection string. The application must fail readiness if the secret/connection is absent.

## Rollback

Use `supabase/rollback/20261108060000_disable_equipment_faults_runtime.sql`. It revokes runtime membership and grants but deliberately preserves all feature data and schema. Full object removal is a separate destructive operation and requires a verified export and explicit approval.

## Review notes / unresolved before applying

- The migration is additive and does not update existing METRA tables or rows.
- The SQL has not been applied. A final review and PostgreSQL integration run are required before production execution.
- The current RLS policy uses transaction-local station/actor context; the adapter must set both on every transaction and must never accept actor identity from a request body.
- The Npgsql adapter and real PostgreSQL Testcontainers suite remain implementation work; this review artifact does not claim they are complete.
