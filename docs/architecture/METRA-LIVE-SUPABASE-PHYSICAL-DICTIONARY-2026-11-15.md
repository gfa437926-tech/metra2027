# METRA 2027 — Live Supabase physical schema dictionary

**Captured:** 2026-11-15 (read-only)
**Project:** `tbdnklyxjvbrilvnwgmq`
**Tables inspected:** 46

This is a read-only snapshot of the live application-owned PostgreSQL tables. It documents deployed physical structures, not the proposed recorder/climate/AI extensions. No data rows were read or changed by this export. The row counts are metadata returned by the schema inspection tool.

**Important:** This dictionary is not an approval to modify the database. Review it against the logical ERD and the recovered 86-migration archive before any new DDL.

## Schema: `alerts`

### `alerts.alert_events`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `rule_id` | `uuid` | yes | — | — |
| `provider_id` | `uuid` | yes | — | — |
| `external_reference` | `text` | yes | — | — |
| `alert_code` | `text` | yes | — | — |
| `severity` | `text` | no | — | severity = ANY (ARRAY['unknown'::text, 'minor'::text, 'moderate'::text, 'severe'::text, 'extreme'::text]) |
| `headline` | `text` | no | — | — |
| `description` | `text` | yes | — | — |
| `area_reference` | `text` | yes | — | — |
| `starts_at` | `timestamp with time zone` | yes | — | — |
| `ends_at` | `timestamp with time zone` | yes | — | — |
| `event_state` | `text` | no | 'active'::text | event_state = ANY (ARRAY['active'::text, 'updated'::text, 'expired'::text, 'cancelled'::text]) |
| `source_payload_reference_id` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `alert_events_source_payload_reference_id_fkey`: (source_payload_reference_id) → `weather.provider_payload_references` (id)
  - `alert_events_rule_id_fkey`: (rule_id) → `alerts.alert_rules` (id)
  - `alert_events_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `alert_recipients_alert_event_id_fkey`: (alert_event_id) → `alerts.alert_events` (id)

### `alerts.alert_recipients`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `alert_event_id` | `uuid` | no | — | — |
| `user_id` | `uuid` | yes | — | — |
| `organization_id` | `uuid` | yes | — | — |
| `station_id` | `uuid` | yes | — | — |
| `delivery_channel` | `text` | no | — | delivery_channel = ANY (ARRAY['in_app'::text, 'email'::text, 'sms'::text, 'push'::text]) |
| `delivery_state` | `text` | no | 'queued'::text | delivery_state = ANY (ARRAY['queued'::text, 'sent'::text, 'delivered'::text, 'failed'::text, 'acknowledged'::text]) |
| `queued_at` | `timestamp with time zone` | no | now() | — |
| `delivered_at` | `timestamp with time zone` | yes | — | — |
| `acknowledged_at` | `timestamp with time zone` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `alert_recipients_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `alert_recipients_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `alert_recipients_alert_event_id_fkey`: (alert_event_id) → `alerts.alert_events` (id)
  - `alert_recipients_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)

