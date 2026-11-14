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
3. Use target-generated UUIDs. Create a protected mapping file from source user UUID to target user UUID. Store it outside Git, encrypted, and restrict access to migration operators.
4. Re-map every application FK that references auth.users.id using the reviewed mapping. Do not run broad text replacement or update UUID-looking columns without proving their semantics.
5. Audit application-owned references not represented by foreign keys, including JSON claims and metadata, before cutover.
6. Require users to establish/reset credentials through target Auth flows. Do not copy password hashes or claim password continuity unless a separately approved, Supabase-supported procedure is documented and tested.
7. Verify target login, email verification, password recovery, role resolution, station scope, and RLS with dedicated test accounts.
8. Revoke/delete temporary migration credentials and securely destroy the mapping file after the approved retention period.

## Do not do

- Never copy the source JWT secret, anon/publishable key, service_role/secret key, or active refresh tokens.
- Never paste passwords, database URLs, API keys, or mapping files into chat or Git.
- Never truncate or modify managed auth.sessions / auth.refresh_tokens as a generic migration step.
- Never delete or alter the experimental source project as part of this transfer.

## Current status

- Auth users exported/imported automatically: NOT IMPLEMENTED.
- Auth FK inventory: implemented in the export script; not yet run against the hosted source.
- User UUID mapping and remap SQL: NOT IMPLEMENTED; depends on actual inventory and owner-approved target identity strategy.
- Target Auth smoke test: NOT EXECUTED; target project has not been supplied.
