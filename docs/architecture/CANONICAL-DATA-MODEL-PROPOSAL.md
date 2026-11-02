# METRA 2027 — Canonical Data Model Proposal

**Status:** revised logical proposal — Supabase Auth recommendation and two-stage registration selected for implementation planning; not an approved physical schema or executable migration.  
**Target database:** Supabase PostgreSQL project `tbdnklyxjvbrilvnwgmq` (selected by the project owner; inspected read-only).  
**Change scope:** documentation only. No Supabase DDL, data, Auth settings, RLS, grants, keys or secrets are changed by this proposal.

## 1. Purpose and design boundary

This proposal turns the repository's legacy data evidence and the current API domain contracts into a logical model for Supabase Auth + ASP.NET Core 10. Supabase Auth is the recommended credential provider; the API remains the sole METRA authorization and workflow authority. This document must be reviewed before any physical PostgreSQL schema is created.

The selected Supabase project currently has no METRA application tables in `public` and no recorded migrations. Legacy table names found in source code are evidence of what old clients attempted to use; they are not proof that those tables exist in the selected project or that their schemas are accurate.

**Architecture boundary**
- Angular and Flutter call the versioned ASP.NET Core API only.
- The API authenticates the caller, resolves the METRA account, evaluates permissions and station scope, and owns transactions.
- The API uses a dedicated least-privilege PostgreSQL runtime role.
- Migration/owner credentials are separate from runtime credentials and are never deployed to clients.
- Application tables should live in a non-exposed schema (proposed name: `metra`) unless a reviewed integration requires exposure. Do not expose privileged tables through the Supabase Data API by default.
- RLS is defense in depth, not a substitute for API authorization. If any application table is exposed, enable and test RLS before granting access.

## 2. Core modelling rules

1. A METRA account is not the same thing as an authentication-provider user.
2. A requested role/station is not an effective role grant or station assignment.
3. Role, permission, organizational scope and station assignment are separate concepts.
4. Approval decisions are immutable business events; current request status is a derived/current-state projection.
5. Account registration approval and meteorological observation approval are separate workflows.
6. Stations and organizational units are distinct entities. A label such as `الإدارة العامة` must not be silently inserted as a meteorological station.
7. Stable machine codes are separate from Arabic display labels. Preserve source labels exactly until a domain owner approves mappings.
8. No identifier, coordinate, role code, permission, status or uniqueness rule is to be invented to fill missing source data.
9. UTC timestamps use timezone-aware database types; server code assigns authoritative timestamps and actors.
10. Destructive deletes are restricted. Prefer explicit lifecycle states, revocation and approved retention/anonymization workflows.

## 3. Proposed logical tables — identity and access

Names below are logical names, not final SQL names or column types.

| Logical entity | Key attributes | Purpose and constraints |
|---|---|---|
| `accounts` | account_id, account_state, created_at, updated_at, activated_at, suspended_at | Canonical METRA principal. Server-generated UUID. State is independent of provider login state. No password/hash columns. |
| `account_profiles` | account_id, first_name, father_name, last_name, email/contact references, phone/contact references | METRA profile data. Preserve original Arabic field meaning. Apply data classification, validation and retention rules. Email/phone uniqueness and normalization require explicit product decisions; do not assume them from legacy UI checks. |
| `account_auth_links` | account_id, auth_user_id, linked_at, revoked_at | Proposed one-to-one mapping from a METRA account to `auth.users.id` (UUID FK to the Supabase-managed Auth user). The Auth user remains managed by Supabase; METRA must not write to `auth` tables. Multiple sign-in methods belonging to the same Supabase Auth user are managed by Supabase Auth, not represented as multiple METRA accounts. |
| `roles` | role_id, role_code, display_name_ar, lifecycle_state | Approved role catalogue. Stable code is immutable; display label can be versioned/changed through review. |
| `permissions` | permission_id, permission_code, description | Explicit capabilities such as `registrations.station.approve`, `registrations.system.approve`, `observations.daily.create`. |
| `role_permissions` | role_id, permission_id, validity metadata | Reviewed mapping from roles to capabilities. No implicit wildcard role. |
| `account_role_grants` | grant_id, account_id, role_id, scope_type, scope_id, valid_from, valid_until, granted_by, revoked_at | Effective role grant with explicit scope and validity. Requested role is not stored here until granted. |
| `account_station_assignments` | assignment_id, account_id, station_id, assignment_type, valid_from, valid_until, authorized_by, revoked_at | Operational station scope. Must not be inferred from profile text or role label. |
| `organizational_units` | unit_id, unit_code, display_name_ar, parent_unit_id, lifecycle_state | Administration/region/department hierarchy where authoritative source confirms it. |
| `stations` | station_id, official_code, display_name_ar, station_type, latitude, longitude, elevation, unit_id, lifecycle_state | Authoritative meteorological station catalogue. Codes, coordinates, types and hierarchy must come from approved station master data, not placeholders. |