### `alerts.alert_rules`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `rule_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `rule_kind` | `text` | no | — | rule_kind = ANY (ARRAY['official_feed'::text, 'threshold'::text, 'system'::text]) |
| `rule_definition` | `jsonb` | no | '{}'::jsonb | jsonb_typeof(rule_definition) = 'object'::text |
| `rule_state` | `text` | no | 'inactive'::text | rule_state = ANY (ARRAY['active'::text, 'inactive'::text, 'retired'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `alert_events_rule_id_fkey`: (rule_id) → `alerts.alert_rules` (id)

## Schema: `audit`

### `audit.events`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `bigint` | no | — | — |
| `occurred_at` | `timestamp with time zone` | no | now() | — |
| `actor_user_id` | `uuid` | yes | — | — |
| `action_code` | `text` | no | — | — |
| `entity_schema` | `text` | no | — | — |
| `entity_table` | `text` | no | — | — |
| `entity_id` | `uuid` | yes | — | — |
| `organization_id` | `uuid` | yes | — | — |
| `station_id` | `uuid` | yes | — | — |
| `outcome` | `text` | no | — | outcome = ANY (ARRAY['success'::text, 'denied'::text, 'failure'::text]) |
| `correlation_id` | `uuid` | yes | — | — |
| `metadata` | `jsonb` | no | '{}'::jsonb | jsonb_typeof(metadata) = 'object'::text |

- Primary key: `id`
- Foreign keys:
  - `events_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)
  - `events_organization_id_fkey`: (organization_id) → `iam.organizations` (id)

## Schema: `catalog`

### `catalog.station_capabilities`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `capability_code` | `text` | no | — | — |
| `capability_details` | `jsonb` | no | '{}'::jsonb | jsonb_typeof(capability_details) = 'object'::text |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `station_capabilities_station_id_fkey`: (station_id) → `catalog.stations` (id)

### `catalog.station_identifiers`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `identifier_scheme` | `text` | no | — | — |
| `identifier_value` | `text` | no | — | — |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `source_reference` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `station_identifiers_station_id_fkey`: (station_id) → `catalog.stations` (id)

### `catalog.station_locations`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `latitude` | `numeric` | no | — | latitude >= '-90'::integer::numeric AND latitude <= 90::numeric |
| `longitude` | `numeric` | no | — | longitude >= '-180'::integer::numeric AND longitude <= 180::numeric |
| `elevation_m` | `numeric` | yes | — | — |
| `timezone_name` | `text` | yes | — | — |
| `location_source` | `text` | no | — | location_source = ANY (ARRAY['official_record'::text, 'survey'::text, 'gps'::text, 'verified_manual'::text, 'other'::text]) |
| `source_reference` | `text` | yes | — | — |
| `horizontal_accuracy_m` | `numeric` | yes | — | horizontal_accuracy_m IS NULL OR horizontal_accuracy_m >= 0::numeric |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `recorded_by` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `station_locations_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_locations_recorded_by_fkey`: (recorded_by) → `iam.user_profiles` (user_id)

### `catalog.station_operating_periods`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `operating_state` | `text` | no | — | operating_state = ANY (ARRAY['active'::text, 'temporarily_closed'::text, 'inactive'::text]) |
| `valid_from` | `timestamp with time zone` | no | — | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `reason` | `text` | yes | — | — |
| `recorded_by` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `station_operating_periods_recorded_by_fkey`: (recorded_by) → `iam.user_profiles` (user_id)
  - `station_operating_periods_station_id_fkey`: (station_id) → `catalog.stations` (id)

### `catalog.station_reviews`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `reviewer_user_id` | `uuid` | no | — | — |
| `decision` | `text` | no | — | decision = ANY (ARRAY['approved'::text, 'rejected'::text, 'changes_requested'::text, 'suspended'::text]) |
| `reason` | `text` | no | — | length(TRIM(BOTH FROM reason)) >= 5 |
| `previous_status` | `text` | yes | — | — |
| `resulting_status` | `text` | no | — | — |
| `decided_at` | `timestamp with time zone` | no | now() | — |
| `correlation_id` | `uuid` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `station_reviews_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_reviews_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)

### `catalog.station_types`

- RLS enabled: **yes**
- Rows (metadata): **7**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `type_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `description` | `text` | yes | — | — |
| `is_active` | `boolean` | no | true | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `stations_station_type_id_fkey`: (station_type_id) → `catalog.station_types` (id)

### `catalog.stations`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `owner_organization_id` | `uuid` | no | — | — |
| `station_type_id` | `uuid` | no | — | — |
| `station_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | length(TRIM(BOTH FROM name_ar)) > 0 |
| `name_en` | `text` | no | — | length(TRIM(BOTH FROM name_en)) > 0 |
| `wmo_identifier` | `text` | yes | — | — |
| `station_description` | `text` | yes | — | — |
| `approval_status` | `text` | no | 'pending'::text | approval_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'changes_requested'::text, 'suspended'::text]) |
| `operational_status` | `text` | no | 'planned'::text | operational_status = ANY (ARRAY['planned'::text, 'active'::text, 'temporarily_closed'::text, 'inactive'::text, 'decommissioned'::text]) |
| `elevation_m` | `numeric` | yes | — | — |
| `timezone_name` | `text` | yes | — | — |
| `opened_on` | `date` | yes | — | — |
| `closed_on` | `date` | yes | — | — |
| `created_by` | `uuid` | yes | — | — |
| `updated_by` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `stations_owner_organization_id_fkey`: (owner_organization_id) → `iam.organizations` (id)
  - `stations_station_type_id_fkey`: (station_type_id) → `catalog.station_types` (id)
  - `stations_created_by_fkey`: (created_by) → `iam.user_profiles` (user_id)
  - `stations_updated_by_fkey`: (updated_by) → `iam.user_profiles` (user_id)
  - `station_identifiers_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_locations_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_capabilities_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_operating_periods_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `station_reviews_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `alert_recipients_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `permission_grants_station_id_organization_id_fkey`: (station_id, organization_id) → `catalog.stations` (id, owner_organization_id)
  - `registration_requests_requested_station_id_fkey`: (requested_station_id) → `catalog.stations` (id)
  - `registration_requests_station_organization_fk`: (requested_station_id, organization_id) → `catalog.stations` (id, owner_organization_id)
  - `events_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `support_incidents_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `equipment_faults_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `equipment_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `submissions_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `role_assignments_station_id_organization_id_fkey`: (station_id, organization_id) → `catalog.stations` (id, owner_organization_id)

## Schema: `files`

### `files.objects`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `bucket_name` | `text` | no | — | — |
| `object_key` | `text` | no | — | — |
| `original_filename` | `text` | yes | — | — |
| `content_type` | `text` | no | — | — |
| `byte_size` | `bigint` | no | — | byte_size >= 0 |
| `sha256` | `text` | no | — | sha256 ~ '^[0-9a-f]{64}$'::text |
| `classification` | `text` | no | — | classification = ANY (ARRAY['public'::text, 'internal'::text, 'confidential'::text, 'restricted'::text]) |
| `owner_user_id` | `uuid` | yes | — | — |
| `object_state` | `text` | no | 'pending'::text | object_state = ANY (ARRAY['pending'::text, 'available'::text, 'quarantined'::text, 'deleted'::text]) |
| `uploaded_at` | `timestamp with time zone` | no | now() | — |
| `retention_until` | `timestamp with time zone` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `provider_payload_references_file_object_id_fkey`: (file_object_id) → `files.objects` (id)
  - `attachments_file_object_id_fkey`: (file_object_id) → `files.objects` (id)
  - `objects_owner_user_id_fkey`: (owner_user_id) → `iam.user_profiles` (user_id)

