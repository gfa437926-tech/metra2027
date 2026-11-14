# Supabase Auth user transfer — controlled recreation, not SQL copying

## Current transfer-pack boundary

The automated transfer pack exports application-owned public/private schema/data. It does not export or import auth.users, auth.identities, password hashes, sessions, refresh tokens, MFA factors, JWT secrets, or Supabase project keys.

Do not use generic pg_dump/psql copying of the managed auth schema as a production migration method. Copying internal Auth tables can create inconsistent identities, credentials, sessions, or references and is not covered by this pack's tests.

## Evidence captured by source export

The encrypted export includes 04_auth_user_fk_inventory.txt. It lists application foreign-key constraints that reference auth.users. It is part of SHA256SUMS.

The inventory identifies declared foreign keys only. It does not find unconstrained UUID columns, external identity-provider mappings, or IDs stored inside JSON/text payloads; those require a separate schema/application audit.

## Supported migration path for this project

1. Create the target Supabase project and configure its Auth providers, site URL, redirect allow-list, SMTP, and rate limits independently.
2. Create replacement users on the target through the Supabase Dashboard or Auth Admin API, or invite users to register again.
3. Create a protected CSV mapping file with exactly these headers: `source_user_id,target_user_id`. Use canonical UUIDs, one row per source user, unique target UUIDs, and file mode `0600`. Store it outside Git.
4. Set `METRA_AUTH_USER_MAPPING_FILE` to that file before running `04_import_data.sh`. The importer verifies every mapped target UUID exists in target `auth.users`.
5. The `remap_auth_user_ids.py` step rewrites only columns explicitly listed by the exported FK inventory and only inside pg_dump `COPY` blocks. It fails if a declared column is missing, a non-null source UUID has no mapping, a mapping is duplicated, or a value is not a UUID.
6. Audit application-owned references not represented by foreign keys, including JSON claims and metadata, before cutover. These are not automatically rewritten.
7. Require users to establish/reset credentials through target Auth flows. Do not copy password hashes or claim password continuity unless a separately approved, Supabase-supported procedure is documented and tested.
8. Verify target login, email verification, password recovery, role resolution, station scope, and RLS with dedicated test accounts.
9. Revoke/delete temporary migration credentials and securely destroy the mapping file after the approved retention period.

## Mapping CSV example

```csv
source_user_id,target_user_id
11111111-1111-4111-8111-111111111111,22222222-2222-4222-8222-222222222222
```

Protect it with `chmod 600 /secure/path/auth-user-map.csv` and set `METRA_AUTH_USER_MAPPING_FILE` to that path. Never commit it.

## Current status

- Auth users exported/imported automatically: NOT IMPLEMENTED; target users must be recreated through supported Auth flows.
- Auth FK inventory: implemented as a machine-readable JSON-lines export and included in SHA256SUMS; not yet run against the hosted source.
- Auth UUID remapper: implemented for declared FK columns in plain pg_dump COPY data; unit tests added but latest CI result is pending.
- Target UUID existence check: implemented in `04_import_data.sh`; not run against a real target.
- Unconstrained UUID/JSON references: manual audit still required.
- Target Auth smoke test: NOT EXECUTED; target project has not been supplied.
