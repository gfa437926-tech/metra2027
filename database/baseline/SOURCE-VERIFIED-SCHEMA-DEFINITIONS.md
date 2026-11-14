# METRA 2027 — Source-verified schema definitions catalogue

**Branch:** `work/metra-full-schema-recovery-2026-11-14`  
**Review basis:** current branch source files; baseline pack 001–008; operational observation migration `20261103164003`; follow-up observation migrations; incremental database migrations 003–031; role seed.  
**Purpose:** record exactly what the checked-in SQL declares, and distinguish it from columns merely assumed by later functions. This is a source extraction, **not approval to apply DDL** and not a claim that all operational METRA domains have approved schemas.

## 1. Coverage and conclusion

The checked-in executable table-definition sources declare **18 public tables**:

- **16 core tables** in `database/baseline/003–007`.
- **2 operational observation tables** in `supabase/migrations/20261103164003_create_operational_observation_submission.sql`.

The isolated-only `auth.users` stub is an additional test fixture, not a METRA-owned public table and not a substitute for Supabase Auth.

The catalogue below records the definitions as written. Several later migrations and read-model functions depend on columns or constraints that these definitions do not contain, or use different names. Those are recorded in section 4; no guessed columns have been added.

## 2. Core table definitions — baseline source

Types, nullability, defaults and declared constraints below are transcribed from the baseline SQL. Where a column is listed without `NOT NULL`, it is nullable under the declared DDL.