## Schema: `iam`

### `iam.access_reviews`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `role_assignment_id` | `uuid` | yes | — | — |
| `permission_grant_id` | `uuid` | yes | — | — |
| `reviewer_user_id` | `uuid` | no | — | — |
| `review_decision` | `text` | no | — | review_decision = ANY (ARRAY['retain'::text, 'modify'::text, 'revoke'::text]) |
| `reason` | `text` | no | — | length(TRIM(BOTH FROM reason)) >= 5 |
| `reviewed_at` | `timestamp with time zone` | no | now() | — |
| `next_review_at` | `timestamp with time zone` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `access_reviews_role_assignment_id_fkey`: (role_assignment_id) → `iam.role_assignments` (id)
  - `access_reviews_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `access_reviews_permission_grant_id_fkey`: (permission_grant_id) → `iam.permission_grants` (id)

### `iam.memberships`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `user_id` | `uuid` | no | — | — |
| `organization_id` | `uuid` | no | — | — |
| `unit_id` | `uuid` | yes | — | — |
| `membership_state` | `text` | no | 'pending'::text | membership_state = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'ended'::text, 'rejected'::text]) |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `requested_at` | `timestamp with time zone` | no | now() | — |
| `approved_at` | `timestamp with time zone` | yes | — | — |
| `approved_by` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `role_assignments_membership_id_organization_id_fkey`: (membership_id, organization_id) → `iam.memberships` (id, organization_id)
  - `memberships_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `memberships_approved_by_fkey`: (approved_by) → `iam.user_profiles` (user_id)
  - `memberships_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `memberships_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)
  - `role_assignments_membership_id_fkey`: (membership_id) → `iam.memberships` (id)

### `iam.organization_units`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `organization_id` | `uuid` | no | — | — |
| `parent_unit_id` | `uuid` | yes | — | — |
| `unit_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | length(TRIM(BOTH FROM name_ar)) > 0 |
| `name_en` | `text` | no | — | length(TRIM(BOTH FROM name_en)) > 0 |
| `unit_state` | `text` | no | 'active'::text | unit_state = ANY (ARRAY['active'::text, 'inactive'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `permission_grants_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `organization_units_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `organization_units_parent_unit_id_organization_id_fkey`: (parent_unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `role_assignments_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `memberships_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `registration_requests_requested_unit_id_organization_id_fkey`: (requested_unit_id, organization_id) → `iam.organization_units` (id, organization_id)

### `iam.organizations`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `organization_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | length(TRIM(BOTH FROM name_ar)) > 0 |
| `name_en` | `text` | no | — | length(TRIM(BOTH FROM name_en)) > 0 |
| `organization_kind` | `text` | no | — | organization_kind = ANY (ARRAY['national_authority'::text, 'regional_authority'::text, 'research'::text, 'partner'::text, 'other'::text]) |
| `organization_state` | `text` | no | 'pending'::text | organization_state = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'retired'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `registration_requests_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `alert_recipients_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `memberships_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `organization_units_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `events_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `stations_owner_organization_id_fkey`: (owner_organization_id) → `iam.organizations` (id)

### `iam.permission_grants`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `user_id` | `uuid` | no | — | — |
| `permission_id` | `uuid` | no | — | — |
| `organization_id` | `uuid` | yes | — | — |
| `unit_id` | `uuid` | yes | — | — |
| `station_id` | `uuid` | yes | — | — |
| `scope_type` | `text` | no | — | scope_type = ANY (ARRAY['global'::text, 'organization'::text, 'unit'::text, 'station'::text]) |
| `grant_state` | `text` | no | 'pending'::text | grant_state = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'revoked'::text, 'expired'::text]) |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `granted_by` | `uuid` | yes | — | — |
| `reason` | `text` | no | — | length(TRIM(BOTH FROM reason)) >= 5 |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `permission_grants_granted_by_fkey`: (granted_by) → `iam.user_profiles` (user_id)
  - `permission_grants_permission_id_fkey`: (permission_id) → `iam.permissions` (id)
  - `permission_grants_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)
  - `access_reviews_permission_grant_id_fkey`: (permission_grant_id) → `iam.permission_grants` (id)
  - `permission_grants_station_id_organization_id_fkey`: (station_id, organization_id) → `catalog.stations` (id, owner_organization_id)
  - `permission_grants_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)

### `iam.permissions`

- RLS enabled: **yes**
- Rows (metadata): **27**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `permission_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `description` | `text` | yes | — | — |
| `permission_domain` | `text` | no | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `role_permissions_permission_id_fkey`: (permission_id) → `iam.permissions` (id)
  - `permission_grants_permission_id_fkey`: (permission_id) → `iam.permissions` (id)

### `iam.registration_decisions`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `request_id` | `uuid` | no | — | — |
| `stage` | `text` | no | — | stage = ANY (ARRAY['station'::text, 'organization'::text, 'system'::text]) |
| `decision_sequence` | `integer` | no | — | decision_sequence > 0 |
| `reviewer_user_id` | `uuid` | no | — | — |
| `decision` | `text` | no | — | decision = ANY (ARRAY['approved'::text, 'rejected'::text, 'returned'::text]) |
| `reason` | `text` | no | — | length(TRIM(BOTH FROM reason)) >= 3 |
| `decided_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `registration_decisions_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `registration_decisions_request_id_fkey`: (request_id) → `iam.registration_requests` (id)

