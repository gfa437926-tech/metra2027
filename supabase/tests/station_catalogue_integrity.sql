-- Run only against a disposable database or a controlled test transaction.
-- Every inserted fixture is rolled back; this script leaves no station records.
begin;
do $$
declare
  country_id uuid;
  authority_id uuid;
  station_id uuid;
  coordinate_rejected boolean := false;
  grant_rejected boolean := false;
  official_source_rejected boolean := false;
begin
  insert into public.countries(iso2_code, iso3_code, name_ar, name_en)
  values (
    upper(substr(md5(gen_random_uuid()::text), 1, 2)),
    upper(substr(md5(gen_random_uuid()::text), 1, 3)),
    'اختبار مؤقت', 'Temporary test'
  ) returning id into country_id;

  insert into public.meteorological_authorities(country_id, authority_code, name_ar, name_en, is_national)
  values(country_id, 'TEST-' || substr(gen_random_uuid()::text,1,8), 'هيئة اختبار', 'Test authority', true)
  returning id into authority_id;

  insert into public.station_catalogue(country_id, owner_authority_id, local_station_code, name_ar, name_en)
  values(country_id, authority_id, 'TEST-' || substr(gen_random_uuid()::text,1,8), 'محطة اختبار', 'Test station')
  returning id into station_id;

  insert into public.station_coordinates(station_id, latitude, longitude, coordinate_source, valid_from, valid_to)
  values(station_id, 25, 45, 'gps', now() - interval '1 day', now() + interval '2 days');

  begin
    insert into public.station_coordinates(station_id, latitude, longitude, coordinate_source, valid_from, valid_to)
    values(station_id, 26, 46, 'gps', now() - interval '1 hour', now() + interval '1 day');
  exception when exclusion_violation then
    coordinate_rejected := true;
  end;
  if not coordinate_rejected then
    raise exception 'Expected overlapping coordinate period to be rejected';
  end if;

  begin
    insert into public.station_coordinates(station_id, latitude, longitude, coordinate_source, source_reference)
    values(station_id, 27, 47, 'official_record', null);
  exception when check_violation then
    official_source_rejected := true;
  end;
  if not official_source_rejected then
    raise exception 'Expected official coordinate without source reference to be rejected';
  end if;

  insert into public.station_access_grants(station_id, authority_id, access_level, approval_status, reason, valid_from, valid_to)
  values(station_id, authority_id, 'read_only', 'pending', 'Temporary test grant', now() - interval '1 day', now() + interval '2 days');

  begin
    insert into public.station_access_grants(station_id, authority_id, access_level, approval_status, reason, valid_from, valid_to)
    values(station_id, authority_id, 'station_editor', 'pending', 'Overlapping temporary test grant', now() - interval '1 hour', now() + interval '1 day');
  exception when exclusion_violation then
    grant_rejected := true;
  end;
  if not grant_rejected then
    raise exception 'Expected overlapping station access grant to be rejected';
  end if;

  raise notice 'PASS: overlapping coordinates, missing official source, and overlapping grants are rejected';
end
$$;
rollback;