| # | Table | Source | Declared columns |
|---:|---|---|---|
| 1 | `countries` | `003_org_and_stations.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `iso2 char(2)`; `name_en text`; `name_ar text`; `is_active boolean NOT NULL DEFAULT true`; `created_at timestamptz NOT NULL DEFAULT now()` |
| 2 | `meteorological_authorities` | `003_org_and_stations.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `country_id uuid NOT NULL FK countries(id) ON DELETE RESTRICT`; `code text`; `name_en text`; `name_ar text`; `is_active boolean NOT NULL DEFAULT true`; `created_at timestamptz NOT NULL DEFAULT now()` |
| 3 | `station_catalogue` | `003_org_and_stations.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `owner_authority_id uuid NOT NULL FK meteorological_authorities(id) ON DELETE RESTRICT`; `country_id uuid NOT NULL FK countries(id) ON DELETE RESTRICT`; `station_code text`; `name_en text`; `name_ar text`; `latitude numeric`; `longitude numeric`; `elevation_m numeric`; `approval_status text NOT NULL DEFAULT 'approved' CHECK pending/approved/rejected/suspended`; `operational_status text NOT NULL DEFAULT 'active' CHECK active/inactive/decommissioned`; `is_demo boolean NOT NULL DEFAULT false`; `created_at timestamptz NOT NULL DEFAULT now()`; `updated_at timestamptz NOT NULL DEFAULT now()` |
| 4 | `metra_role_catalogue` | `004_roles_and_permission_catalogue.sql` | `role_code text PK`; `name_ar text`; `name_en text`; `description_ar text`; `description_en text`; `is_requestable boolean NOT NULL DEFAULT false`; `is_active boolean NOT NULL DEFAULT true`; `display_order int NOT NULL DEFAULT 100` |
| 5 | `metra_permission_codes` | `004_roles_and_permission_catalogue.sql` | `code text PK`; `description text`; `is_active boolean NOT NULL DEFAULT true` |
| 6 | `metra_role_permissions` | `004_roles_and_permission_catalogue.sql` | `role_code text NOT NULL FK metra_role_catalogue(role_code) ON DELETE CASCADE`; `permission_code text NOT NULL`; composite PK `(role_code, permission_code)` |
| 7 | `metra_account_states` | `005_memberships_assignments_grants.sql` | `user_id uuid PK FK auth.users(id) ON DELETE RESTRICT`; `account_state text NOT NULL DEFAULT 'active' CHECK active/disabled/pending/locked`; `updated_at timestamptz NOT NULL DEFAULT now()` |
| 8 | `authority_memberships` | `005_memberships_assignments_grants.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `authority_id uuid NOT NULL FK meteorological_authorities(id) ON DELETE RESTRICT`; `membership_role_code text FK metra_role_catalogue(role_code)`; `approval_status text NOT NULL DEFAULT 'approved' CHECK pending/approved/rejected/revoked`; `valid_from timestamptz NOT NULL DEFAULT now()`; `valid_to timestamptz`; `created_at timestamptz NOT NULL DEFAULT now()` |
| 9 | `station_assignments` | `005_memberships_assignments_grants.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `station_id uuid NOT NULL FK station_catalogue(id) ON DELETE RESTRICT`; `authority_id uuid NOT NULL FK meteorological_authorities(id) ON DELETE RESTRICT`; `assignment_role_code text NOT NULL FK metra_role_catalogue(role_code)`; `approval_status text NOT NULL DEFAULT 'approved' CHECK pending/approved/rejected/revoked`; `valid_from timestamptz NOT NULL DEFAULT now()`; `valid_to timestamptz`; `created_at timestamptz NOT NULL DEFAULT now()` |
| 10 | `permission_grants` | `005_memberships_assignments_grants.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `permission_code text NOT NULL`; `authority_id uuid FK meteorological_authorities(id) ON DELETE RESTRICT` (nullable in baseline); `station_id uuid FK station_catalogue(id) ON DELETE RESTRICT`; `approval_status text NOT NULL DEFAULT 'approved' CHECK pending/approved/rejected/revoked`; `approved_at timestamptz`; `approved_by uuid FK auth.users(id)`; `reviewed_at timestamptz`; `valid_from timestamptz NOT NULL DEFAULT now()`; `valid_to timestamptz`; `revoked_at timestamptz`; `created_at timestamptz NOT NULL DEFAULT now()`; CHECK: archive-read permission requires non-null `station_id` |
| 11 | `metra_user_profiles` | `006_registration_and_station_audit.sql` | `user_id uuid PK FK auth.users(id) ON DELETE RESTRICT`; `display_name text`; `phone text`; `created_at timestamptz NOT NULL DEFAULT now()`; `updated_at timestamptz NOT NULL DEFAULT now()` |
| 12 | `registration_requests` | `006_registration_and_station_audit.sql` | `id uuid PK DEFAULT gen_random_uuid()`; `user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `requested_station_id uuid FK station_catalogue(id)`; `requested_role_code text FK metra_role_catalogue(role_code)`; `status text NOT NULL DEFAULT 'pending'`; `created_at timestamptz NOT NULL DEFAULT now()`; `updated_at timestamptz NOT NULL DEFAULT now()` |
| 13 | `registration_audit_events` | `006_registration_and_station_audit.sql` | `id bigint GENERATED ALWAYS AS IDENTITY PK`; `request_id uuid NOT NULL FK registration_requests(id) ON DELETE RESTRICT`; `actor_user_id uuid FK auth.users(id)`; `action_code text NOT NULL`; `from_status text`; `to_status text`; `note text`; `occurred_at timestamptz NOT NULL DEFAULT now()` |
| 14 | `station_audit_log` | `006_registration_and_station_audit.sql` | `id bigint GENERATED ALWAYS AS IDENTITY PK`; `station_id uuid NOT NULL FK station_catalogue(id) ON DELETE RESTRICT`; `actor_user_id uuid FK auth.users(id)`; `event_type text NOT NULL`; `payload jsonb NOT NULL DEFAULT '{}'::jsonb`; `occurred_at timestamptz NOT NULL DEFAULT now()` |
| 15 | `permission_grant_audit` | `007_audit_append_only.sql` | `id bigint GENERATED ALWAYS AS IDENTITY PK`; `grant_id uuid NOT NULL`; `action text NOT NULL CHECK granted/revoked/modified`; `actor_user_id uuid FK auth.users(id)`; `station_id uuid FK station_catalogue(id)`; `permission_code text NOT NULL`; `occurred_at timestamptz NOT NULL DEFAULT now()`; `note text` |
| 16 | `authority_access_audit_events` | `007_audit_append_only.sql` | `id bigint GENERATED ALWAYS AS IDENTITY PK`; `target_kind text NOT NULL CHECK membership/permission_grant`; `target_id uuid NOT NULL`; `authority_id uuid NOT NULL FK meteorological_authorities(id) ON DELETE RESTRICT`; `subject_user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `actor_user_id uuid NOT NULL FK auth.users(id) ON DELETE RESTRICT`; `action_code text NOT NULL CHECK requested/approved/rejected/revoked`; `from_status text`; `to_status text NOT NULL`; `reason text NOT NULL CHECK trimmed length 5..2000`; `metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK object`; `occurred_at timestamptz NOT NULL`; `created_at timestamptz NOT NULL DEFAULT clock_timestamp()` |