### `iam.registration_requests`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `applicant_user_id` | `uuid` | no | — | — |
| `organization_id` | `uuid` | no | — | — |
| `requested_unit_id` | `uuid` | yes | — | — |
| `requested_station_id` | `uuid` | no | — | — |
| `requested_role_id` | `uuid` | no | — | — |
| `request_state` | `text` | no | 'submitted'::text | request_state = ANY (ARRAY['submitted'::text, 'pending_station_review'::text, 'pending_system_review'::text, 'approved'::text, 'rejected'::text, 'withdrawn'::text]) |
| `terms_version` | `text` | no | — | — |
| `idempotency_key` | `text` | no | — | — |
| `submitted_at` | `timestamp with time zone` | no | now() | — |
| `resolved_at` | `timestamp with time zone` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `registration_requests_requested_unit_id_organization_id_fkey`: (requested_unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `registration_decisions_request_id_fkey`: (request_id) → `iam.registration_requests` (id)
  - `registration_requests_requested_role_id_fkey`: (requested_role_id) → `iam.roles` (id)
  - `registration_requests_applicant_user_id_fkey`: (applicant_user_id) → `iam.user_profiles` (user_id)
  - `registration_requests_organization_id_fkey`: (organization_id) → `iam.organizations` (id)
  - `registration_requests_requested_station_id_fkey`: (requested_station_id) → `catalog.stations` (id)
  - `registration_requests_station_organization_fk`: (requested_station_id, organization_id) → `catalog.stations` (id, owner_organization_id)

### `iam.role_assignments`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `membership_id` | `uuid` | no | — | — |
| `organization_id` | `uuid` | yes | — | — |
| `unit_id` | `uuid` | yes | — | — |
| `station_id` | `uuid` | yes | — | — |
| `role_id` | `uuid` | no | — | — |
| `scope_type` | `text` | no | — | scope_type = ANY (ARRAY['global'::text, 'organization'::text, 'unit'::text, 'station'::text]) |
| `assignment_state` | `text` | no | 'pending'::text | assignment_state = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'revoked'::text, 'expired'::text]) |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |
| `assigned_by` | `uuid` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `role_assignments_assigned_by_fkey`: (assigned_by) → `iam.user_profiles` (user_id)
  - `access_reviews_role_assignment_id_fkey`: (role_assignment_id) → `iam.role_assignments` (id)
  - `role_assignments_membership_id_fkey`: (membership_id) → `iam.memberships` (id)
  - `role_assignments_station_id_organization_id_fkey`: (station_id, organization_id) → `catalog.stations` (id, owner_organization_id)
  - `role_assignments_unit_id_organization_id_fkey`: (unit_id, organization_id) → `iam.organization_units` (id, organization_id)
  - `role_assignments_membership_id_organization_id_fkey`: (membership_id, organization_id) → `iam.memberships` (id, organization_id)
  - `role_assignments_role_id_fkey`: (role_id) → `iam.roles` (id)

### `iam.role_permissions`

- RLS enabled: **yes**
- Rows (metadata): **78**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `role_id` | `uuid` | no | — | — |
| `permission_id` | `uuid` | no | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `role_id`, `permission_id`
- Foreign keys:
  - `role_permissions_permission_id_fkey`: (permission_id) → `iam.permissions` (id)
  - `role_permissions_role_id_fkey`: (role_id) → `iam.roles` (id)

### `iam.roles`

