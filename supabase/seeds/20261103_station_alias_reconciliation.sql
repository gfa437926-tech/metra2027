-- Reconcile only explicitly reviewed legacy station-name aliases.
-- Safe to re-run. This changes METRA destination observation links only.
-- It never connects to or writes to the legacy INSERT project.
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
  join aliases a
    on btrim(o.station_name_source) = a.source_name
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
