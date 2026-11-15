
-- METRA greenfield rebuild. Scope: application-owned schemas only.
-- Supabase-managed auth/storage/realtime/vault/extensions/migration history are preserved.

create extension if not exists btree_gist with schema extensions;

do $$
declare r record;
begin
  -- Remove application-owned relations in public, including all dependent legacy objects.
  for r in
    select n.nspname, c.relname, c.relkind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r','p','v','m','f','S')
    order by case c.relkind when 'v' then 1 when 'm' then 1 when 'f' then 2 when 'r' then 3 when 'p' then 3 when 'S' then 4 else 5 end
  loop
    if r.relkind = 'v' then
      execute format('drop view if exists %I.%I cascade', r.nspname, r.relname);
    elsif r.relkind = 'm' then
      execute format('drop materialized view if exists %I.%I cascade', r.nspname, r.relname);
    elsif r.relkind = 'f' then
      execute format('drop foreign table if exists %I.%I cascade', r.nspname, r.relname);
    elsif r.relkind in ('r','p') then
      execute format('drop table if exists %I.%I cascade', r.nspname, r.relname);
    elsif r.relkind = 'S' then
      execute format('drop sequence if exists %I.%I cascade', r.nspname, r.relname);
    end if;
  end loop;

  -- Remove application RPCs/triggers in public and private; never touch Supabase schemas.
  for r in
    select p.oid::regprocedure as signature, n.nspname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public','private')
  loop
    execute format('drop function if exists %s cascade', r.signature);
  end loop;

  -- Remove app-specific custom types from public.
  for r in
    select n.nspname, t.typname
    from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typtype in ('e','d')
  loop
    execute format('drop type if exists %I.%I cascade', r.nspname, r.typname);
  end loop;
end $$;

drop schema if exists metra_migration cascade;
drop schema if exists private cascade;

create schema iam;
create schema catalog;
create schema ref;
create schema observations;
create schema weather;
create schema alerts;
create schema operations;
create schema files;
create schema integration;
create schema audit;
create schema private;

-- Shared timestamps and immutable event helpers. All are SECURITY INVOKER.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function private.reject_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'append-only record: % is not permitted on %.%', tg_op, tg_table_schema, tg_table_name
    using errcode = '55000';
end;
$$;

