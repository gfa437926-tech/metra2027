# SQL / migration review package (read-only — not applied)

**Repository tip at authorship:** `work/legacy-ui-migration-audit`  
**Rule:** Do **not** apply any statement in this package to Supabase or any database until the owner explicitly approves.

## 1. Target environment

- Intended Supabase project (from repo docs): `https://tbdnklyxjvbrilvnwgmq.supabase.co`
- **Out of scope:** legacy/old METRA database (no connect, no migrate, no import)

## 2. Migration sets present in the repository

### A) `supabase/migrations` (operational observations / faults / support)

| File | Intent (from file contents) |
|---|---|
| `20261103164003_create_operational_observation_submission.sql` | Observations + audit tables; revoke client roles; service_role grants |
| `20261103164045_deny_client_access_to_operational_observations.sql` | Extra client deny |
| `20261103164638_index_operational_observation_foreign_keys.sql` | Indexes |
| `20261103215400_observation_review_decision.sql` | Decision RPC |
| `20261103220500_harden_observation_decision_null_validation.sql` | Null hardening |
| `20261107020000_harden_observation_decision_sod_and_audit.sql` | Separation of duties + audit |
| `20261107021500_observation_resubmit_after_return.sql` | Resubmit after return |
| `20261107030000_equipment_faults_station_scoped.sql` | Equipment faults + audit |
| `20261107031000_support_incidents_station_scoped.sql` | Support incidents + audit |
| `20261107032000_harden_ops_rls_and_assignee_checks.sql` | RLS / assignee checks |
| `20261108010000_metra_ops_runtime_role_and_fault_read.sql` | Ops runtime role |
| `20261108020000_npgsql_ops_session_context_rls.sql` | Npgsql session context RLS |

### B) `database/migrations` (authority / station / registration lifecycle)

Numbered `003`–`029` style scripts for permission RPCs, registration, assignment, authority access, audit binding, and related hardening. Test bootstrap helpers live under `database/bootstrap/` and are **not** production apply scripts by themselves.

## 3. Security model observed in SQL + API

1. Operational tables often **revoke** direct `anon` / `authenticated` access.
2. Many RPCs are granted to **`service_role`** only.
3. ASP.NET validates **JWT** then **station permission**, then calls PostgREST/RPC with **server-side service role**.
4. Residual risk: leaked service role or a new endpoint missing `RequireStationPermission` bypasses end-user RLS.

## 4. Explicit open questions for the owner (approval gates)

1. **Apply order** on the new Supabase project: confirm which migrations are already applied vs pending (live schema not verified from Git alone).
2. **`legacy_users_staging` (reported ~160 rows):** not defined in these migration files — confirm origin; keep isolated until a written decision (archive / delete / ignore).
3. **Service-role reduction plan:** approve whether phase-2 moves read paths to user JWT + RLS, or keeps API-enforced service role with expanded tests only.
4. **Npgsql `MetraOps` role:** approve creation of limited DB role and connection string storage in host secrets only (never in client apps).

## 5. Recommended apply procedure (only after approval)

1. Snapshot / backup of the **new** project only.
2. Dry-run on a disposable branch database or local Postgres with the same scripts.
3. Apply in filename order; record each success/failure.
4. Run repository `database/tests` scripts against an **isolated** test database (not production data).
5. Re-run Backend readiness (`/api/v1/ready`) with MetraOps configured if ops path is enabled.

## 6. What this package does **not** authorize

- Touching the old database
- Importing legacy stations
- Merging PR #11 / #12
- Changing production secrets in chat
