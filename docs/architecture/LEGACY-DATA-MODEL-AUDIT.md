# Legacy Data Model Audit — METRA 2027

**Status:** Code-derived audit supplemented by a separate read-only live schema review; not a target schema proposal  
**Branch:** `work/identity-migration-audit`  
**Scope:** Repository source inspection. Live legacy Supabase metadata and aggregate counts are documented separately in `LEGACY-SUPABASE-READ-ONLY-REVIEW.md`. No database, Auth, RLS, policy, or user data was changed.

## 1. Evidence standard

This document records table names, columns, and operations explicitly referenced by repository code. A Supabase `.from("table")` call proves only that the client code expects that table name. It does **not** prove that the table exists in the connected project, that the listed columns are current, or that any particular type, nullability, default, primary key, foreign key, unique constraint, index, trigger, grant, or RLS policy exists.

A recursive repository tree inspection found no SQL schema, SQL dump, Supabase migrations directory, or Supabase CLI project configuration. The only Supabase configuration files found are client configuration files. Therefore, the actual database schema remains unverified.

## 2. Identity and registration data

### `users` — observed columns

| Column | Evidence/use in code | Notes |
|---|---|---|
| `id` | filters, joins-by-reference, inserted ID | Type and identity generation unknown |
| `first_name`, `father_name`, `last_name` | registration, profile display, admin listing | Original profile labels retained |
| `email` | login lookup, duplicate check, profile | Uniqueness is assumed by UI but not verified |
| `phone` | registration, recovery lookup, profile | Format/uniqueness unknown |
| `station` | registration, station scope, manager lookup | Free-text value in legacy code; no verified station FK |
| `role` | redirects, manager lookup, admin filters | Free-text Arabic labels; canonical catalogue unresolved |
| `password_hash` | browser login verification and admin provisioning | Legacy custom password storage; do not migrate into a new client-side auth design |
| `status` | login gate, active/approved filters | Values observed include `active`, `approved`, `pending`; full state machine unknown |
| `approved_by_station_manager` | login gate | Boolean-like field read; write path not established by this audit |
| `approved_by_system_manager` | login gate | Boolean-like field read; write path not established by this audit |
| `last_login` | login metadata update | Timestamp format inferred from ISO string |
| `login_count` | increment on login | Numeric semantics/default unknown |
| `updated_at`, `created_at` | updates and ordering | Defaults/triggers unknown |
| `notes` | admin UI fallback/display | Persistence path/type unknown |
| `full_name`, `department` | alternate profile reader in `user-manager.js` | Compatibility assumptions; not aligned with registration fields |

**Observed operations:** select by `email` or `id`; select all; update login metadata; insert and update from admin UI; delete by `id`; filter by `status`, `station`, and `role`. Some UI paths select `*`, so the actual set of consumed columns may be larger than the explicit projection list.

**Important inconsistency:** `login.js` verifies a locally stored `password_hash` in the `users` row, while `user-manager.js` also calls Supabase Auth `auth.getUser()` and then looks up `users.id = auth user.id`. The repository does not establish a reliable identity mapping between these two models.

### `registration_queue` — observed columns

| Column | Evidence/use in code |
|---|---|
| `id` | selected after insert; filtered for update |
| `first_name`, `father_name`, `last_name` | copied from registration request |
| `email`, `phone` | duplicate checks and admin display |
| `station`, `role` | requested assignment |
| `password_hash` | copied from legacy registration flow |
| `program_password` | written by legacy registration form |
| `agreed_to_terms` | written as true |
| `status` | values observed: `pending`, `approved`, `rejected` |
| `created_at`, `updated_at` | creation and update timestamps |
| `approved_by_station_at`, `approved_by_system_at` | shown in demo data / system approval update |
| `user_id` | set after account creation |
| `rejected_at`, `rejection_reason` | rejection update |
| `station_manager_name`, `station_manager_email` | demo/UI fields; not verified as persisted |

**Observed operations:** duplicate lookup by email, insert, list pending, update to approved/rejected, and link to created user via `user_id`.

**Workflow concern:** registration UI describes two approvals (station manager then system manager), but the inspected system approval handler creates a user and updates the request to approved. The repository evidence does not prove an atomic transaction across those operations. A failed queue update can leave a created user with a request that remains pending. A fallback branch also fabricates a default password hash string if the request lacks one; this is unsafe and must not be carried forward.

## 3. Other tables referenced by the legacy application

These are additional observed table names, not a verified inventory of tables in Supabase.

| Table | Columns explicitly referenced or written | Evidence notes |
|---|---|---|
| `hourly_reports` | `created_at`, `station_name` | Admin statistics and station/report views; other code selects `*` |
| `daily_reports` | `submission_date` | Date-filtered dashboard read |
| `climate_reports` | `created_at` | Date-filtered dashboard read |
| `climate_hourly_reports` | dynamic statistics table name | Separate from `climate_reports`; relationship unknown |
| `rainfall_reports` | `created_at` | Date-filtered dashboard read |
| `weather_phenomena` | `created_at` | Date-filtered dashboard read |
| `agricultural_reports` | `created_at` | Date-filtered dashboard read |
| `soil_temperatures` | `submitted_at`; config connectivity probe selects `count` | Other clients may use additional columns |
| `equipment_failures` | `created_at`, `station_name`, `equipment_type`, `failure_description`, `failure_date`, `failure_severity`, `status`, `urgency_level` | Workshop UI reads, inserts/updates/deletes |
| `telecom_failures` | `id`, `device_type`, `problem_type`, `description`, `urgent`, `station`, `reporter_name`, `reporter_id`, `reporter_email`, `reporter_phone`, `reporter_station`, `reporter_role`, `status`, `created_at`, `updated_at`, `technician_notes` plus device-specific fields | Database manager inserts, reads, updates, exports; telecom UI also deletes and inserts |
| `it_problem_reports` | `created_at`, `reporter_name`, `station_name`, `bulletin_type`, `problem_type`, `problem_description`, `status` | Admin and IT manager reads |
| `reminders` | `station_name`, `title`, `message`, `priority`, `status`, `send_at` | Management dashboard read |
| `whatsapp_reminders` | `sent_at` | Insert/read operations in management dashboard |
| `activity_log` | `user_name`, `action_type`, `action_details`, `created_at` | Read and insert operations |
| `user_messages` | `user_id`, `message`, `created_at` | Read operations |
| `system_stats` | `date`, `total_users`, `active_users`, `pending_requests`, `sent_reports`, `errors_count` | Read and ordering by date |
| `system_backups` | `backup_name`, `backup_type`, `data_count`, `created_at` | Read and ordering |
| `sms` | `recipient`, `message`, `status`, `created_at`, `id` | Read; resend/test UI actions are simulations |
 