- RLS enabled: **yes**
- Rows (metadata): **10**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `role_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `description` | `text` | yes | — | — |
| `is_system_role` | `boolean` | no | false | — |
| `is_assignable` | `boolean` | no | true | — |
| `is_requestable` | `boolean` | no | false | — |
| `role_state` | `text` | no | 'active'::text | role_state = ANY (ARRAY['active'::text, 'inactive'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `role_assignments_role_id_fkey`: (role_id) → `iam.roles` (id)
  - `role_permissions_role_id_fkey`: (role_id) → `iam.roles` (id)
  - `registration_requests_requested_role_id_fkey`: (requested_role_id) → `iam.roles` (id)

### `iam.user_profiles`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `user_id` | `uuid` | no | — | — |
| `email` | `text` | yes | — | — |
| `display_name` | `text` | yes | — | — |
| `given_name` | `text` | yes | — | — |
| `family_name` | `text` | yes | — | — |
| `phone_e164` | `text` | yes | — | — |
| `preferred_locale` | `text` | no | 'ar'::text | — |
| `timezone_name` | `text` | yes | — | — |
| `profile_state` | `text` | no | 'active'::text | profile_state = ANY (ARRAY['active'::text, 'suspended'::text, 'closed'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |
| `father_name` | `text` | yes | — | — |

- Primary key: `user_id`
- Foreign keys:
  - `submissions_author_user_id_fkey`: (author_user_id) → `iam.user_profiles` (user_id)
  - `support_incident_events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)
  - `events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)
  - `access_reviews_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `objects_owner_user_id_fkey`: (owner_user_id) → `iam.user_profiles` (user_id)
  - `registration_decisions_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `registration_requests_applicant_user_id_fkey`: (applicant_user_id) → `iam.user_profiles` (user_id)
  - `permission_grants_granted_by_fkey`: (granted_by) → `iam.user_profiles` (user_id)
  - `permission_grants_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)
  - `role_assignments_assigned_by_fkey`: (assigned_by) → `iam.user_profiles` (user_id)
  - `station_reviews_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `station_operating_periods_recorded_by_fkey`: (recorded_by) → `iam.user_profiles` (user_id)
  - `station_locations_recorded_by_fkey`: (recorded_by) → `iam.user_profiles` (user_id)
  - `stations_updated_by_fkey`: (updated_by) → `iam.user_profiles` (user_id)
  - `stations_created_by_fkey`: (created_by) → `iam.user_profiles` (user_id)
  - `memberships_approved_by_fkey`: (approved_by) → `iam.user_profiles` (user_id)
  - `memberships_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)
  - `user_profiles_user_id_fkey`: (user_id) → `auth.users` (id)
  - `support_incidents_assigned_to_user_id_fkey`: (assigned_to_user_id) → `iam.user_profiles` (user_id)
  - `equipment_fault_events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)
  - `equipment_faults_assigned_to_user_id_fkey`: (assigned_to_user_id) → `iam.user_profiles` (user_id)
  - `equipment_faults_reporter_user_id_fkey`: (reporter_user_id) → `iam.user_profiles` (user_id)
  - `alert_recipients_user_id_fkey`: (user_id) → `iam.user_profiles` (user_id)
  - `attachments_attached_by_fkey`: (attached_by) → `iam.user_profiles` (user_id)
  - `quality_flags_resolved_by_fkey`: (resolved_by) → `iam.user_profiles` (user_id)
  - `review_decisions_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `revisions_changed_by_fkey`: (changed_by) → `iam.user_profiles` (user_id)
  - `support_incidents_reporter_user_id_fkey`: (reporter_user_id) → `iam.user_profiles` (user_id)

## Schema: `integration`

### `integration.execution_runs`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `source_id` | `uuid` | no | — | — |
| `operation_code` | `text` | no | — | — |
| `idempotency_key` | `text` | no | — | — |
| `run_state` | `text` | no | 'queued'::text | run_state = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'partial'::text, 'failed'::text, 'cancelled'::text]) |
| `started_at` | `timestamp with time zone` | no | now() | — |
| `completed_at` | `timestamp with time zone` | yes | — | — |
| `result_summary` | `jsonb` | yes | — | result_summary IS NULL OR jsonb_typeof(result_summary) = 'object'::text |
| `error_code` | `text` | yes | — | — |
| `correlation_id` | `uuid` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `execution_runs_source_id_fkey`: (source_id) → `integration.sources` (id)

### `integration.sources`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `source_code` | `text` | no | — | — |
| `name` | `text` | no | — | — |
| `source_kind` | `text` | no | — | source_kind = ANY (ARRAY['station_catalogue'::text, 'forecast'::text, 'alert'::text, 'climate'::text, 'identity'::text, 'other'::text]) |
| `contract_version` | `text` | yes | — | — |
| `endpoint_reference` | `text` | yes | — | — |
| `source_state` | `text` | no | 'planned'::text | source_state = ANY (ARRAY['planned'::text, 'active'::text, 'suspended'::text, 'retired'::text]) |
| `approved_at` | `timestamp with time zone` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `execution_runs_source_id_fkey`: (source_id) → `integration.sources` (id)

## Schema: `observations`

### `observations.attachments`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `submission_id` | `uuid` | no | — | — |
| `file_object_id` | `uuid` | no | — | — |
| `attachment_kind` | `text` | no | — | — |
| `attached_by` | `uuid` | no | — | — |
| `attached_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `attachments_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `attachments_file_object_id_fkey`: (file_object_id) → `files.objects` (id)
  - `attachments_attached_by_fkey`: (attached_by) → `iam.user_profiles` (user_id)

### `observations.quality_flags`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `submission_id` | `uuid` | yes | — | — |
| `observation_value_id` | `uuid` | yes | — | — |
| `rule_code` | `text` | no | — | — |
| `severity` | `text` | no | — | severity = ANY (ARRAY['info'::text, 'warning'::text, 'error'::text, 'critical'::text]) |
| `flag_state` | `text` | no | 'open'::text | flag_state = ANY (ARRAY['open'::text, 'acknowledged'::text, 'resolved'::text, 'waived'::text]) |
| `details` | `jsonb` | no | '{}'::jsonb | jsonb_typeof(details) = 'object'::text |
| `raised_at` | `timestamp with time zone` | no | now() | — |
| `resolved_at` | `timestamp with time zone` | yes | — | — |
| `resolved_by` | `uuid` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `quality_flags_resolved_by_fkey`: (resolved_by) → `iam.user_profiles` (user_id)
  - `quality_flags_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `quality_flags_observation_value_id_fkey`: (observation_value_id) → `observations.values` (id)

### `observations.review_decisions`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `submission_id` | `uuid` | no | — | — |
| `reviewer_user_id` | `uuid` | no | — | — |
| `decision` | `text` | no | — | decision = ANY (ARRAY['approved'::text, 'returned'::text, 'rejected'::text]) |
| `reason` | `text` | no | — | length(TRIM(BOTH FROM reason)) >= 3 |
| `decided_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `review_decisions_reviewer_user_id_fkey`: (reviewer_user_id) → `iam.user_profiles` (user_id)
  - `review_decisions_submission_id_fkey`: (submission_id) → `observations.submissions` (id)

