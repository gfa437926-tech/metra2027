
alter table iam.registration_requests
  add constraint registration_requests_station_organization_fk
  foreign key (requested_station_id, organization_id)
  references catalog.stations(id, owner_organization_id) on delete restrict;

alter table operations.equipment
  add constraint equipment_id_station_uq unique (id, station_id);

alter table operations.equipment_faults
  add constraint equipment_faults_equipment_station_fk
  foreign key (equipment_id, station_id)
  references operations.equipment(id, station_id) on delete restrict;

create table iam.access_reviews (
  id uuid primary key default gen_random_uuid(),
  role_assignment_id uuid references iam.role_assignments(id) on delete restrict,
  permission_grant_id uuid references iam.permission_grants(id) on delete restrict,
  reviewer_user_id uuid not null references iam.user_profiles(user_id) on delete restrict,
  review_decision text not null check (review_decision in ('retain','modify','revoke')),
  reason text not null check (length(trim(reason)) >= 5),
  reviewed_at timestamptz not null default now(),
  next_review_at timestamptz,
  check (num_nonnulls(role_assignment_id, permission_grant_id) = 1),
  check (next_review_at is null or next_review_at > reviewed_at)
);

create index access_reviews_role_assignment_time_idx
  on iam.access_reviews(role_assignment_id, reviewed_at desc);
create index access_reviews_permission_grant_time_idx
  on iam.access_reviews(permission_grant_id, reviewed_at desc);
create index access_reviews_reviewer_time_idx
  on iam.access_reviews(reviewer_user_id, reviewed_at desc);

alter table iam.access_reviews enable row level security;
grant select, insert, update, delete on iam.access_reviews to service_role;

create trigger access_reviews_append_only
before update or delete on iam.access_reviews
for each row execute function private.reject_mutation();

do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    select c.conrelid as relid, c.conname,
           array_agg(a.attnum::smallint order by k.ord) as fk_attnums,
           array_agg(a.attname order by k.ord) as fk_names,
           string_agg(format('%I', a.attname), ', ' order by k.ord) as fk_sql
    from pg_constraint c
    cross join lateral unnest(c.conkey) with ordinality k(attnum, ord)
    join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum
    join pg_class t on t.oid=c.conrelid
    join pg_namespace n on n.oid=t.relnamespace
    where c.contype='f'
      and n.nspname in ('iam','catalog','ref','observations','weather','alerts','operations','files','integration','audit')
    group by c.conrelid,c.conname
  loop
    if not exists (
      select 1 from pg_index i
      where i.indrelid=r.relid and i.indisvalid and i.indisready
        and (
          select array_agg(x.attnum::smallint order by x.ord)
          from unnest(i.indkey::smallint[]) with ordinality x(attnum,ord)
          where x.ord <= cardinality(r.fk_attnums)
        ) = r.fk_attnums
    ) then
      v_index_name := left((r.relid::regclass::text || '_' || array_to_string(r.fk_names,'_') || '_fk_idx'),54)
                      || '_' || substr(md5(r.conname),1,8);
      execute format('create index %I on %s (%s)',v_index_name,r.relid::regclass,r.fk_sql);
    end if;
  end loop;
end $$;
