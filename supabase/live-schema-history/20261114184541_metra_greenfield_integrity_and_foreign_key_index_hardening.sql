
alter table iam.role_assignments
  add constraint role_assignments_membership_id_fkey
  foreign key (membership_id) references iam.memberships(id) on delete restrict;

create unique index alert_recipients_target_channel_uq
  on alerts.alert_recipients (alert_event_id, user_id, organization_id, station_id, delivery_channel)
  nulls not distinct;

do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    select
      c.conrelid as relid,
      c.conname,
      array_agg(a.attnum::smallint order by k.ord) as fk_attnums,
      array_agg(a.attname order by k.ord) as fk_names,
      string_agg(format('%I', a.attname), ', ' order by k.ord) as fk_sql
    from pg_constraint c
    cross join lateral unnest(c.conkey) with ordinality k(attnum, ord)
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f'
      and n.nspname in ('iam','catalog','ref','observations','weather','alerts','operations','files','integration','audit')
    group by c.conrelid, c.conname
  loop
    if not exists (
      select 1
      from pg_index i
      where i.indrelid = r.relid
        and i.indisvalid
        and i.indisready
        and (
          select array_agg(x.attnum::smallint order by x.ord)
          from unnest(i.indkey::smallint[]) with ordinality x(attnum, ord)
          where x.ord <= cardinality(r.fk_attnums)
        ) = r.fk_attnums
    ) then
      v_index_name := left((r.relid::regclass::text || '_' || array_to_string(r.fk_names, '_') || '_fk_idx'), 54)
                      || '_' || substr(md5(r.conname), 1, 8);
      execute format('create index %I on %s (%s)', v_index_name, r.relid::regclass, r.fk_sql);
    end if;
  end loop;
end $$;