### `observations.revisions`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `submission_id` | `uuid` | no | — | — |
| `revision_number` | `integer` | no | — | revision_number > 0 |
| `snapshot` | `jsonb` | no | — | jsonb_typeof(snapshot) = 'object'::text |
| `changed_by` | `uuid` | no | — | — |
| `change_reason` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `revisions_changed_by_fkey`: (changed_by) → `iam.user_profiles` (user_id)
  - `revisions_submission_id_fkey`: (submission_id) → `observations.submissions` (id)

### `observations.submissions`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `author_user_id` | `uuid` | no | — | — |
| `observation_type_id` | `uuid` | no | — | — |
| `observed_at` | `timestamp with time zone` | no | — | — |
| `timezone_name` | `text` | yes | — | — |
| `submission_state` | `text` | no | 'draft'::text | submission_state = ANY (ARRAY['draft'::text, 'submitted'::text, 'under_review'::text, 'approved'::text, 'returned'::text, 'rejected'::text, 'superseded'::text]) |
| `revision_number` | `integer` | no | 1 | revision_number > 0 |
| `idempotency_key` | `text` | no | — | — |
| `submitted_at` | `timestamp with time zone` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `attachments_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `submissions_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `submissions_author_user_id_fkey`: (author_user_id) → `iam.user_profiles` (user_id)
  - `submissions_observation_type_id_fkey`: (observation_type_id) → `ref.observation_types` (id)
  - `values_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `revisions_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `review_decisions_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `quality_flags_submission_id_fkey`: (submission_id) → `observations.submissions` (id)

### `observations.values`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `submission_id` | `uuid` | no | — | — |
| `parameter_id` | `uuid` | no | — | — |
| `value_kind` | `text` | no | — | — |
| `value_decimal` | `numeric` | yes | — | — |
| `value_integer` | `bigint` | yes | — | — |
| `value_text` | `text` | yes | — | — |
| `value_boolean` | `boolean` | yes | — | — |
| `unit_id` | `uuid` | yes | — | — |
| `sequence_number` | `integer` | no | 1 | sequence_number > 0 |
| `quality_state` | `text` | no | 'unchecked'::text | quality_state = ANY (ARRAY['unchecked'::text, 'passed'::text, 'suspect'::text, 'failed'::text, 'corrected'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `values_submission_id_fkey`: (submission_id) → `observations.submissions` (id)
  - `quality_flags_observation_value_id_fkey`: (observation_value_id) → `observations.values` (id)
  - `values_parameter_id_value_kind_fkey`: (parameter_id, value_kind) → `ref.parameters` (id, value_kind)
  - `values_unit_id_fkey`: (unit_id) → `ref.units` (id)

## Schema: `operations`

### `operations.equipment`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `equipment_code` | `text` | no | — | — |
| `equipment_kind` | `text` | no | — | — |
| `manufacturer` | `text` | yes | — | — |
| `model` | `text` | yes | — | — |
| `serial_number` | `text` | yes | — | — |
| `installed_at` | `date` | yes | — | — |
| `equipment_state` | `text` | no | 'active'::text | equipment_state = ANY (ARRAY['planned'::text, 'active'::text, 'maintenance'::text, 'retired'::text]) |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `equipment_faults_equipment_id_fkey`: (equipment_id) → `operations.equipment` (id)
  - `equipment_faults_equipment_station_fk`: (equipment_id, station_id) → `operations.equipment` (id, station_id)
  - `equipment_station_id_fkey`: (station_id) → `catalog.stations` (id)

### `operations.equipment_fault_events`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `fault_id` | `uuid` | no | — | — |
| `actor_user_id` | `uuid` | yes | — | — |
| `event_code` | `text` | no | — | — |
| `previous_state` | `text` | yes | — | — |
| `resulting_state` | `text` | yes | — | — |
| `note` | `text` | yes | — | — |
| `occurred_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `equipment_fault_events_fault_id_fkey`: (fault_id) → `operations.equipment_faults` (id)
  - `equipment_fault_events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)

### `operations.equipment_faults`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | no | — | — |
| `equipment_id` | `uuid` | yes | — | — |
| `reporter_user_id` | `uuid` | no | — | — |
| `assigned_to_user_id` | `uuid` | yes | — | — |
| `fault_code` | `text` | yes | — | — |
| `title` | `text` | no | — | — |
| `description` | `text` | no | — | — |
| `severity` | `text` | no | — | severity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]) |
| `fault_state` | `text` | no | 'open'::text | fault_state = ANY (ARRAY['open'::text, 'triaged'::text, 'assigned'::text, 'in_progress'::text, 'resolved'::text, 'closed'::text, 'reopened'::text]) |
| `reported_at` | `timestamp with time zone` | no | now() | — |
| `resolved_at` | `timestamp with time zone` | yes | — | — |
| `resolution_note` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `equipment_fault_events_fault_id_fkey`: (fault_id) → `operations.equipment_faults` (id)
  - `equipment_faults_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `equipment_faults_equipment_station_fk`: (equipment_id, station_id) → `operations.equipment` (id, station_id)
  - `equipment_faults_assigned_to_user_id_fkey`: (assigned_to_user_id) → `iam.user_profiles` (user_id)
  - `equipment_faults_reporter_user_id_fkey`: (reporter_user_id) → `iam.user_profiles` (user_id)
  - `equipment_faults_equipment_id_fkey`: (equipment_id) → `operations.equipment` (id)