### Account identity invariants

- One active external identity key must not map to two METRA accounts.
- Issuer and subject are opaque identifiers and are compared exactly; no lowercase, trimming or trailing-slash normalization.
- Account suspension blocks protected operations even if provider authentication succeeds.
- Identity linking does not create, activate or grant roles to an account.
- Identity link and its audit event commit atomically.
- Revocation is an explicit audited operation; do not silently overwrite an existing link.
- Do not store provider access/refresh tokens, authorization codes or passwords in these tables.

Identity provider for this project: Supabase Auth is the selected recommendation. The proposed physical link is `metra.account_auth_links.auth_user_id UUID REFERENCES auth.users(id)` with uniqueness on `auth_user_id` and, by default, `account_id`. This is a cross-schema FK proposal only; it must be checked against Supabase platform ownership and approved before implementation. Never insert/update/delete rows in `auth.users` or other platform-managed Auth tables. Do not add a generic issuer+subject table alongside this mapping unless a separately approved external OIDC requirement emerges.

## 4. Registration and approval workflow

| Logical entity | Key attributes | Purpose |
|---|---|---|
| `registration_requests` | request_id, applicant_profile_snapshot, requested_role_code, requested_station_reference, terms_version, terms_accepted_at, request_state, submitted_at, created_at | Stores a request, not an active account or role grant. Snapshot semantics and PII retention need approval. No password, password hash or shared program password. |
| `registration_decisions` | decision_id, request_id, stage, outcome, actor_account_id, actor_scope_snapshot, reason_code, reason_text, decided_at | Append-only record of each station/system decision, including actor and effective scope at decision time. |
| `registration_request_events` | event_id, request_id, event_type, actor_account_id, occurred_at, correlation_id, safe_metadata | Optional unified lifecycle history if the team chooses event history separate from decision records. Avoid duplicating the same audit fact without a clear purpose. |

The proposed registration submission transaction creates a METRA account in `PendingApproval`, links the already-authenticated Supabase `auth.users.id`, creates the registration request, and writes the submission audit event atomically. It does not grant a role or station assignment.

The proposed request lifecycle is:

`PendingStationApproval → PendingSystemApproval → Approved` (or terminal `Rejected`). The METRA account remains non-active until final approval; final approval changes the account to `Active` and creates the approved role grant and station assignment in the same transaction.

Rejection is terminal unless a separately approved appeal/reopen process is specified. The current API domain code has this two-stage model, while legacy source inspection does not prove every management-screen action or edge case. Business owners must confirm whether requests can be returned, edited, reopened, delegated or rejected at either stage.

Required transaction behavior:
- Stage-one actor must have the station-approval capability for the requested station scope.
- Stage-two actor must have system-approval capability.
- The actor is derived from the validated server context, never request JSON.
- A user cannot approve their own registration.
- Initial pending account creation, Auth-user link, registration request and submission audit event must be atomic.
- Final activation, effective role grant, approved station assignment, request-state transition and approval audit event must be atomic.
- Rejection must record the decision actor, stage, timestamp and reason policy.
- Duplicate submissions and concurrent decisions must be idempotent or rejected with a stable domain outcome.
- No browser-side password hashing, program password, temporary password or password recovery is migrated.

