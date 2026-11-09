# Service-role path inventory (Backend)

**Finding:** After validating the user JWT and station permission in ASP.NET, most data-plane calls to PostgREST/RPC use `Supabase:ServiceRoleKey` from **server configuration only**.

## Why this exists

- Deny direct client access to operational tables (migrations revoke `anon`/`authenticated`).
- Keep a single enforcement point in the API for station scope and SoD rules.

## Residual risk

If the service role key is leaked, or a new endpoint forgets `RequireStationPermission`, the database will not enforce end-user station isolation by itself for those service-role calls.

## Target hardening (requires approved SQL + code changes)

1. Prefer user-JWT / narrow DB role for read paths where RLS can express station scope.
2. Keep service role for privileged RPCs that already embed `p_user_id` checks and audit.
3. Expand automated tests that fail closed when station permission is missing.
4. Never place service role in Angular, Flutter, or public repos.

## Client rules (already documented in apps)

- Flutter/Angular: API base URL + anon key for Auth only.
- All operational writes/reads go through Metra.Api with the user bearer token.