-- Identity and organization model.
create table iam.user_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  email text,
  display_name text,
  given_name text,
  family_name text,
  phone_e164 text,
  preferred_locale text not null default 'ar',
  timezone_name text,
  profile_state text not null default 'active'
    check (profile_state in ('active','suspended','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (email)
);

create table iam.organizations (
  id uuid primary key default gen_random_uuid(),
  organization_code text not null unique,
  name_ar text not null check (length(trim(name_ar)) > 0),
  name_en text not null check (length(trim(name_en)) > 0),
  organization_kind text not null
    check (organization_kind in ('national_authority','regional_authority','research','partner','other')),
  organization_state text not null default 'pending'
    check (organization_state in ('pending','active','suspended','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table iam.organization_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references iam.organizations(id) on delete restrict,
  parent_unit_id uuid,
  unit_code text not null,
  name_ar text not null check (length(trim(name_ar)) > 0),
  name_en text not null check (length(trim(name_en)) > 0),
  unit_state text not null default 'active' check (unit_state in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, unit_code),
  unique (id, organization_id),
  foreign key (parent_unit_id, organization_id)
    references iam.organization_units(id, organization_id) on delete restrict
);

create table iam.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  organization_id uuid not null references iam.organizations(id) on delete restrict,
  unit_id uuid,
  membership_state text not null default 'pending'
    check (membership_state in ('pending','active','suspended','ended','rejected')),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references iam.user_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  unique (id, organization_id),
  foreign key (unit_id, organization_id)
    references iam.organization_units(id, organization_id) on delete restrict
);

create table iam.roles (
  id uuid primary key default gen_random_uuid(),
  role_code text not null unique,
  name_ar text not null,
  name_en text not null,
  description text,
  is_system_role boolean not null default false,
  is_assignable boolean not null default true,
  is_requestable boolean not null default false,
  role_state text not null default 'active' check (role_state in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table iam.permissions (
  id uuid primary key default gen_random_uuid(),
  permission_code text not null unique,
  name_ar text not null,
  name_en text not null,
  description text,
  permission_domain text not null,
  created_at timestamptz not null default now()
);

create table iam.role_permissions (
  role_id uuid not null references iam.roles(id) on delete restrict,
  permission_id uuid not null references iam.permissions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

-- New station catalogue; deliberately starts empty.
create table catalog.station_types (
  id uuid primary key default gen_random_uuid(),
  type_code text not null unique,
  name_ar text not null,
  name_en text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table catalog.stations (
  id uuid primary key default gen_random_uuid(),
  owner_organization_id uuid not null references iam.organizations(id) on delete restrict,
  station_type_id uuid not null references catalog.station_types(id) on delete restrict,
  station_code text not null unique,
  name_ar text not null check (length(trim(name_ar)) > 0),
  name_en text not null check (length(trim(name_en)) > 0),
  wmo_identifier text,
  station_description text,
  approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected','changes_requested','suspended')),
  operational_status text not null default 'planned'
    check (operational_status in ('planned','active','temporarily_closed','inactive','decommissioned')),
  elevation_m numeric(9,2),
  timezone_name text,
  opened_on date,
  closed_on date,
  created_by uuid references iam.user_profiles(user_id) on delete restrict,
  updated_by uuid references iam.user_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (closed_on is null or opened_on is null or closed_on >= opened_on),
  unique (id, owner_organization_id),
  unique (wmo_identifier)
);

create table catalog.station_identifiers (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  identifier_scheme text not null,
  identifier_value text not null,
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  source_reference text,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  unique (identifier_scheme, identifier_value, valid_from)
);

create table catalog.station_locations (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  latitude numeric(9,6) not null check (latitude between -90 and 90),
  longitude numeric(9,6) not null check (longitude between -180 and 180),
  elevation_m numeric(9,2),
  timezone_name text,
  location_source text not null
    check (location_source in ('official_record','survey','gps','verified_manual','other')),
  source_reference text,
  horizontal_accuracy_m numeric(10,2) check (horizontal_accuracy_m is null or horizontal_accuracy_m >= 0),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  recorded_by uuid references iam.user_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  exclude using gist (
    station_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') with &&
  )
);

create table catalog.station_capabilities (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  capability_code text not null,
  capability_details jsonb not null default '{}'::jsonb check (jsonb_typeof(capability_details) = 'object'),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  unique (station_id, capability_code, valid_from)
);

create table catalog.station_operating_periods (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  operating_state text not null check (operating_state in ('active','temporarily_closed','inactive')),
  valid_from timestamptz not null,
  valid_to timestamptz,
  reason text,
  recorded_by uuid references iam.user_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  exclude using gist (
    station_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') with &&
  )
);

create table catalog.station_reviews (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  reviewer_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  decision text not null check (decision in ('approved','rejected','changes_requested','suspended')),
  reason text not null check (length(trim(reason)) >= 5),
  previous_status text,
  resulting_status text not null,
  decided_at timestamptz not null default now(),
  correlation_id uuid
);

-- Scoped role assignments and exceptional grants.
create table iam.role_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null,
  organization_id uuid,
  unit_id uuid,
  station_id uuid,
  role_id uuid not null references iam.roles(id) on delete restrict,
  scope_type text not null check (scope_type in ('global','organization','unit','station')),
  assignment_state text not null default 'pending'
    check (assignment_state in ('pending','active','suspended','revoked','expired')),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  assigned_by uuid references iam.user_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  check (
    (scope_type = 'global' and organization_id is null and unit_id is null and station_id is null)
    or (scope_type = 'organization' and organization_id is not null and unit_id is null and station_id is null)
    or (scope_type = 'unit' and organization_id is not null and unit_id is not null and station_id is null)
    or (scope_type = 'station' and organization_id is not null and unit_id is null and station_id is not null)
  ),
  foreign key (membership_id, organization_id)
    references iam.memberships(id, organization_id) on delete restrict,
  foreign key (unit_id, organization_id)
    references iam.organization_units(id, organization_id) on delete restrict,
  foreign key (station_id, organization_id)
    references catalog.stations(id, owner_organization_id) on delete restrict
);

create table iam.permission_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  permission_id uuid not null references iam.permissions(id) on delete restrict,
  organization_id uuid,
  unit_id uuid,
  station_id uuid,
  scope_type text not null check (scope_type in ('global','organization','unit','station')),
  grant_state text not null default 'pending'
    check (grant_state in ('pending','active','suspended','revoked','expired')),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  granted_by uuid references iam.user_profiles(user_id) on delete restrict,
  reason text not null check (length(trim(reason)) >= 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  check (
    (scope_type = 'global' and organization_id is null and unit_id is null and station_id is null)
    or (scope_type = 'organization' and organization_id is not null and unit_id is null and station_id is null)
    or (scope_type = 'unit' and organization_id is not null and unit_id is not null and station_id is null)
    or (scope_type = 'station' and organization_id is not null and unit_id is null and station_id is not null)
  ),
  foreign key (unit_id, organization_id)
    references iam.organization_units(id, organization_id) on delete restrict,
  foreign key (station_id, organization_id)
    references catalog.stations(id, owner_organization_id) on delete restrict
);

create table iam.registration_requests (
  id uuid primary key default gen_random_uuid(),
  applicant_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  organization_id uuid not null references iam.organizations(id) on delete restrict,
  requested_unit_id uuid,
  requested_station_id uuid not null references catalog.stations(id) on delete restrict,
  requested_role_id uuid not null references iam.roles(id) on delete restrict,
  request_state text not null default 'submitted'
    check (request_state in ('submitted','pending_station_review','pending_system_review','approved','rejected','withdrawn')),
  terms_version text not null,
  idempotency_key text not null,
  submitted_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (applicant_user_id, idempotency_key),
  foreign key (requested_unit_id, organization_id)
    references iam.organization_units(id, organization_id) on delete restrict
);

create table iam.registration_decisions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references iam.registration_requests(id) on delete restrict,
  stage text not null check (stage in ('station','organization','system')),
  decision_sequence integer not null check (decision_sequence > 0),
  reviewer_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  decision text not null check (decision in ('approved','rejected','returned')),
  reason text not null check (length(trim(reason)) >= 3),
  decided_at timestamptz not null default now(),
  unique (request_id, stage, decision_sequence)
);

-- Scientific reference catalogues. Parameter thresholds remain deliberately unseeded.
create table ref.units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null unique,
  symbol text not null,
  name_ar text not null,
  name_en text not null,
  dimension_code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table ref.parameters (
  id uuid primary key default gen_random_uuid(),
  parameter_code text not null unique,
  name_ar text not null,
  name_en text not null,
  description text,
  value_kind text not null check (value_kind in ('decimal','integer','text','boolean')),
  canonical_unit_id uuid references ref.units(id) on delete restrict,
  precision_scale smallint check (precision_scale is null or precision_scale between 0 and 12),
  is_active boolean not null default true,
  definition_version text not null default '1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, value_kind)
);

create table ref.observation_types (
  id uuid primary key default gen_random_uuid(),
  type_code text not null unique,
  name_ar text not null,
  name_en text not null,
  cadence_code text,
  schema_version text not null default '1',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- File metadata only; binary objects remain in private Storage buckets.
create table files.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_name text not null,
  object_key text not null,
  original_filename text,
  content_type text not null,
  byte_size bigint not null check (byte_size >= 0),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  classification text not null
    check (classification in ('public','internal','confidential','restricted')),
  owner_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  object_state text not null default 'pending'
    check (object_state in ('pending','available','quarantined','deleted')),
  uploaded_at timestamptz not null default now(),
  retention_until timestamptz,
  unique (bucket_name, object_key)
);

-- Manual observations are separate from forecasts and carry typed values.
create table observations.submissions (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  author_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  observation_type_id uuid not null references ref.observation_types(id) on delete restrict,
  observed_at timestamptz not null,
  timezone_name text,
  submission_state text not null default 'draft'
    check (submission_state in ('draft','submitted','under_review','approved','returned','rejected','superseded')),
  revision_number integer not null default 1 check (revision_number > 0),
  idempotency_key text not null,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (author_user_id, idempotency_key),
  unique (id, revision_number)
);

create table observations.values (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references observations.submissions(id) on delete restrict,
  parameter_id uuid not null,
  value_kind text not null,
  value_decimal numeric,
  value_integer bigint,
  value_text text,
  value_boolean boolean,
  unit_id uuid references ref.units(id) on delete restrict,
  sequence_number integer not null default 1 check (sequence_number > 0),
  quality_state text not null default 'unchecked'
    check (quality_state in ('unchecked','passed','suspect','failed','corrected')),
  created_at timestamptz not null default now(),
  foreign key (parameter_id, value_kind) references ref.parameters(id, value_kind) on delete restrict,
  check (
    (value_kind = 'decimal' and value_decimal is not null and value_integer is null and value_text is null and value_boolean is null)
    or (value_kind = 'integer' and value_decimal is null and value_integer is not null and value_text is null and value_boolean is null)
    or (value_kind = 'text' and value_decimal is null and value_integer is null and value_text is not null and value_boolean is null)
    or (value_kind = 'boolean' and value_decimal is null and value_integer is null and value_text is null and value_boolean is not null)
  ),
  unique (submission_id, parameter_id, sequence_number)
);

create table observations.revisions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references observations.submissions(id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  changed_by uuid not null references iam.user_profiles(user_id) on delete restrict,
  change_reason text,
  created_at timestamptz not null default now(),
  unique (submission_id, revision_number)
);

create table observations.review_decisions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references observations.submissions(id) on delete restrict,
  reviewer_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  decision text not null check (decision in ('approved','returned','rejected')),
  reason text not null check (length(trim(reason)) >= 3),
  decided_at timestamptz not null default now()
);

create table observations.quality_flags (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid references observations.submissions(id) on delete restrict,
  observation_value_id uuid references observations.values(id) on delete restrict,
  rule_code text not null,
  severity text not null check (severity in ('info','warning','error','critical')),
  flag_state text not null default 'open' check (flag_state in ('open','acknowledged','resolved','waived')),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  raised_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references iam.user_profiles(user_id) on delete restrict,
  check (num_nonnulls(submission_id, observation_value_id) = 1)
);

create table observations.attachments (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references observations.submissions(id) on delete restrict,
  file_object_id uuid not null references files.objects(id) on delete restrict,
  attachment_kind text not null,
  attached_by uuid not null references iam.user_profiles(user_id) on delete restrict,
  attached_at timestamptz not null default now(),
  unique (submission_id, file_object_id)
);

-- Provider forecasts and ingestion provenance are not station observations.
create table weather.providers (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null unique,
  name text not null,
  provider_kind text not null check (provider_kind in ('forecast','observation_feed','alert_feed','radar','other')),
  contract_version text,
  provider_state text not null default 'planned'
    check (provider_state in ('planned','active','suspended','retired')),
  terms_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table weather.ingestion_runs (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references weather.providers(id) on delete restrict,
  operation_code text not null,
  idempotency_key text not null,
  run_state text not null default 'queued'
    check (run_state in ('queued','running','succeeded','partial','failed','cancelled')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  records_received bigint not null default 0 check (records_received >= 0),
  records_accepted bigint not null default 0 check (records_accepted >= 0),
  error_code text,
  correlation_id uuid,
  unique (provider_id, idempotency_key),
  check (completed_at is null or completed_at >= started_at),
  check (records_accepted <= records_received)
);

create table weather.forecast_runs (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references weather.providers(id) on delete restrict,
  ingestion_run_id uuid references weather.ingestion_runs(id) on delete restrict,
  model_code text,
  model_version text,
  issued_at timestamptz not null,
  retrieved_at timestamptz not null default now(),
  coverage_start timestamptz,
  coverage_end timestamptz,
  run_state text not null default 'received'
    check (run_state in ('received','validated','published','withdrawn','failed')),
  source_reference text,
  created_at timestamptz not null default now(),
  check (coverage_end is null or coverage_start is null or coverage_end > coverage_start),
  unique (provider_id, source_reference)
);

create table weather.forecast_points (
  id uuid primary key default gen_random_uuid(),
  forecast_run_id uuid not null references weather.forecast_runs(id) on delete restrict,
  parameter_id uuid not null,
  value_kind text not null,
  value_decimal numeric,
  value_integer bigint,
  value_text text,
  value_boolean boolean,
  unit_id uuid references ref.units(id) on delete restrict,
  valid_at timestamptz not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  grid_cell_reference text,
  created_at timestamptz not null default now(),
  foreign key (parameter_id, value_kind) references ref.parameters(id, value_kind) on delete restrict,
  check (
    (value_kind = 'decimal' and value_decimal is not null and value_integer is null and value_text is null and value_boolean is null)
    or (value_kind = 'integer' and value_decimal is null and value_integer is not null and value_text is null and value_boolean is null)
    or (value_kind = 'text' and value_decimal is null and value_integer is null and value_text is not null and value_boolean is null)
    or (value_kind = 'boolean' and value_decimal is null and value_integer is null and value_text is null and value_boolean is not null)
  ),
  check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180)),
  check ((latitude is not null and longitude is not null and grid_cell_reference is null)
      or (latitude is null and longitude is null and grid_cell_reference is not null))
);

create table weather.forecast_parameter_mappings (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references weather.providers(id) on delete restrict,
  provider_parameter_code text not null,
  parameter_id uuid not null references ref.parameters(id) on delete restrict,
  provider_unit_code text,
  mapping_version text not null,
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  check (valid_to is null or valid_to > valid_from),
  unique (provider_id, provider_parameter_code, mapping_version)
);

create table weather.provider_payload_references (
  id uuid primary key default gen_random_uuid(),
  ingestion_run_id uuid not null references weather.ingestion_runs(id) on delete restrict,
  file_object_id uuid not null references files.objects(id) on delete restrict,
  payload_kind text not null check (payload_kind in ('request','response','manifest','other')),
  captured_at timestamptz not null default now(),
  retention_until timestamptz,
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  unique (ingestion_run_id, file_object_id)
);

-- Alert lifecycle and delivery traceability.
create table alerts.alert_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique,
  name_ar text not null,
  name_en text not null,
  rule_kind text not null check (rule_kind in ('official_feed','threshold','system')),
  rule_definition jsonb not null default '{}'::jsonb check (jsonb_typeof(rule_definition) = 'object'),
  rule_state text not null default 'inactive' check (rule_state in ('active','inactive','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table alerts.alert_events (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid references alerts.alert_rules(id) on delete restrict,
  provider_id uuid references weather.providers(id) on delete restrict,
  external_reference text,
  alert_code text,
  severity text not null check (severity in ('unknown','minor','moderate','severe','extreme')),
  headline text not null,
  description text,
  area_reference text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_state text not null default 'active' check (event_state in ('active','updated','expired','cancelled')),
  source_payload_reference_id uuid references weather.provider_payload_references(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at > starts_at),
  unique (provider_id, external_reference)
);

create table alerts.alert_recipients (
  id uuid primary key default gen_random_uuid(),
  alert_event_id uuid not null references alerts.alert_events(id) on delete restrict,
  user_id uuid references iam.user_profiles(user_id) on delete restrict,
  organization_id uuid references iam.organizations(id) on delete restrict,
  station_id uuid references catalog.stations(id) on delete restrict,
  delivery_channel text not null check (delivery_channel in ('in_app','email','sms','push')),
  delivery_state text not null default 'queued'
    check (delivery_state in ('queued','sent','delivered','failed','acknowledged')),
  queued_at timestamptz not null default now(),
  delivered_at timestamptz,
  acknowledged_at timestamptz,
  check (num_nonnulls(user_id, organization_id, station_id) = 1),
  unique (alert_event_id, user_id, organization_id, station_id, delivery_channel)
);

-- Station equipment, fault handling and support workflow.
create table operations.equipment (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  equipment_code text not null,
  equipment_kind text not null,
  manufacturer text,
  model text,
  serial_number text,
  installed_at date,
  equipment_state text not null default 'active'
    check (equipment_state in ('planned','active','maintenance','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (station_id, equipment_code)
);

create table operations.equipment_faults (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references catalog.stations(id) on delete restrict,
  equipment_id uuid references operations.equipment(id) on delete restrict,
  reporter_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  assigned_to_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  fault_code text,
  title text not null,
  description text not null,
  severity text not null check (severity in ('low','medium','high','critical')),
  fault_state text not null default 'open'
    check (fault_state in ('open','triaged','assigned','in_progress','resolved','closed','reopened')),
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table operations.equipment_fault_events (
  id uuid primary key default gen_random_uuid(),
  fault_id uuid not null references operations.equipment_faults(id) on delete restrict,
  actor_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  event_code text not null,
  previous_state text,
  resulting_state text,
  note text,
  occurred_at timestamptz not null default now()
);

create table operations.support_incidents (
  id uuid primary key default gen_random_uuid(),
  station_id uuid references catalog.stations(id) on delete restrict,
  reporter_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  assigned_to_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  category_code text not null,
  title text not null,
  description text not null,
  priority text not null check (priority in ('low','normal','high','urgent')),
  incident_state text not null default 'open'
    check (incident_state in ('open','triaged','assigned','in_progress','waiting','resolved','closed','reopened')),
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table operations.support_incident_events (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references operations.support_incidents(id) on delete restrict,
  actor_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  event_code text not null,
  previous_state text,
  resulting_state text,
  note text,
  occurred_at timestamptz not null default now()
);

-- Integration orchestration and append-only audit trail.
create table integration.sources (
  id uuid primary key default gen_random_uuid(),
  source_code text not null unique,
  name text not null,
  source_kind text not null
    check (source_kind in ('station_catalogue','forecast','alert','climate','identity','other')),
  contract_version text,
  endpoint_reference text,
  source_state text not null default 'planned'
    check (source_state in ('planned','active','suspended','retired')),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table integration.execution_runs (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references integration.sources(id) on delete restrict,
  operation_code text not null,
  idempotency_key text not null,
  run_state text not null default 'queued'
    check (run_state in ('queued','running','succeeded','partial','failed','cancelled')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  result_summary jsonb check (result_summary is null or jsonb_typeof(result_summary) = 'object'),
  error_code text,
  correlation_id uuid,
  check (completed_at is null or completed_at >= started_at),
  unique (source_id, idempotency_key)
);

create table audit.events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid references iam.user_profiles(user_id) on delete restrict,
  action_code text not null,
  entity_schema text not null,
  entity_table text not null,
  entity_id uuid,
  organization_id uuid references iam.organizations(id) on delete restrict,
  station_id uuid references catalog.stations(id) on delete restrict,
  outcome text not null check (outcome in ('success','denied','failure')),
  correlation_id uuid,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);

-- Auth profile projection: metadata is used only for display, never authorization.
create function private.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into iam.user_profiles (user_id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created_metra
after insert on auth.users
for each row execute function private.handle_auth_user_created();

insert into iam.user_profiles (user_id, email, display_name)
select u.id, u.email,
       coalesce(u.raw_user_meta_data ->> 'display_name', u.raw_user_meta_data ->> 'full_name')
from auth.users u
on conflict (user_id) do nothing;

-- Initial role and permission catalogue. No users or grants are provisioned.
insert into iam.roles (role_code, name_ar, name_en, description, is_system_role, is_assignable, is_requestable)
values
 ('platform_admin','مدير المنصة','Platform administrator','إدارة تقنية شاملة للمنصة',true,true,false),
 ('organization_admin','مدير الجهة','Organization administrator','إدارة عضويات وصلاحيات الجهة ضمن نطاقها',true,true,true),
 ('station_manager','رئيس محطة','Station manager','إدارة سير العمل ضمن محطة محددة',true,true,true),
 ('observer','راصد جوي','Weather observer','إدخال قراءات الرصد المصرح بها',true,true,true),
 ('catalogue_reviewer','مراجع دليل المحطات','Station catalogue reviewer','مراجعة بيانات المحطات واعتمادها',true,true,false),
 ('data_reviewer','مراجع بيانات الرصد','Observation reviewer','مراجعة واعتماد سجلات الرصد',true,true,true),
 ('forecast_analyst','محلل تنبؤات','Forecast analyst','إدارة وتحليل بيانات التنبؤ',true,true,true),
 ('maintenance_technician','فني صيانة','Maintenance technician','متابعة أعطال تجهيزات المحطات',true,true,true),
 ('support_agent','موظف دعم','Support agent','معالجة بلاغات الدعم الفني',true,true,false),
 ('auditor','مدقق','Auditor','قراءة سجلات التدقيق ضمن نطاق معتمد',true,true,false);

insert into iam.permissions (permission_code, name_ar, name_en, permission_domain)
values
 ('stations.read','قراءة المحطات','Read stations','stations'),
 ('stations.manage','إدارة المحطات','Manage stations','stations'),
 ('stations.review','مراجعة دليل المحطات','Review station catalogue','stations'),
 ('memberships.manage','إدارة العضويات','Manage memberships','iam'),
 ('roles.assign','تعيين الأدوار','Assign roles','iam'),
 ('permissions.grant','منح الصلاحيات','Grant permissions','iam'),
 ('observations.create','إنشاء رصد','Create observations','observations'),
 ('observations.read_own','قراءة رصدي','Read own observations','observations'),
 ('observations.read_station','قراءة رصد المحطة','Read station observations','observations'),
 ('observations.review','مراجعة الرصد','Review observations','observations'),
 ('observations.quality.manage','إدارة جودة الرصد','Manage observation quality','observations'),
 ('forecasts.read','قراءة التنبؤات','Read forecasts','weather'),
 ('forecasts.manage','إدارة التنبؤات','Manage forecasts','weather'),
 ('alerts.read','قراءة التنبيهات','Read alerts','alerts'),
 ('alerts.manage','إدارة التنبيهات','Manage alerts','alerts'),
 ('operations.faults.create','إنشاء بلاغ عطل','Create equipment faults','operations'),
 ('operations.faults.read','قراءة الأعطال','Read equipment faults','operations'),
 ('operations.faults.resolve','معالجة الأعطال','Resolve equipment faults','operations'),
 ('operations.support.create','إنشاء بلاغ دعم','Create support incidents','operations'),
 ('operations.support.read','قراءة بلاغات الدعم','Read support incidents','operations'),
 ('operations.support.resolve','معالجة بلاغات الدعم','Resolve support incidents','operations'),
 ('files.upload','رفع الملفات','Upload files','files'),
 ('files.read','قراءة الملفات','Read files','files'),
 ('audit.read','قراءة التدقيق','Read audit trail','audit'),
 ('integration.manage','إدارة التكاملات','Manage integrations','integration');

-- Least-privilege role matrix; scope is enforced by assignments/grants and the backend.
insert into iam.role_permissions (role_id, permission_id)
select r.id, p.id
from iam.roles r
join iam.permissions p on p.permission_code = any (
  case r.role_code
    when 'platform_admin' then array[
      'stations.read','stations.manage','stations.review','memberships.manage','roles.assign','permissions.grant',
      'observations.create','observations.read_own','observations.read_station','observations.review','observations.quality.manage',
      'forecasts.read','forecasts.manage','alerts.read','alerts.manage','operations.faults.create','operations.faults.read',
      'operations.faults.resolve','operations.support.create','operations.support.read','operations.support.resolve',
      'files.upload','files.read','audit.read','integration.manage'
    ]
    when 'organization_admin' then array[
      'stations.read','memberships.manage','roles.assign','observations.read_station','forecasts.read',
      'alerts.read','operations.faults.read','operations.support.read','files.read'
    ]
    when 'station_manager' then array[
      'stations.read','observations.read_own','observations.read_station','observations.review',
      'operations.faults.create','operations.faults.read','operations.support.create','operations.support.read','files.upload','files.read'
    ]
    when 'observer' then array[
      'stations.read','observations.create','observations.read_own','files.upload'
    ]
    when 'catalogue_reviewer' then array['stations.read','stations.review']
    when 'data_reviewer' then array[
      'stations.read','observations.read_station','observations.review','observations.quality.manage','files.read'
    ]
    when 'forecast_analyst' then array['stations.read','forecasts.read','forecasts.manage','alerts.read']
    when 'maintenance_technician' then array[
      'stations.read','operations.faults.create','operations.faults.read','operations.faults.resolve','files.upload','files.read'
    ]
    when 'support_agent' then array[
      'operations.support.create','operations.support.read','operations.support.resolve','files.read'
    ]
    when 'auditor' then array['stations.read','observations.read_station','forecasts.read','alerts.read','audit.read']
    else array[]::text[]
  end
);

insert into catalog.station_types (type_code, name_ar, name_en)
values
 ('synoptic','محطة رصد سينوبتيكي','Synoptic station'),
 ('automatic','محطة رصد آلية','Automatic weather station'),
 ('climatological','محطة مناخية','Climatological station'),
 ('upper_air','محطة رصد طبقات الجو العليا','Upper-air station'),
 ('marine','محطة أرصاد بحرية','Marine meteorological station'),
 ('agrometeorological','محطة أرصاد زراعية','Agrometeorological station'),
 ('other','نوع آخر','Other station type');

insert into ref.observation_types (type_code, name_ar, name_en, cadence_code)
values
 ('hourly','رصد ساعي','Hourly observation','hourly'),
 ('daily','رصد يومي','Daily observation','daily'),
 ('phenomenon','ظاهرة جوية','Weather phenomenon','event');

-- Helpful indexes for foreign keys, queues, and time-series access.
create index memberships_user_state_idx on iam.memberships(user_id, membership_state);
create index memberships_org_state_idx on iam.memberships(organization_id, membership_state);
create index organization_units_parent_idx on iam.organization_units(parent_unit_id);
create index stations_owner_status_idx on catalog.stations(owner_organization_id, approval_status, operational_status);
create index station_identifiers_station_idx on catalog.station_identifiers(station_id);
create index station_locations_station_valid_idx on catalog.station_locations(station_id, valid_from desc);
create index station_capabilities_station_idx on catalog.station_capabilities(station_id, capability_code);
create index station_operating_periods_station_idx on catalog.station_operating_periods(station_id, valid_from desc);
create index station_reviews_station_time_idx on catalog.station_reviews(station_id, decided_at desc);
create index role_assignments_membership_state_idx on iam.role_assignments(membership_id, assignment_state, valid_from);
create index role_assignments_station_scope_idx on iam.role_assignments(station_id, assignment_state);
create index permission_grants_user_permission_idx on iam.permission_grants(user_id, permission_id, grant_state);
create index registration_requests_queue_idx on iam.registration_requests(request_state, submitted_at);
create index registration_requests_station_idx on iam.registration_requests(requested_station_id, request_state);
create index registration_decisions_request_time_idx on iam.registration_decisions(request_id, decided_at desc);
create index observation_submissions_station_time_idx on observations.submissions(station_id, observed_at desc);
create index observation_submissions_author_time_idx on observations.submissions(author_user_id, created_at desc);
create index observation_submissions_state_idx on observations.submissions(submission_state, submitted_at);
create index observation_values_submission_idx on observations.values(submission_id, parameter_id);
create index observation_revisions_submission_idx on observations.revisions(submission_id, revision_number desc);
create index observation_reviews_submission_idx on observations.review_decisions(submission_id, decided_at desc);
create index quality_flags_open_idx on observations.quality_flags(flag_state, severity, raised_at desc);
create index ingestion_runs_provider_time_idx on weather.ingestion_runs(provider_id, started_at desc);
create index forecast_runs_provider_issued_idx on weather.forecast_runs(provider_id, issued_at desc);
create index forecast_points_run_time_idx on weather.forecast_points(forecast_run_id, valid_at, parameter_id);
create index alert_events_state_time_idx on alerts.alert_events(event_state, starts_at desc);
create index alert_recipients_user_state_idx on alerts.alert_recipients(user_id, delivery_state, queued_at desc);
create index equipment_station_state_idx on operations.equipment(station_id, equipment_state);
create index equipment_faults_station_state_idx on operations.equipment_faults(station_id, fault_state, reported_at desc);
create index equipment_faults_assignee_idx on operations.equipment_faults(assigned_to_user_id, fault_state);
create index support_incidents_station_state_idx on operations.support_incidents(station_id, incident_state, reported_at desc);
create index support_incidents_assignee_idx on operations.support_incidents(assigned_to_user_id, incident_state);
create index integration_runs_source_time_idx on integration.execution_runs(source_id, started_at desc);
create index audit_events_time_idx on audit.events(occurred_at desc);
create index audit_events_actor_time_idx on audit.events(actor_user_id, occurred_at desc);
create index audit_events_station_time_idx on audit.events(station_id, occurred_at desc);

-- updated_at triggers.
do $$
declare r record;
begin
  for r in
    select n.nspname, c.relname
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('iam','catalog','ref','observations','weather','alerts','operations','files','integration','audit')
      and c.relkind='r'
      and exists (
        select 1 from information_schema.columns col
        where col.table_schema=n.nspname and col.table_name=c.relname and col.column_name='updated_at'
      )
  loop
    execute format('create trigger set_updated_at before update on %I.%I for each row execute function private.set_updated_at()', r.nspname, r.relname);
  end loop;
end $$;

-- Append-only decision and audit histories.
create trigger station_reviews_append_only before update or delete on catalog.station_reviews
for each row execute function private.reject_mutation();
create trigger registration_decisions_append_only before update or delete on iam.registration_decisions
for each row execute function private.reject_mutation();
create trigger observation_revisions_append_only before update or delete on observations.revisions
for each row execute function private.reject_mutation();
create trigger observation_review_decisions_append_only before update or delete on observations.review_decisions
for each row execute function private.reject_mutation();
create trigger equipment_fault_events_append_only before update or delete on operations.equipment_fault_events
for each row execute function private.reject_mutation();
create trigger support_incident_events_append_only before update or delete on operations.support_incident_events
for each row execute function private.reject_mutation();
create trigger audit_events_append_only before update or delete on audit.events
for each row execute function private.reject_mutation();

-- Lock down every application table. Server-side service_role is the only DB API principal granted.
do $$
declare r record;
begin
  for r in
    select n.nspname, c.relname
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('iam','catalog','ref','observations','weather','alerts','operations','files','integration','audit')
      and c.relkind='r'
  loop
    execute format('alter table %I.%I enable row level security', r.nspname, r.relname);
  end loop;
end $$;

revoke all on schema iam, catalog, ref, observations, weather, alerts, operations, files, integration, audit, private from public, anon, authenticated;
grant usage on schema iam, catalog, ref, observations, weather, alerts, operations, files, integration, audit, private to service_role;
grant select, insert, update, delete on all tables in schema iam, catalog, ref, observations, weather, alerts, operations, files, integration, audit to service_role;
grant usage, select on all sequences in schema audit to service_role;
grant execute on all functions in schema private to service_role;
revoke all on all functions in schema private from public, anon, authenticated;

-- No application tables are exposed through public/PostgREST. Auth and Storage remain intact.
