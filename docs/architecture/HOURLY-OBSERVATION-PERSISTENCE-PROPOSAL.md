# Hourly observation persistence — schema proposal (NOT APPLIED)

**Status:** implementation draft for review only. This file is not a Supabase migration and has not been executed against any database. Do not apply it until the METRA schema owner approves the table names, retention rules, and access model.

## Scope

Create a dedicated persistence boundary for hourly observations in the new METRA database only. It does not import or reference legacy station identifiers or legacy observation tables.

The proposed ASP.NET adapter is:
- `backend/Metra.Api/Infrastructure/Database/NpgsqlHourlyObservationStore.cs`

It writes an observation and its `submitted` audit event in one PostgreSQL transaction. Review locks the observation, rechecks the reviewer's active account, permission, and current station assignment, then updates the status and inserts the audit event in the same transaction. A failed audit insert rolls back the report mutation.

## Proposed SQL

The following SQL is a review artifact only. It has **not** been run.

```sql
create table public.hourly_observations (
  id uuid primary key,
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  observation_date date not null,
  utc_hour smallint not null,
  observation_values jsonb not null,
  status text not null default 'pending_review',
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  review_note text,
  constraint hourly_observations_hour_check check (utc_hour between 0 and 23),
  constraint hourly_observations_values_object_check
    check (jsonb_typeof(observation_values) = 'object'),
  constraint hourly_observations_status_check
    check (status in ('pending_review', 'approved', 'rejected')),
  constraint hourly_observations_review_consistency
    check ((reviewed_by is null) = (reviewed_at is null)),
  constraint hourly_observations_review_state_check
    check ((status = 'pending_review' and reviewed_by is null)
        or (status in ('approved','rejected') and reviewed_by is not null)),
  constraint hourly_observations_review_note_check
    check (review_note is null or length(review_note) <= 1000)
);

create index hourly_observations_station_time_idx
  on public.hourly_observations(station_id, observation_date desc, utc_hour desc);
create index hourly_observations_submitter_history_idx
  on public.hourly_observations(submitted_by, submitted_at desc, id desc);
create index hourly_observations_review_queue_idx
  on public.hourly_observations(station_id, submitted_at, id)
  where status = 'pending_review';

create table public.hourly_observation_audit_events (
  id bigint generated always as identity primary key,
  observation_id uuid not null references public.hourly_observations(id) on delete restrict,
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null,
  from_status text,
  to_status text not null,
  note text,
  occurred_at timestamptz not null default now(),
  constraint hourly_observation_audit_event_type_check
    check (event_type in ('submitted','approved','rejected')),
  constraint hourly_observation_audit_status_check
    check (to_status in ('pending_review','approved','rejected')
       and (from_status is null or from_status in ('pending_review','approved','rejected'))),
  constraint hourly_observation_audit_note_check
    check (note is null or length(note) <= 1000)
);

create index hourly_observation_audit_history_idx
  on public.hourly_observation_audit_events(observation_id, occurred_at desc, id desc);

create or replace function private.reject_hourly_observation_audit_mutation()
returns trigger language plpgsql set search_path = pg_catalog
as $$
begin
  raise exception 'hourly observation audit events are append-only'
    using errcode = '55000';
end;
$$;
revoke all on function private.reject_hourly_observation_audit_mutation()
  from public, anon, authenticated;
create trigger hourly_observation_audit_events_append_only
  before update or delete on public.hourly_observation_audit_events
  for each row execute function private.reject_hourly_observation_audit_mutation();

alter table public.hourly_observations enable row level security;
alter table public.hourly_observation_audit_events enable row level security;

create policy hourly_observations_deny_clients
  on public.hourly_observations for all to anon, authenticated
  using (false) with check (false);
create policy hourly_observation_audit_deny_clients
  on public.hourly_observation_audit_events for all to anon, authenticated
  using (false) with check (false);

-- Runtime policies are deliberately limited to the non-login API role.
create policy hourly_observations_api_runtime_read
  on public.hourly_observations for select to metra_api_runtime using (true);
create policy hourly_observations_api_runtime_insert
  on public.hourly_observations for insert to metra_api_runtime with check (true);
create policy hourly_observations_api_runtime_update
  on public.hourly_observations for update to metra_api_runtime
  using (true) with check (true);
create policy hourly_observation_audit_api_runtime_read
  on public.hourly_observation_audit_events for select to metra_api_runtime using (true);
create policy hourly_observation_audit_api_runtime_insert
  on public.hourly_observation_audit_events for insert to metra_api_runtime with check (true);

revoke all on public.hourly_observations, public.hourly_observation_audit_events
  from anon, authenticated, service_role;
grant select, insert, update on public.hourly_observations to metra_api_runtime;
grant select, insert on public.hourly_observation_audit_events to metra_api_runtime;
grant usage, select on sequence public.hourly_observation_audit_events_id_seq
  to metra_api_runtime;
```

## Station review queue API (implemented, feature-flagged)

The API now includes an authenticated, read-only queue endpoint:

- `GET /api/v1/observations/hourly/review-queue`
- Optional query parameters: `stationId`, `pageSize` (default 50, maximum 100), and `cursor`.
- The response contains only queue metadata: observation ID, station ID, observation date, UTC hour, submitter account ID, and submission time. It does not return the JSON observation values.
- The application service requires an active actor, the `observations.hourly.review` permission, and at least one effective station assignment. A requested station must belong to that actor's effective assignments.
- The PostgreSQL query independently rechecks the active account, approved/unexpired review permission, and approved/unexpired assignment against authoritative identity tables on every page.
- Paging uses a stable descending `(submitted_at, id)` keyset. Continuation tokens are protected with ASP.NET Core Data Protection and bound to the actor, station filter, and page size.

The API endpoint, query service, PostgreSQL adapter, and service-level tests are committed, but have not yet been built or executed against PostgreSQL. The workflow flag remains disabled by default.

## Additional activation prerequisites

The queue query reads `metra_account_states`, `permission_grants`, and `station_assignments`. Before activation, verify that the dedicated `metra_api_runtime` database principal has only the required read access to these identity tables and that applicable RLS policies permit the API query without granting access to client roles. The table grants in this proposal do not by themselves grant access to those identity tables.

In multi-instance or redeployed production environments, configure a durable, shared ASP.NET Core Data Protection key ring. Otherwise, review-queue continuation cursors may become invalid after a process restart or on another API instance.

## Required review decisions

1. Confirm that `station_catalogue.id`, `auth.users.id`, `metra_account_states`, `permission_grants`, and `station_assignments` are the authoritative new-project references.
2. Confirm retention and archival periods for observations and immutable audit events.
3. Confirm whether the same station may submit more than one observation for the same UTC date/hour, and whether a correction workflow is required.
4. Confirm the runtime role is the intended database principal and is not the Supabase owner or `service_role`.

## Current implementation boundary

- The adapter is committed and is registered/mapped only when the explicit configuration flag `Features:HourlyObservationWorkflowEnabled=true` is enabled. The flag also requires `ConnectionStrings:MetraDatabase`.
- Keep the flag disabled until this proposal is approved, the schema is applied, and the API runtime login has the exact table grants. The default is disabled.
- No database schema, data, RLS policy, role, or permission was changed by this proposal.
- Before enabling the endpoints, apply an approved migration, provision the least-privilege runtime login, and run database integration tests for atomic insert/audit, authorization revocation races, and concurrent review.
