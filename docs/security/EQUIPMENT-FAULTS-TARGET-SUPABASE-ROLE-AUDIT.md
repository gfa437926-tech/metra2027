# Equipment Faults — Target Supabase Role Audit

**Audit date:** 2026-11-08  
**Target:** `tbdnklyxjvbrilvnwgmq` (`metra2027-angular`)  
**Method:** read-only PostgreSQL catalog queries and Supabase Security Advisor  
**Execution status:** no SQL writes, DDL, grants, migrations, RPCs, or configuration changes were performed.

## 1. Decision

**Path B is technically feasible, but it is not safe to implement against the current role wiring yet.**

The project already contains a promising dedicated role, `metra_api_runtime`, but it is not currently a usable PostgREST execution role for the proposed Equipment Faults routine:
- It is `NOLOGIN`, `NOBYPASSRLS`, not superuser, and cannot create roles.
- It currently has read-only table grants on a limited set of METRA tables, plus EXECUTE on two private registration routines.
- It has no EXECUTE privilege on any Equipment Faults routine (none exists yet).
- The role-membership catalogue shows `authenticator` is a member of `anon`, `authenticated`, and `service_role`, but not `metra_api_runtime`. Therefore the current PostgREST role-switch path cannot assume `metra_api_runtime` without an explicitly reviewed membership/configuration design.

Do **not** use `service_role` as the intended least-privilege identity for this routine. It has `BYPASSRLS` and broad direct privileges across the current `public` METRA tables, including INSERT, UPDATE, DELETE, and TRUNCATE on many tables. A narrow function grant does not remove those direct capabilities.

## 2. Verified role facts

| Role | Login | BYPASSRLS | Observed purpose / risk |
|---|---:|---:|---|
| `metra_api_runtime` | No | No | Dedicated least-privilege candidate; currently read-only on its granted tables |
| `service_role` | No | Yes | Broad privileged API role; unsuitable as the isolation boundary for Equipment Faults |
| `authenticated` | No | No | Client role; no direct grants observed on the current public METRA tables |
| `anon` | No | No | Client role; no direct grants observed on the current public METRA tables |
| `postgres` | Yes | Yes | Owns current application tables and existing METRA SECURITY DEFINER functions; must not be the owner of a new narrowly scoped definer routine |

The `metra_api_runtime` role has SELECT grants on a limited set of METRA directory/authorization tables. It does not currently have direct privileges to mutate application tables. The catalog also reports it can execute the existing private registration submission/review routines.

## 3. Existing database posture relevant to this feature

- No `equipment_faults` or `equipment_fault_audit` table was present in the audited `public` table catalogue.
- No Equipment Faults RPC/function was present.
- Existing public METRA tables had RLS enabled. Several have explicit deny policies for `anon` and `authenticated`; selected directory tables have read policies for `metra_api_runtime`.
- The existing observation audit table has both RLS enabled and FORCE RLS, with a client-deny policy.
- Default privileges for objects created in `public` by `postgres` currently include broad grants to `anon`, `authenticated`, and `service_role` for tables, functions, and sequences. This must be treated as a separate exposure risk: a new function/table must not inherit these defaults unintentionally.
- The Security Advisor returned one informational finding: `metra_migration.legacy_users_staging` has RLS enabled but no policies. This is outside Equipment Faults and was not changed.

## 4. Implications for the atomic transition routine

The schema proposal correctly requires one atomic operation for the fault update plus audit append. The safest preferred shape remains a narrow routine in an intentionally exposed API schema, executed with **SECURITY INVOKER** as `metra_api_runtime`, not as `service_role` and not as `postgres`.

Before this can work, a reviewed design must settle all of the following:

1. How the .NET backend's PostgREST request is authenticated and how it assumes the `metra_api_runtime` role. The current catalogue does not show `authenticator` membership in that role.
2. Which schema PostgREST exposes for the RPC. The current audit could not conclusively read the hosted Data API exposed-schema configuration from PostgreSQL catalog settings.
3. Exact minimum EXECUTE privilege for the routine and minimum underlying UPDATE/INSERT privileges required by an invoker routine.
4. Matching RLS policies for `metra_api_runtime` on the two Equipment Faults tables, with station and status predicates enforced in the database transaction.
5. Explicit revocation of inherited/default PUBLIC, anon, and authenticated EXECUTE/table privileges for the new objects, plus safe default privileges for future objects. Do not apply a blanket revoke to existing project objects as part of this feature without a separate impact review.
6. Audit immutability enforced by database privileges and a trigger/constraint strategy; the runtime role must not gain UPDATE/DELETE/TRUNCATE on the audit table.
7. Proof that the .NET service cannot fall back to `service_role` for this feature and that the RPC derives actor identity from trusted backend context, not caller-controlled request fields.

If SECURITY INVOKER cannot satisfy the atomic write with the intended runtime role, prefer the separately reviewed restricted direct-PostgreSQL role path (Option A) over elevating `service_role`. A SECURITY DEFINER alternative is not approved by this audit; if ever proposed, it needs a dedicated non-login, non-BYPASSRLS owner with narrowly granted table rights, fixed safe search_path, schema-qualified objects, no dynamic SQL, and an explicit function-body authorization review.

## 5. Important distinction: current capability vs future design

The database has a least-privilege role candidate, but the existing `metra_api_runtime` role is not yet wired to execute a new PostgREST routine. The existing service's PostgREST credential/role-switch behavior and the hosted exposed-schema configuration still need independent verification. Therefore this audit does not certify that Path B can be enabled immediately.

## 6. Non-actions

This was a read-only audit. No database objects, role memberships, grants, policies, settings, or data were changed. The legacy database was not accessed.