### `operations.support_incident_events`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `incident_id` | `uuid` | no | — | — |
| `actor_user_id` | `uuid` | yes | — | — |
| `event_code` | `text` | no | — | — |
| `previous_state` | `text` | yes | — | — |
| `resulting_state` | `text` | yes | — | — |
| `note` | `text` | yes | — | — |
| `occurred_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `support_incident_events_actor_user_id_fkey`: (actor_user_id) → `iam.user_profiles` (user_id)
  - `support_incident_events_incident_id_fkey`: (incident_id) → `operations.support_incidents` (id)

### `operations.support_incidents`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `station_id` | `uuid` | yes | — | — |
| `reporter_user_id` | `uuid` | no | — | — |
| `assigned_to_user_id` | `uuid` | yes | — | — |
| `category_code` | `text` | no | — | — |
| `title` | `text` | no | — | — |
| `description` | `text` | no | — | — |
| `priority` | `text` | no | — | priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]) |
| `incident_state` | `text` | no | 'open'::text | incident_state = ANY (ARRAY['open'::text, 'triaged'::text, 'assigned'::text, 'in_progress'::text, 'waiting'::text, 'resolved'::text, 'closed'::text, 'reopened'::text]) |
| `reported_at` | `timestamp with time zone` | no | now() | — |
| `resolved_at` | `timestamp with time zone` | yes | — | — |
| `resolution_note` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `support_incidents_reporter_user_id_fkey`: (reporter_user_id) → `iam.user_profiles` (user_id)
  - `support_incidents_station_id_fkey`: (station_id) → `catalog.stations` (id)
  - `support_incidents_assigned_to_user_id_fkey`: (assigned_to_user_id) → `iam.user_profiles` (user_id)
  - `support_incident_events_incident_id_fkey`: (incident_id) → `operations.support_incidents` (id)

## Schema: `ref`

### `ref.observation_types`

- RLS enabled: **yes**
- Rows (metadata): **3**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `type_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `cadence_code` | `text` | yes | — | — |
| `schema_version` | `text` | no | '1'::text | — |
| `is_active` | `boolean` | no | true | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `submissions_observation_type_id_fkey`: (observation_type_id) → `ref.observation_types` (id)

### `ref.parameters`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `parameter_code` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `description` | `text` | yes | — | — |
| `value_kind` | `text` | no | — | value_kind = ANY (ARRAY['decimal'::text, 'integer'::text, 'text'::text, 'boolean'::text]) |
| `canonical_unit_id` | `uuid` | yes | — | — |
| `precision_scale` | `smallint` | yes | — | precision_scale IS NULL OR precision_scale >= 0 AND precision_scale <= 12 |
| `is_active` | `boolean` | no | true | — |
| `definition_version` | `text` | no | '1'::text | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `forecast_points_parameter_id_value_kind_fkey`: (parameter_id, value_kind) → `ref.parameters` (id, value_kind)
  - `forecast_parameter_mappings_parameter_id_fkey`: (parameter_id) → `ref.parameters` (id)
  - `values_parameter_id_value_kind_fkey`: (parameter_id, value_kind) → `ref.parameters` (id, value_kind)
  - `parameters_canonical_unit_id_fkey`: (canonical_unit_id) → `ref.units` (id)

### `ref.units`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `unit_code` | `text` | no | — | — |
| `symbol` | `text` | no | — | — |
| `name_ar` | `text` | no | — | — |
| `name_en` | `text` | no | — | — |
| `dimension_code` | `text` | no | — | — |
| `is_active` | `boolean` | no | true | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `parameters_canonical_unit_id_fkey`: (canonical_unit_id) → `ref.units` (id)
  - `values_unit_id_fkey`: (unit_id) → `ref.units` (id)
  - `forecast_points_unit_id_fkey`: (unit_id) → `ref.units` (id)

## Schema: `weather`

### `weather.forecast_parameter_mappings`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `provider_id` | `uuid` | no | — | — |
| `provider_parameter_code` | `text` | no | — | — |
| `parameter_id` | `uuid` | no | — | — |
| `provider_unit_code` | `text` | yes | — | — |
| `mapping_version` | `text` | no | — | — |
| `valid_from` | `timestamp with time zone` | no | now() | — |
| `valid_to` | `timestamp with time zone` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `forecast_parameter_mappings_parameter_id_fkey`: (parameter_id) → `ref.parameters` (id)
  - `forecast_parameter_mappings_provider_id_fkey`: (provider_id) → `weather.providers` (id)

