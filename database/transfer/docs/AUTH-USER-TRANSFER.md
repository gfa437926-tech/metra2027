# Supabase Auth users — current zero-user boundary and future handling

## Current source evidence and export guard

The approved experimental source project is `tbdnklyxjvbrilvnwgmq`.

The latest read-only inspection returned:

- `auth.users`: **0 rows**.
- Application foreign-key inventory: exported separately as JSON-lines metadata; it lists declared constraints referencing `auth.users`.
- The export script performs its own `SELECT count(*) FROM auth.users` check and **refuses to export if the count is non-zero**.
- The manifest must contain `auth_user_count=0` and `auth_users_exported=false`; both import scripts verify these assertions.

No Auth users, identities, password hashes, sessions, refresh tokens, MFA factors, JWT secrets, or Supabase project keys are copied by this transfer pack.

## What is and is not implemented

- Auth user export/import: **not implemented and intentionally disabled**.
- Auth FK inventory: implemented and included in the encrypted export package checksums.
- `remap_auth_user_ids.py`: a standalone, unit-tested utility only. It is **not called by `04_import_data.sh`** and must not be used unless a separate Auth migration is approved.
- Unconstrained UUIDs and IDs embedded in JSON/text: not covered by the FK inventory and require a separate application/schema audit if source users ever exist.
- Target Auth setup and login smoke tests: not executed because the target project has not been supplied.

## If source Auth users appear in a future snapshot

The transfer script will stop before exporting. Do not bypass the guard or copy managed `auth.*` tables with generic pg_dump/psql.

A separate approved migration plan must then:

1. Inventory all declared and undeclared application references to source user UUIDs.
2. Create replacement accounts through supported Supabase Auth Dashboard/Admin API flows on the target.
3. Generate a protected source-to-target UUID mapping outside Git.
4. Rewrite only reviewed application references in a controlled, tested import path.
5. Require users to establish/reset credentials through target Auth flows.
6. Verify login, email verification, recovery, role resolution, station scope, and RLS using dedicated test accounts.
7. Destroy temporary mapping material after the approved retention period.

Do not copy password hashes, active sessions, refresh tokens, MFA secrets, JWT secrets, or project keys. Do not claim password continuity without a separately approved and supported procedure.

## Acceptance rule

For this transfer package, the only accepted source Auth state is zero users. A non-zero count is a hard stop and requires a new explicit decision; it is not an automatic fallback to the standalone remapper.