## 5. Audit and security records

Proposed `audit_events` fields:
- event_id (server-generated identifier);
- occurred_at_utc;
- actor_account_id (nullable only for documented system/anonymous events);
- action_code and outcome_code;
- target_type and target_id;
- scope_type and scope_id where relevant;
- request_id/correlation_id;
- reason_code and minimal safe metadata;
- schema/event version.

Requirements:
- Audit events are append-only for the API runtime role: INSERT/SELECT only; no UPDATE/DELETE.
- Audit insert and corresponding business state mutation commit in the same transaction.
- Do not log passwords, tokens, secrets, full identity subjects, or unnecessary contact data.
- Migration/owner credentials are not used by the running API.
- Define retention, export, backup, restore and tamper-response policy before production.
- A database owner can still alter its own database; stronger tamper resistance may require export to a separately controlled immutable/WORM destination.

## 6. Other METRA operational domains

The legacy source audit observed these table names: `hourly_reports`, `daily_reports`, `climate_reports`, `climate_hourly_reports`, `rainfall_reports`, `weather_phenomena`, `agricultural_reports`, `soil_temperatures`, `equipment_failures`, `telecom_failures`, `it_problem_reports`, `reminders`, `whatsapp_reminders`, `activity_log`, `user_messages`, `system_stats`, `system_backups`, and `sms`.

These should not be copied one-for-one into a new schema yet. The physical model for each operational domain must be derived from the complete form fields, validation rules, units, date/time semantics, station catalogue, correction/approval lifecycle, export requirements and authoritative data ownership.

Recommended domain boundaries for later design:
- **Meteorological observations:** explicitly model daily, hourly, monthly and annual reports; rainfall; climate summaries; weather phenomena; agricultural reports; and soil-temperature observations as typed domain records. Preserve each form's actual fields, units, precision, time basis, quality flags, correction history and approval lifecycle. Monthly/annual products should be defined as either independently submitted reports or reproducible aggregates from lower-frequency observations; do not assume which without source evidence. Agricultural reports and soil temperatures must remain first-class scientific records, not be dropped into generic JSON.
- **Classic and automatic stations:** both station classes belong in the same canonical station catalogue and shared application filters/map, with an explicit station type and source-system provenance. Their display markers may differ in clients, but station identity, coordinates and type must come from authoritative station master data. Keep provider-specific ingestion/collector storage separate where required; expose a normalized METRA API contract so Angular and Flutter can present both classes together without merging source databases or overwriting classic records.
- **Maintenance and incident reporting:** reconcile equipment and telecom field variants, reporter attribution, status transitions and device-specific attributes before defining normalized tables.
- **IT support:** separate report, assignment, work notes and resolution history if the actual workflow requires them.
- **Notifications/reminders:** define recipient, delivery channel, consent/purpose, scheduling, delivery attempts and idempotency. Do not store secrets or treat UI simulations as sent messages.
- **System metrics/backups:** operational telemetry and backup metadata are not ordinary user-editable application records; assign separate service ownership and access controls.
- **Messaging:** define retention, moderation, attachment handling and access scope before storing message bodies.

The dynamic table-name pattern found in legacy dashboard code must be replaced by a fixed server-side allowlist or explicit typed endpoints. Never accept arbitrary client-provided table names.

## 7. Canonicalization and legacy reconciliation blockers

### Roles

Legacy code contains these Arabic labels:
- Registration selector: `راصد جوي`, `متنبئ جوي`, `رئيس محطة`, `مدير مركز`, `مدير النظام`, `رئيس دائرة الشبكات`.
- Redirect map additionally contains: `مبرمج الدعم الفني`, `رئيس الاتصالات`, `رئيس الورشات`, `مدقق`, `متنبئ في محطات الرصد`.