### `weather.forecast_points`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `forecast_run_id` | `uuid` | no | — | — |
| `parameter_id` | `uuid` | no | — | — |
| `value_kind` | `text` | no | — | — |
| `value_decimal` | `numeric` | yes | — | — |
| `value_integer` | `bigint` | yes | — | — |
| `value_text` | `text` | yes | — | — |
| `value_boolean` | `boolean` | yes | — | — |
| `unit_id` | `uuid` | yes | — | — |
| `valid_at` | `timestamp with time zone` | no | — | — |
| `latitude` | `numeric` | yes | — | — |
| `longitude` | `numeric` | yes | — | — |
| `grid_cell_reference` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `forecast_points_unit_id_fkey`: (unit_id) → `ref.units` (id)
  - `forecast_points_forecast_run_id_fkey`: (forecast_run_id) → `weather.forecast_runs` (id)
  - `forecast_points_parameter_id_value_kind_fkey`: (parameter_id, value_kind) → `ref.parameters` (id, value_kind)

### `weather.forecast_runs`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `provider_id` | `uuid` | no | — | — |
| `ingestion_run_id` | `uuid` | yes | — | — |
| `model_code` | `text` | yes | — | — |
| `model_version` | `text` | yes | — | — |
| `issued_at` | `timestamp with time zone` | no | — | — |
| `retrieved_at` | `timestamp with time zone` | no | now() | — |
| `coverage_start` | `timestamp with time zone` | yes | — | — |
| `coverage_end` | `timestamp with time zone` | yes | — | — |
| `run_state` | `text` | no | 'received'::text | run_state = ANY (ARRAY['received'::text, 'validated'::text, 'published'::text, 'withdrawn'::text, 'failed'::text]) |
| `source_reference` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `forecast_runs_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `forecast_points_forecast_run_id_fkey`: (forecast_run_id) → `weather.forecast_runs` (id)
  - `forecast_runs_ingestion_run_id_fkey`: (ingestion_run_id) → `weather.ingestion_runs` (id)

### `weather.ingestion_runs`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `provider_id` | `uuid` | no | — | — |
| `operation_code` | `text` | no | — | — |
| `idempotency_key` | `text` | no | — | — |
| `run_state` | `text` | no | 'queued'::text | run_state = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'partial'::text, 'failed'::text, 'cancelled'::text]) |
| `started_at` | `timestamp with time zone` | no | now() | — |
| `completed_at` | `timestamp with time zone` | yes | — | — |
| `records_received` | `bigint` | no | 0 | records_received >= 0 |
| `records_accepted` | `bigint` | no | 0 | records_accepted >= 0 |
| `error_code` | `text` | yes | — | — |
| `correlation_id` | `uuid` | yes | — | — |

- Primary key: `id`
- Foreign keys:
  - `ingestion_runs_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `forecast_runs_ingestion_run_id_fkey`: (ingestion_run_id) → `weather.ingestion_runs` (id)
  - `provider_payload_references_ingestion_run_id_fkey`: (ingestion_run_id) → `weather.ingestion_runs` (id)

### `weather.provider_payload_references`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `ingestion_run_id` | `uuid` | no | — | — |
| `file_object_id` | `uuid` | no | — | — |
| `payload_kind` | `text` | no | — | payload_kind = ANY (ARRAY['request'::text, 'response'::text, 'manifest'::text, 'other'::text]) |
| `captured_at` | `timestamp with time zone` | no | now() | — |
| `retention_until` | `timestamp with time zone` | yes | — | — |
| `content_sha256` | `text` | no | — | content_sha256 ~ '^[0-9a-f]{64}$'::text |

- Primary key: `id`
- Foreign keys:
  - `provider_payload_references_ingestion_run_id_fkey`: (ingestion_run_id) → `weather.ingestion_runs` (id)
  - `alert_events_source_payload_reference_id_fkey`: (source_payload_reference_id) → `weather.provider_payload_references` (id)
  - `provider_payload_references_file_object_id_fkey`: (file_object_id) → `files.objects` (id)

### `weather.providers`

- RLS enabled: **yes**
- Rows (metadata): **0**

| Column | PostgreSQL type | Nullable | Default | Check |
|---|---|---:|---|---|
| `id` | `uuid` | no | gen_random_uuid() | — |
| `provider_code` | `text` | no | — | — |
| `name` | `text` | no | — | — |
| `provider_kind` | `text` | no | — | provider_kind = ANY (ARRAY['forecast'::text, 'observation_feed'::text, 'alert_feed'::text, 'radar'::text, 'other'::text]) |
| `contract_version` | `text` | yes | — | — |
| `provider_state` | `text` | no | 'planned'::text | provider_state = ANY (ARRAY['planned'::text, 'active'::text, 'suspended'::text, 'retired'::text]) |
| `terms_reference` | `text` | yes | — | — |
| `created_at` | `timestamp with time zone` | no | now() | — |
| `updated_at` | `timestamp with time zone` | no | now() | — |

- Primary key: `id`
- Foreign keys:
  - `alert_events_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `ingestion_runs_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `forecast_runs_provider_id_fkey`: (provider_id) → `weather.providers` (id)
  - `forecast_parameter_mappings_provider_id_fkey`: (provider_id) → `weather.providers` (id)

## Interpretation and release boundary

- All 46 inspected application tables had RLS enabled at capture time.
- No `anon` or `authenticated` table CRUD grants were observed in the read-only privilege check.
- The `public` schema contains no application tables; the live model is organized into dedicated schemas.
- Recorder capture/image/trace, climate-series/homogeneity, and AI dataset/experiment/model-registry tables were not present in this inspected physical model.
- Do not apply the archived SQL from `supabase/live-schema-history/` wholesale. It is a source archive, not an active replay set.