# METRA 2027 — Supabase runtime identity security review

**Inspection date:** 2026-11-15  
**Project:** `tbdnklyxjvbrilvnwgmq`  
**Method:** read-only PostgreSQL role/grant/RLS inspection and source review. No database writes or credential changes were performed.

## 1. Verified controls

- All 46 inspected application tables have RLS enabled.
- The checked `anon` and `authenticated` roles have no SELECT, INSERT, UPDATE or DELETE table privileges on those 46 tables.
- The checked `anon` and `authenticated` roles have no EXECUTE privilege on application functions in the inspected domain schemas.
- All 46 application tables are readable by the Supabase `service_role`; this role has `BYPASSRLS=true`.
- Five active Edge Functions were inventoried and each reported `verify_jwt=true`.
- The Security Advisor's 21 `rls_enabled_no_policy` findings are informational. For those tables, RLS is enabled and there is no permissive client policy; the client roles also lack table grants in the inspected privilege matrix.

## 2. Runtime identity gap

The database contains a role named `metra_api_runtime` with:
- `NOLOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`, and no database/role creation privileges.
- 25 application tables with at least one table privilege granted to it.
- No EXECUTE privileges on the inspected application functions.
- No membership relationship with `service_role`, and no membership relationship granting the runtime role through `service_role`.

The .NET API source currently configures multiple Supabase data/authorization services with `Supabase:ServiceRoleKey`, including station authorization, station directory, authority access and observation submission. The service-role key is server-only and is not placed in Flutter, but it authenticates those PostgREST requests as the broad `service_role` identity, which bypasses RLS. The existing `metra_api_runtime` role is not currently the effective API identity and is not ready to replace it as-is.

This is a server trust-boundary risk, not evidence of direct client access. Current endpoints perform application-side authorization and the relevant database RPCs add checks, but a missed or defective server authorization path would execute with the broad service-role capability.

## 3. Unresolved Data API configuration

The read-only database session returned NULL for `pgrst.db_schemas` and `pgrst.db_extra_search_path`. Those session settings do not establish which schemas are exposed in the hosted Supabase Data API. The Dashboard Data API exposed-schema configuration must be checked separately before release.

## 4. Required production decision

Before production:
1. Choose and document the least-privilege API execution model: a properly provisioned non-BYPASSRLS runtime identity, or a narrowly scoped server-only RPC gateway with explicit per-operation authorization and a documented service-role exception boundary.
2. If using `metra_api_runtime`, define its login/credential or trusted role-switching mechanism, exact function EXECUTE grants, table access, RLS policies, and connection behavior. Do not simply grant it service_role membership or enable BYPASSRLS.
3. Ensure the runtime identity can execute only approved RPCs and cannot directly mutate arbitrary scientific/audit tables.
4. Add integration tests proving cross-authority, cross-station, unapproved-account, expired-grant and self-elevation denials against the actual runtime identity.
5. Confirm the Data API exposed schemas and function grants; keep sensitive domain schemas unexposed unless an explicit reviewed requirement exists.
6. Keep service-role credentials in a managed secret store, rotate them, prevent logging, and never ship them to Flutter or public configuration.

## 5. Release gate

The current service-role design may be used only as a controlled server-side development/staging trust boundary. It is not a least-privilege production credential model. No production release should be approved until the runtime identity decision and its integration tests are complete.

This review is observational only. It does not create roles, change grants, alter RLS policies, rotate credentials, or modify the live database.