The difference between `متنبئ جوي` and `متنبئ في محطات الرصد` is unresolved. The four roles present only in the redirect map are not automatically obsolete. No stable role codes or permission mappings are approved by this proposal.

### Stations and organizational units

The legacy registration selector contains 32 names, but the repository's `stations-data.js` is explicitly incomplete and `user-data.js` includes illustrative/fallback metadata. `الإدارة العامة` may be an organizational scope rather than a station. Do not infer station coordinates, official codes, types, region or active state from labels.

Before import, obtain the complete authoritative station master and reconcile every legacy name. Unresolved and duplicate mappings must be reported, not silently merged or dropped.

### Legacy identity data

Legacy `users` and `registration_queue` include password-related fields and inconsistent identity assumptions. Never migrate `password_hash`, `program_password`, browser-generated temporary passwords or fabricated fallback hashes into the new design. Profile/account mapping must be performed without copying credential material.

## 8. Suggested implementation sequence

1. Approve the identity-provider decision and canonical account lifecycle.
2. Approve role labels, stable role codes, permission matrix and scope semantics.
3. Obtain authoritative station and organizational-unit source data.
4. Approve registration state machine, rejection/appeal behavior and audit requirements.
5. Review a physical schema design, FK/unique/check constraints, indexes, grants and RLS matrix.
6. Select migration ownership, runtime role, secret delivery and isolated development/test project.
7. Implement schema migrations and PostgreSQL adapter in the ASP.NET Core API.
8. Add integration tests for constraints, concurrent decisions, suspension races, rollback, least privilege and RLS.
9. Build a dry-run migration report with duplicate/orphan counts; do not migrate credential fields.
10. Obtain explicit migration/cutover approval, backup/restore rehearsal and operational sign-off.

## 9. Decisions still required from the project owner

| Decision | Current state |
|---|---|
| Supabase PostgreSQL target project | Selected: `tbdnklyxjvbrilvnwgmq` |
| Supabase Auth as identity provider | **Recommended and selected for implementation planning; Auth configuration review still gates production activation** |
| External OIDC provider | Not in scope; requires a separate decision if later needed |
| Canonical METRA account key and lifecycle | UUID account key; pending/active/suspended/rejected/closed lifecycle proposed; physical constraints require review |
| Account-to-Auth-user cardinality | One-to-one proposed; recovery/relinking requires separate controlled workflow |
| Role catalogue and Arabic label reconciliation | Requires domain-owner approval; 10 legacy role labels need reconciliation |
| Permission-to-role mapping and station scope | Requires domain-owner approval; role names alone do not grant capabilities |
| Complete station master (classic and automatic) and organizational hierarchy | Source data required; 32 legacy labels are not authoritative or complete |
| Registration return/reopen/appeal behavior | Two sequential approvals selected; rejection is terminal in current proposal; return/reopen/appeal policy remains a business decision |
| Auth-user link storage | Supabase `auth.users.id` UUID FK proposed; subject is not duplicated as free text |
| Subject encryption/key-management approach | Not applicable to direct UUID FK proposal; reassess if external OIDC is added |
| Runtime DB role and migration ownership | Not selected |
| Audit retention and immutable export | Not selected |
| Separate development/test project and CI integration DB | Not selected |

## 10. Supabase platform and Data API boundary

The proposed METRA application objects belong in a dedicated non-exposed `metra` schema. Supabase's 2026-10-30 Data API exposure change means newly created public-schema tables are no longer automatically exposed by default; METRA must not rely on default exposure behavior as a security control. Keep application tables out of exposed schemas, do not grant `anon` or `authenticated` direct access to privileged METRA tables, and use the .NET API with a least-privilege database role. RLS remains defense in depth for any explicitly exposed object. Never modify platform-owned `auth`, `storage`, or `realtime` internals.

## 11. Explicit non-claims

This proposal is not a verified physical schema, security certification, data migration, production deployment or approval to change the live Supabase project. No application tables, RLS policies, grants, users, Auth settings, secrets or database records have been created, modified or migrated.