The telecom report code has inconsistent naming: `database.js` writes `station` and reporter contact fields, while dashboard rendering expects `reporter_station`; another UI constructs `reporter_station` and `reporter_role`. Device detail fields are stored as separate type-specific columns in one path but as `device_data` in another. This requires reconciliation before migration.

The dashboard dynamically requests counts from several report tables and also uses a table name parameter. Dynamic table names must be allowlisted in a server-side implementation; never accept arbitrary client-supplied table names.

## 4. Security findings and migration blockers

### Critical — service-role credential embedded in browser code

The account-approval path in `manager-dashboard.html` contains a hard-coded Supabase service-role credential and attempts to instantiate a client with it after an ordinary insert fails. A service-role key bypasses RLS and must never be present in browser-delivered code. Treat the credential as compromised: rotate/revoke it in Supabase, remove it from source and deployment artifacts, review access/audit logs for unexpected use, and move privileged account creation to the trusted ASP.NET Core API or a protected server-side function. Do not replace it with another browser secret. This audit intentionally does not reproduce the credential.

### High — browser-side credential and identity model

- Legacy registration stores a custom password hash in `registration_queue`; login reads `password_hash` from `users` and verifies it in browser code.
- Recovery matches email + phone, generates a temporary password in the browser, logs it to console, and displays it to the user. This is not an acceptable recovery design.
- The UI trusts `localStorage.currentUser` for some privileged pages and falls back to fabricated administrator/demo identities in workshop UI.
- Browser role/status checks and RLS assumptions do not replace server-side authorization.
- Do not migrate `program_password`, browser-generated temporary passwords, or the default password fallback.

### High — non-atomic approval and administration

- Account creation and queue update are separate requests; the queue update error is logged but not necessarily rolled back.
- Admin UI directly inserts, updates, and deletes `users`.
- No complete audit trail for approval decisions, actor identity, decision reason, or transition history was verified.
- Station-manager selection uses `.single()`, which assumes exactly one active manager for a station; zero or multiple managers are not handled robustly.

### Data integrity unknowns

No source-level evidence establishes:
- Primary keys, foreign keys, identity types, unique indexes, or email normalization constraints.
- Column types, nullability, defaults, check constraints, generated columns, or enum definitions.
- Cascading delete/update behavior.
- Triggers, stored procedures, scheduled jobs, or transactional guarantees.
- RLS enabled state, policy definitions, grants, exposed schemas, or Data API configuration.
- Whether the tables and columns still exist in the current Supabase project.

## 5. Safe migration approach

1. Obtain a read-only schema export from the project owner/authorized Supabase environment, including columns/types, constraints, indexes, triggers, grants, RLS policies, and relevant Auth configuration. Do not export user row contents for this purpose.
2. Rotate the exposed service-role key before further privileged operations. Remove it from all browser assets and repository history according to the credential incident response process.
3. Build a mapping from legacy `users` and `registration_queue` to separate identity, profile, account status, requested role/station, granted permissions, station assignments, and approval events.
4. Define canonical role and station catalogues from authoritative source records; do not derive IDs or coordinates from free-text labels.
5. Reconcile telecom failure field variants and report table/date-field variants before any ETL.
6. Design idempotent, staged migration with dry-run counts, duplicate handling, referential-integrity checks, rollback plan, and explicit owner sign-off.
7. Keep all client access behind the versioned ASP.NET Core API. The API must derive actor identity from a validated authentication context and enforce role, permission, station scope, and workflow transitions server-side.

## 6. Evidence reviewed

Repository files reviewed for this audit include:
- `database.js`
- `supabase-config.js`
- `login.js`
- `user-manager.js`
- `user-data.js`
- `auth-manager.js`
- `manager-dashboard.html`
- `manag-net.html`
- `it-maneger.html`
- `telecom-manager.html`
- `workshop-manager.html`
- `angular-app/src/app/core/supabase/supabase.config.ts`

The recursive repository tree contained no `.sql` files, SQL dumps, Supabase migrations directory, or Supabase CLI configuration. The Angular Supabase config is blank/environment-driven; the legacy JS config embeds the project URL and public anon key. No live database connection or data query was performed.

## 7. Acceptance criteria for the next phase

- [ ] Service-role key rotated and removed from all browser-delivered assets.
- [ ] Authoritative schema export reviewed without exposing personal row data.
- [ ] Canonical role/station catalogue approved by the domain owner.
- [ ] Legacy table/column mappings reviewed and signed off.
- [ ] Duplicate and orphan records quantified from a controlled read-only migration rehearsal.
- [ ] Registration approval transitions and actor audit requirements formally specified.
- [ ] No production DDL or data migration until a reviewed migration plan is approved.
