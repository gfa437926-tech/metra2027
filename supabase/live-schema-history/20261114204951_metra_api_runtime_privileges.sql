begin;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles where rolname = 'metra_api_runtime'
  ) then
    create role metra_api_runtime
      nologin nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
end
$$;

comment on role metra_api_runtime is
  'Non-login, non-BYPASSRLS least-privilege role for the METRA ASP.NET API. A separate managed login must be granted membership; never connect as postgres or service_role.';

grant usage on schema iam, catalog, ref, observations, alerts, audit to metra_api_runtime;

grant select on
  iam.user_profiles,
  iam.organizations,
  iam.organization_units,
  iam.memberships,
  iam.roles,
  iam.permissions,
  iam.role_permissions,
  iam.role_assignments,
  iam.permission_grants,
  iam.registration_requests,
  iam.registration_decisions
to metra_api_runtime;

grant update (given_name, father_name, family_name, display_name, phone_e164, updated_at)
  on iam.user_profiles to metra_api_runtime;
grant insert on iam.registration_requests to metra_api_runtime;
grant update (request_state, resolved_at)
  on iam.registration_requests to metra_api_runtime;
grant insert on iam.registration_decisions to metra_api_runtime;
grant insert on iam.memberships to metra_api_runtime;
grant insert on iam.role_assignments to metra_api_runtime;

grant select on
  catalog.stations,
  catalog.station_types,
  catalog.station_locations
to metra_api_runtime;
grant update (approval_status, updated_by, updated_at)
  on catalog.stations to metra_api_runtime;
grant insert on catalog.station_reviews to metra_api_runtime;

grant select on
  ref.observation_types,
  ref.parameters,
  ref.units
to metra_api_runtime;

grant select on
  observations.submissions,
  observations."values",
  observations.revisions,
  observations.review_decisions
to metra_api_runtime;
grant insert on observations.submissions to metra_api_runtime;
grant update (submission_state, updated_at)
  on observations.submissions to metra_api_runtime;
grant insert on observations."values" to metra_api_runtime;
grant insert on observations.revisions to metra_api_runtime;
grant insert on observations.review_decisions to metra_api_runtime;

grant select on alerts.alert_events, alerts.alert_recipients to metra_api_runtime;

grant insert on audit.events to metra_api_runtime;

drop policy if exists metra_api_runtime_select on iam.user_profiles;
create policy metra_api_runtime_select on iam.user_profiles
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_update on iam.user_profiles;
create policy metra_api_runtime_update on iam.user_profiles
  for update to metra_api_runtime using (true) with check (true);

drop policy if exists metra_api_runtime_select on iam.organizations;
create policy metra_api_runtime_select on iam.organizations
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.organization_units;
create policy metra_api_runtime_select on iam.organization_units
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.memberships;
create policy metra_api_runtime_select on iam.memberships
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on iam.memberships;
create policy metra_api_runtime_insert on iam.memberships
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_select on iam.roles;
create policy metra_api_runtime_select on iam.roles
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.permissions;
create policy metra_api_runtime_select on iam.permissions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.role_permissions;
create policy metra_api_runtime_select on iam.role_permissions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.role_assignments;
create policy metra_api_runtime_select on iam.role_assignments
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on iam.role_assignments;
create policy metra_api_runtime_insert on iam.role_assignments
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_select on iam.permission_grants;
create policy metra_api_runtime_select on iam.permission_grants
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on iam.registration_requests;
create policy metra_api_runtime_select on iam.registration_requests
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on iam.registration_requests;
create policy metra_api_runtime_insert on iam.registration_requests
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_update on iam.registration_requests;
create policy metra_api_runtime_update on iam.registration_requests
  for update to metra_api_runtime using (true) with check (true);
drop policy if exists metra_api_runtime_select on iam.registration_decisions;
create policy metra_api_runtime_select on iam.registration_decisions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on iam.registration_decisions;
create policy metra_api_runtime_insert on iam.registration_decisions
  for insert to metra_api_runtime with check (true);

drop policy if exists metra_api_runtime_select on catalog.stations;
create policy metra_api_runtime_select on catalog.stations
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_update on catalog.stations;
create policy metra_api_runtime_update on catalog.stations
  for update to metra_api_runtime using (true) with check (true);
drop policy if exists metra_api_runtime_select on catalog.station_types;
create policy metra_api_runtime_select on catalog.station_types
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on catalog.station_locations;
create policy metra_api_runtime_select on catalog.station_locations
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on catalog.station_reviews;
create policy metra_api_runtime_insert on catalog.station_reviews
  for insert to metra_api_runtime with check (true);

drop policy if exists metra_api_runtime_select on ref.observation_types;
create policy metra_api_runtime_select on ref.observation_types
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on ref.parameters;
create policy metra_api_runtime_select on ref.parameters
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on ref.units;
create policy metra_api_runtime_select on ref.units
  for select to metra_api_runtime using (true);

drop policy if exists metra_api_runtime_select on observations.submissions;
create policy metra_api_runtime_select on observations.submissions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on observations.submissions;
create policy metra_api_runtime_insert on observations.submissions
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_update on observations.submissions;
create policy metra_api_runtime_update on observations.submissions
  for update to metra_api_runtime using (true) with check (true);
drop policy if exists metra_api_runtime_select on observations."values";
create policy metra_api_runtime_select on observations."values"
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on observations."values";
create policy metra_api_runtime_insert on observations."values"
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_select on observations.revisions;
create policy metra_api_runtime_select on observations.revisions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on observations.revisions;
create policy metra_api_runtime_insert on observations.revisions
  for insert to metra_api_runtime with check (true);
drop policy if exists metra_api_runtime_select on observations.review_decisions;
create policy metra_api_runtime_select on observations.review_decisions
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_insert on observations.review_decisions;
create policy metra_api_runtime_insert on observations.review_decisions
  for insert to metra_api_runtime with check (true);

drop policy if exists metra_api_runtime_select on alerts.alert_events;
create policy metra_api_runtime_select on alerts.alert_events
  for select to metra_api_runtime using (true);
drop policy if exists metra_api_runtime_select on alerts.alert_recipients;
create policy metra_api_runtime_select on alerts.alert_recipients
  for select to metra_api_runtime using (true);

drop policy if exists metra_api_runtime_insert on audit.events;
create policy metra_api_runtime_insert on audit.events
  for insert to metra_api_runtime with check (true);

commit;
