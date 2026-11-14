# METRA 2027 — Database advisor remediation proposal

- Source project: `tbdnklyxjvbrilvnwgmq`
- Snapshot: 2026-11-14
- Status: **proposal only — no SQL below has been applied**
- Change boundary: do not execute against the hosted experimental source until the schema review and owner approval are complete. Prefer applying reviewed changes to the new target project before application cutover.

## 1. Pin search paths on two trigger functions

Supabase Security Advisor reports mutable search paths for these functions:

- `public.reject_metra_equipment_fault_audit_mutation()`
- `public.reject_metra_support_incident_audit_mutation()`

Read-only inspection confirms both are SECURITY INVOKER trigger functions whose bodies only raise an exception; they do not query tables or call unqualified application objects.

The target transfer pack now applies the following hardening in `apply_runtime_grants.sql` and verifies it with `assert_target_function_search_path.sql`. The experimental source remains unchanged.

```sql
ALTER FUNCTION public.reject_metra_equipment_fault_audit_mutation()
  SET search_path = pg_catalog;

ALTER FUNCTION public.reject_metra_support_incident_audit_mutation()
  SET search_path = pg_catalog;
```

After applying to an approved target, verify `pg_proc.proconfig` contains the pinned search path and rerun Supabase Security Advisors.

## 2. Add indexes for 10 uncovered foreign keys

The Performance Advisor identified these foreign keys without a covering index:

```sql
CREATE INDEX IF NOT EXISTS metra_equipment_fault_audit_events_actor_user_id_idx
  ON public.metra_equipment_fault_audit_events (actor_user_id);
CREATE INDEX IF NOT EXISTS metra_equipment_fault_audit_events_fault_id_idx
  ON public.metra_equipment_fault_audit_events (fault_id);
CREATE INDEX IF NOT EXISTS metra_equipment_fault_audit_events_station_id_idx
  ON public.metra_equipment_fault_audit_events (station_id);

CREATE INDEX IF NOT EXISTS metra_equipment_faults_assigned_to_idx
  ON public.metra_equipment_faults (assigned_to);
CREATE INDEX IF NOT EXISTS metra_equipment_faults_reporter_user_id_idx
  ON public.metra_equipment_faults (reporter_user_id);

CREATE INDEX IF NOT EXISTS metra_support_incident_audit_events_actor_user_id_idx
  ON public.metra_support_incident_audit_events (actor_user_id);
CREATE INDEX IF NOT EXISTS metra_support_incident_audit_events_incident_id_idx
  ON public.metra_support_incident_audit_events (incident_id);
CREATE INDEX IF NOT EXISTS metra_support_incident_audit_events_station_id_idx
  ON public.metra_support_incident_audit_events (station_id);

CREATE INDEX IF NOT EXISTS metra_support_incidents_assigned_to_idx
  ON public.metra_support_incidents (assigned_to);
CREATE INDEX IF NOT EXISTS metra_support_incidents_reporter_user_id_idx
  ON public.metra_support_incidents (reporter_user_id);
```

Existing composite indexes already cover `station_id` on `metra_equipment_faults` and `metra_support_incidents`, so the advisor did not report those two FKs.

After applying, verify each FK has a covering index and rerun Performance Advisors. These indexes are proposed based on FK coverage; confirm query patterns and write overhead before adding them to the final migration.

## 3. Tighten the source's broad default ACLs on the target

Read-only inspection found that source defaults for objects created by `postgres` in `public` grant ALL table and sequence privileges and function EXECUTE to `anon`, `authenticated`, and `service_role`. This is broader than the target's server-only data-access design.

The transfer scripts now intentionally diverge from those source defaults:

- `PUBLIC`, `anon`, and `authenticated` receive no default privileges on future public tables, sequences, or functions.
- `service_role` receives the required default privileges.
- Existing application-object grants are restored explicitly and checked with `compare_acl_inventory_acceptance.sql`.
- `assert_target_default_acl.sql` blocks restore acceptance if client roles regain implicit default privileges.

This hardening is target-only. The experimental source defaults remain unchanged. The target also restricts future private-schema function execution to `metra_api_runtime`. Review any future direct PostgREST/RPC access requirement before adding explicit grants.

## 4. RLS findings — preserve the current default-deny behavior

The following four public tables have RLS enabled but no policies:

- `metra_equipment_fault_audit_events`
- `metra_equipment_faults`
- `metra_support_incident_audit_events`
- `metra_support_incidents`

Read-only grant inspection found no `anon` or `authenticated` table grants on these four tables; only `postgres` and `service_role` had table privileges. Keep the default-deny posture until the .NET API access model is reviewed. Do not add permissive browser policies just to silence the advisor.

`metra_migration.legacy_users_staging` also has RLS enabled and no policies. It is outside the transfer pack's `public/private` export scope and must remain excluded.

## 5. Do not drop the 46 unused indexes from this snapshot

The project currently has no Auth users, no operational observations, and very few rows in most application tables. The 46 unused-index notices are not evidence that the indexes are unnecessary. Reassess after realistic workload and query telemetry exist.

## 6. Approval and verification gates

1. Review this proposal against the actual migration history and API query patterns.
2. Generate a proper Supabase migration using the supported CLI workflow; do not apply ad-hoc SQL from this document.
3. Apply only to an explicitly identified new target after it exists and has passed the transfer preflight.
4. Run SQL tests, Supabase Security/Performance Advisors, and application smoke tests.
5. Do not apply these changes to the experimental source or any legacy METRA database without separate explicit approval.
