-- Verify the non-destructive INSERT observation import.
-- Run against the METRA destination database after importing source records.
do $$
declare
  duplicate_count bigint;
  invalid_payload_count bigint;
  identity_leak_count bigint;
  demo_import_count bigint;
  missing_provenance_count bigint;
begin
  select count(*) into duplicate_count
  from (
    select source_system,source_table,source_record_id
    from public.metra_observation_records
    where source_system='INSERT'
    group by source_system,source_table,source_record_id
    having count(*)>1
  ) d;
  if duplicate_count <> 0 then
    raise exception 'Duplicate source identities found: %', duplicate_count;
  end if;

  select count(*) into invalid_payload_count
  from public.metra_observation_records
  where source_system='INSERT' and jsonb_typeof(payload) <> 'object';
  if invalid_payload_count <> 0 then
    raise exception 'Non-object observation payloads found: %', invalid_payload_count;
  end if;

  select count(*) into identity_leak_count
  from public.metra_observation_records
  where source_system='INSERT'
    and payload ?| array[
      'user_id','user_name','user_email','user_role',
      'observer_name','observer_role','user_agent',
      'browser_language','observer_id'
    ];
  if identity_leak_count <> 0 then
    raise exception 'Personal identity fields remain in imported payloads: %', identity_leak_count;
  end if;

  select count(*) into demo_import_count
  from public.metra_observation_records
  where source_system='INSERT' and is_demo;
  if demo_import_count <> 0 then
    raise exception 'Legacy source records must not be marked as synthetic demo data: %', demo_import_count;
  end if;

  select count(*) into missing_provenance_count
  from public.metra_observation_records
  where source_system='INSERT'
    and (source_table is null or source_record_id is null);
  if missing_provenance_count <> 0 then
    raise exception 'Imported rows without complete provenance: %', missing_provenance_count;
  end if;

  raise notice 'PASS: imported observations have unique source keys, object payloads, provenance, no identity keys, and no demo flag';
end
$$;