## 3. Operational observation table definitions — Supabase migration source

These two tables are owned by the first operational-observation migration. They must not be recreated in the core baseline.

### 17. `metra_observations`

Source: `supabase/migrations/20261103164003_create_operational_observation_submission.sql`

- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `station_id uuid NOT NULL REFERENCES station_catalogue(id)`
- `created_by uuid NOT NULL REFERENCES auth.users(id)`
- `observation_type text NOT NULL CHECK IN ('daily','hourly','phenomenon')`
- `observed_at timestamptz NOT NULL`
- `payload jsonb NOT NULL CHECK jsonb object and pg_column_size <= 65536`
- `status text NOT NULL CHECK IN ('draft','submitted','returned','approved')`
- `initial_status text NOT NULL CHECK IN ('draft','submitted')`
- `idempotency_key text NOT NULL CHECK trimmed length 1..128`
- `submitted_at timestamptz`
- `reviewed_by uuid REFERENCES auth.users(id)`
- `reviewed_at timestamptz`
- `review_note text CHECK null or length <= 2000`
- `created_at timestamptz NOT NULL DEFAULT now()`
- `updated_at timestamptz NOT NULL DEFAULT now()`
- UNIQUE `(station_id, created_by, idempotency_key)`

### 18. `metra_observation_audit_events`

Source: same migration.

- `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`
- `observation_id uuid NOT NULL REFERENCES metra_observations(id)`
- `station_id uuid NOT NULL REFERENCES station_catalogue(id)`
- `actor_user_id uuid NOT NULL REFERENCES auth.users(id)`
- `event_type text NOT NULL CHECK IN ('created_draft','submitted','returned','approved','resubmitted')`
- `from_status text CHECK null or in ('draft','submitted','returned','approved')`
- `to_status text NOT NULL CHECK in ('draft','submitted','returned','approved')`
- `note text CHECK null or length <= 2000`
- `occurred_at timestamptz NOT NULL DEFAULT now()`

## 4. Additional isolated identity object

`database/baseline/002_identity_stub.sql` creates `auth.users(id uuid PRIMARY KEY, email text, created_at timestamptz NOT NULL DEFAULT now())` for isolated PostgreSQL only. It is explicitly not a replacement for hosted Supabase Auth and is not counted among the 18 METRA public tables.

## 5. Declared indexes, RLS, triggers and follow-up deltas

- Baseline indexes: `idx_station_catalogue_authority`; `idx_station_assignments_user_station`; `idx_station_assignments_station`; `idx_authority_memberships_user_authority`; `idx_permission_grants_user_code`; partial `idx_permission_grants_station_code`; `idx_permission_grant_audit_grant`; `idx_station_audit_log_station_time`.
- Baseline append-only triggers use `public.reject_append_only_audit_mutation()` on `permission_grant_audit`, `authority_access_audit_events`, `registration_audit_events`, and `station_audit_log`.
- Observation migration adds indexes `metra_observations_station_status_observed_idx`, `metra_observations_creator_created_idx`, and `metra_observation_audit_observation_time_idx`; later migration adds audit actor, station and reviewed-by indexes.
- Observation migration enables and forces RLS on both observation tables, revokes browser/runtime access, grants selected access to `service_role`, adds deny-client policies, and adds append-only audit trigger `metra_observation_audit_immutable`.
- Migration 020 attempts to add `permission_grants.authority_id` and make it NOT NULL, adds an authority FK and authority-scoped exclusion constraint/index, and attempts to CREATE `authority_access_audit_events` again.
- Migration 022 expects to drop and recreate `permission_grants_revocation_check`.
- Migration 030 and 031 are proposal markers, not operational table definitions.

## 6. Unresolved schema contracts — cannot be filled from approved DDL in this source set

The following dependencies are explicit in later SQL, but the authoritative column definition is absent or incompatible in the baseline:

