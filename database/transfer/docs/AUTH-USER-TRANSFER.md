# Transferring experimental Auth users (Supabase)

## Constraints

Supabase Auth stores users in `auth.users` with **hashed passwords**. You must not:

- Export or reuse the source project JWT secret on the target.
- Copy active refresh tokens / sessions as a substitute for proper login.
- Paste service role keys or DB passwords into chat or git.

## Recommended approaches (pick one)

### A) Dashboard / Admin API recreate (few test users)

1. On the **target** project, create users via Auth Admin API or Dashboard.
2. Issue temporary passwords; force reset on first login.
3. Re-map `auth.users.id` only if application FKs require identical UUIDs — otherwise update `public` FK columns to the new ids after import.

### B) SQL dump of `auth.users` + `auth.identities` (lab only)

Requires source DB password and sufficient privilege:

```bash
pg_dump "$METRA_SRC_DATABASE_URL" --data-only --schema=auth \
  --table=auth.users --table=auth.identities \
  --file=auth_users_data.sql
```

Import into target only after Auth schema exists. Then:

- Rotate all sessions (truncate `auth.sessions` / refresh tokens on target).
- Confirm email provider / redirect URLs are **target** settings.
- Application uses **new** anon and service_role keys from the target project only.

Identical UUIDs preserve `permission_grants` / assignments FKs that reference `auth.users.id`.

### C) No users (schema + catalogue only)

Valid if the target is a clean staging schema test. Public catalogue data can still be imported without Auth rows.

## After transfer

- [ ] Login with one experimental account on **target** URL works.
- [ ] JWT `iss` matches target Auth URL.
- [ ] Flutter / .NET point to target `Supabase__Url` and keys.
- [ ] Source project remains intact until restore drill succeeds.
