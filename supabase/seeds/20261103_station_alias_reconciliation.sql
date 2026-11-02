-- Reconcile station labels from imported observation payloads.
-- Safe to re-run. This changes METRA destination observation links only.
-- It never connects to or writes to the legacy INSERT project.

-- The legacy phenomenon table stores its source station label in station_name.
update public.metra_observation_records
set station_name_source = nullif(btrim(payload->>'station_name'), '')
where source_system = 'INSERT'
  and source_table = 'weather_phenomena'
  and station_name_source is null;

-- Link exact source labels only; no fuzzy matching or nearest-station inference.
update public.metra_observation_records o
set station_id = s.id
from public.station_catalogue s
where o.source_system = 'INSERT'
  and o.station_id is null
  and s.source_system = 'INSERT'
  and s.is_demo = false
  and lower(btrim(o.station_name_source)) = lower(btrim(s.name_ar));

-- Reconcile only explicitly reviewed station-name aliases.
with aliases(source_name,canonical_station_name) as (
  values
    ('محطة حمص','حمص'),
    ('مطار دمشق','مطار دمشق الدولي'),
    ('محطة اللاذقية','اللاذقية'),
    ('محطة السويداء','السويداء'),
    ('محطة طرطوس','طرطوس')
),
mapping as (
  select o.id as observation_id, s.id as station_id
  from public.metra_observation_records o
  join aliases a on btrim(o.station_name_source) = a.source_name
  join public.station_catalogue s
    on s.source_system = 'INSERT'
   and s.source_table = 'stations'
   and s.is_demo = false
   and btrim(s.name_ar) = a.canonical_station_name
  where o.source_system = 'INSERT'
    and o.station_id is null
)
update public.metra_observation_records o
set station_id = m.station_id
from mapping m
where o.id = m.observation_id;