| Relation | Baseline source shape | Later SQL dependency | Exact unresolved issue |
|---|---|---|---|
| `metra_user_profiles` | `display_name, phone` | 008/010 read `first_name, father_name, last_name` | Profile schema contract absent |
| `station_catalogue` | `station_code` | 008/010 read `local_station_code` | Code-field naming contract differs |
| `meteorological_authorities` | `code, name_en, name_ar` | 027 reads `authority_code, is_national` | Authority catalogue contract differs |
| `metra_account_states` | `account_state, updated_at` | 010 reads `state_reason`; 009 returns it | Missing state-reason definition |
| `registration_requests` | basic request/status/timestamps | 008/009/019 use `phone_snapshot, terms_version, submitted_at, review_note` and status workflow | Full registration contract absent |
| `registration_audit_events` | `actor_user_id, action_code, from_status, to_status, note, occurred_at` | 008 reads `user_id, event_type, terms_version, decision_note` | Audit event contract differs |
| `station_assignments` | identity, scope, role, status, validity, created_at | 012/013 use `requested_by, reason, approved_by, reviewed_at, updated_at` | Workflow columns absent |
| `station_audit_log` | station/event/payload shape | 012–014 use `entity_type, entity_id, action, actor_id, reason, before_data, after_data` | Audit event contract differs |
| `authority_memberships` | no requester/reason fields | 020–023 use `requested_by, reason` | Lifecycle columns absent |
| `permission_grants` | has nullable `authority_id`, no requester/reason | 020–023 use `requested_by, reason`; 020 tries to add existing `authority_id` | Column and nullability conflict |
| `permission_grants` constraints | baseline only declares archive station CHECK | 020 drops `permission_grants_no_overlapping_periods`; 022 drops `permission_grants_revocation_check` | Expected constraints are not declared in baseline |
| `authority_access_audit_events` | created in baseline 007 | 020 executes another non-conditional CREATE TABLE for same relation | Duplicate ownership/replay conflict |

These are not cosmetic discrepancies. They affect row shape, workflow writes, authorization scope, audit traceability, and migration replay. Do not resolve them with guessed types, blanket `IF NOT EXISTS`, or edits that conceal the original migration assumptions.

## 7. Role seed evidence

`database/seeds/001_role_catalogue.sql` declares eight roles: `observer`, `station_head`, `station_auditor`, `chief_auditor`, `network_director`, `statistics_director`, `aftn_operator`, and `system_admin`. It does not declare a complete permission-code catalogue or a complete `metra_role_permissions` allow-list. Migration files insert additional role-permission pairs; these must be consolidated separately without assuming that the eight role rows prove a complete permission model.

## 8. Completeness boundary

This is an exhaustive transcription of the **18 public table definitions found in the current branch's checked-in executable sources** plus the isolated auth stub. It is not a complete approved schema for all METRA domains. The repository explicitly lacks approved operational definitions for forecast products, AI jobs, Climatol jobs, notifications and the wider electronic-record warehouse. No definitions for those domains are fabricated here.

**Acceptance for the requested “all original approved definitions” step remains blocked** until the canonical full-schema package or approved schema export supplies the missing contracts listed above and confirms whether the current baseline skeletons are authoritative or only isolated fixtures. This catalogue is the verified extraction result; it is not permission to apply DDL to hosted Supabase or the legacy database.


## 9. Cross-branch search for the missing original schema

A read-only search was also made across the repository branches most relevant to database engineering:

- `work/backend-db-integration-phase` contains the Stage C2 reconciliation report. It explicitly identifies the absence of original migrations 001/002 and describes the unified schema as a proposed Path N/Path H strategy, not an approved production schema.
- `work/backend-db-integration-full-2026-11-13` contains Path N compatibility patches for 020, 022 and 027. These are replay adapters for an empty PostgreSQL path; they are not the missing original CREATE TABLE history and do not resolve all missing profile, registration, assignment and audit column contracts. They were not copied into this recovery branch because they are a separate compatibility implementation requiring review.
- `work/database-engineering-audit` contains `PROPOSED-UNIFIED-DATA-MODEL.md`, which explicitly labels itself a logical proposal, not approved DDL. Its required-fields matrix is likewise a preliminary, non-approved operational contract.
- The C9.6 report is a read-only reconciliation of a configured hosted project's schema at that time. It records meaningful differences (including authority-scoped grants without a grant-level `station_id`) but is not a complete schema dump and is not authorization to query or change that hosted project now.

**Cross-branch result:** no approved full schema export or original 001/002 migration package was found in the inspected repository sources. Compatibility patches and proposed logical models are not substitutes for that source of truth.
