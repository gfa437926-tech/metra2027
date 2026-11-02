-- METRA 2027 station catalogue import.
-- Source project: legacy INSERT (vktcvkwqszehgmhqjrkb), accessed read-only.
-- Source tables: public.stations and public.fieldclimate_stations only.
-- No INSERT source table, row, policy, trigger, or setting is modified.
-- Safe to rerun: source identity is protected by a partial unique index.
-- All imported stations remain pending/unverified; missing coordinates stay NULL.
begin;
insert into public.countries (iso2_code,iso3_code,name_ar,name_en,is_active)
values ('SY','SYR','الجمهورية العربية السورية','Syrian Arab Republic',true)
on conflict (iso2_code) do nothing;
insert into public.meteorological_authorities (country_id,authority_code,name_ar,name_en,is_national,is_active)
select c.id,'LEGACY-UNASSIGNED','جهة مالكة غير محددة في بيانات المصدر','Unassigned legacy source owner',false,true
from public.countries c where c.iso2_code='SY'
on conflict (country_id,authority_code) do nothing;
with owner as (
 select a.id authority_id,a.country_id from public.meteorological_authorities a
 join public.countries c on c.id=a.country_id
 where c.iso2_code='SY' and a.authority_code='LEGACY-UNASSIGNED'
), source_rows(source_table,source_record_id,name_ar,name_en,station_type,latitude,longitude,elevation_m) as (
select 'stations'::text,'1'::text,'مركز بحوث الغاب','مركز بحوث الغاب','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'2'::text,'طرطوس الزراعي -عمريت','طرطوس الزراعي -عمريت','classic'::text,34.8353,35.9042,null::numeric
union all
select 'stations'::text,'3'::text,'السويداء','السويداء','classic'::text,32.709,36.5695,null::numeric
union all
select 'stations'::text,'4'::text,'طرطوس','طرطوس','classic'::text,34.889,35.8866,null::numeric
union all
select 'stations'::text,'5'::text,'حينة','حينة','classic'::text,33.35187,35.94196,null::numeric
union all
select 'stations'::text,'6'::text,'محطة حماه','محطة حماه','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'7'::text,'اللاذقية','اللاذقية','classic'::text,35.78,35.52,null::numeric
union all
select 'stations'::text,'8'::text,'بانياس','بانياس','classic'::text,35.1819,35.9487,null::numeric
union all
select 'stations'::text,'9'::text,'حمص','حمص','classic'::text,34.724,36.7256,null::numeric
union all
select 'stations'::text,'10'::text,'مطار دمشق الدولي','مطار دمشق الدولي','classic'::text,33.4114,36.5156,null::numeric
union all
select 'stations'::text,'11'::text,'صحنايا','صحنايا','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'12'::text,'حماه','حماه','classic'::text,35.1318,36.7578,null::numeric
union all
select 'stations'::text,'13'::text,'البوكمال','البوكمال','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'14'::text,'جرابلس','جرابلس','classic'::text,36.8175,38.0111,null::numeric
union all
select 'stations'::text,'15'::text,'دير الزور','دير الزور','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'16'::text,'حمام واصل','حمام واصل','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'17'::text,'القرداحة','القرداحة','classic'::text,36.05,35.45,null::numeric
union all
select 'stations'::text,'18'::text,'القنيطرة','القنيطرة','classic'::text,33.126,35.8246,null::numeric
union all
select 'stations'::text,'19'::text,'مطار حلب الدولي','مطار حلب الدولي','classic'::text,36.18056,37.22417,null::numeric
union all
select 'stations'::text,'20'::text,'الإدارة العامة','الإدارة العامة','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'21'::text,'درعا','درعا','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'22'::text,'سلمية','سلمية','classic'::text,35.0113,37.0532,null::numeric
union all
select 'stations'::text,'23'::text,'بوقا','بوقا','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'24'::text,'حلب الجامعية','حلب الجامعية','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'25'::text,'زاهد','زاهد','classic'::text,null,null,null::numeric
union all
select 'stations'::text,'26'::text,'صافيتا','صافيتا','classic'::text,34.8167,36.1333,null::numeric
union all
select 'stations'::text,'27'::text,'الحسكة','الحسكة','classic'::text,36.5024,40.7477,null::numeric
union all
select 'stations'::text,'28'::text,'القامشلي','القامشلي','classic'::text,37.0521,41.2314,null::numeric
union all
select 'stations'::text,'29'::text,'عين العرب الجنوبية','عين العرب الجنوبية','classic'::text,null,null,null::numeric
union all
select 'fieldclimate_stations'::text,'002127FE','KafrYhmol','KafrYhmol','automatic'::text,36.0498,36.707972,303.8
union all
select 'fieldclimate_stations'::text,'002127FF','IDLEB','IDLEB','automatic'::text,35.94052,36.62756,424.9
union all
select 'fieldclimate_stations'::text,'00212800','ورشات 4','ورشات 4','automatic'::text,33.49837,36.243488,758
union all
select 'fieldclimate_stations'::text,'00212807','ورشات 3','ورشات 3','automatic'::text,33.498288,36.243448,754.6
union all
select 'fieldclimate_stations'::text,'0021280E','واحة البطمة','واحة البطمة','automatic'::text,33.810224,37.228024,777
union all
select 'fieldclimate_stations'::text,'002134AF','Sahl Alroj','Sahl Alroj','automatic'::text,33.498388,36.243508,766.3
union all
select 'fieldclimate_stations'::text,'002134B5','جامعة حلب','جامعة حلب','automatic'::text,36.207996,37.11448,441.8
union all
select 'fieldclimate_stations'::text,'002134C2','الصبورة اكساد','الصبورة اكساد','automatic'::text,33.494416,36.124216,990.9
union all
select 'fieldclimate_stations'::text,'00213513','Azaz','Azaz','automatic'::text,36.779336,34.590812,9.8
union all
select 'fieldclimate_stations'::text,'00213515','Harem','Harem','automatic'::text,36.165856,36.474272,282.7
union all
select 'fieldclimate_stations'::text,'00214D87','عين الفيجة','عين الفيجة','automatic'::text,33.616668,36.173256,892
union all
select 'fieldclimate_stations'::text,'00214D8F','الحاطرية','الحاطرية','automatic'::text,35.110988,36.23936,1064.9
union all
select 'fieldclimate_stations'::text,'00214D90','Mabatli','Mabatli','automatic'::text,33.4983512890916,36.2434329497526,705
union all
select 'fieldclimate_stations'::text,'00214D91','سرغايا','سرغايا','automatic'::text,33.78888,36.143116,1422.2
union all
select 'fieldclimate_stations'::text,'00214D94','حماه- الكريم','حماه- الكريم','automatic'::text,35.396156,36.33058,175.6
union all
select 'fieldclimate_stations'::text,'00214D95','درعا-ازرع','درعا-ازرع','automatic'::text,32.84933,36.238352,571.7
union all
select 'fieldclimate_stations'::text,'00214D9D','مصياف','مصياف','automatic'::text,35.03312,36.332984,578.5
union all
select 'fieldclimate_stations'::text,'00214FFA','برزة زراعة','برزة زراعة','automatic'::text,33.537278,36.319336,723
union all
select 'fieldclimate_stations'::text,'00215B54','حينة','حينة','automatic'::text,33.345624,35.944832,1038.9
union all
select 'fieldclimate_stations'::text,'00216216','حلب صوران اعزاز','حلب صوران اعزاز','automatic'::text,36.58696,37.22648,470.9
union all
select 'fieldclimate_stations'::text,'00216219','حلب الباب','حلب الباب','automatic'::text,36.375328,37.497216,493.9
union all
select 'fieldclimate_stations'::text,'0021667B','حلب صربايا','حلب صربايا','automatic'::text,36.051168,36.928688,280.7
union all
select 'fieldclimate_stations'::text,'0021667D','حلب تل الطوقان','حلب تل الطوقان','automatic'::text,35.81852,36.942112,278.4
union all
select 'fieldclimate_stations'::text,'00216819','دير الزور المريعية','دير الزور المريعية','automatic'::text,35.27168,40.209752,201.8
union all
select 'fieldclimate_stations'::text,'002168CB','درعا االمدينة','درعا االمدينة','automatic'::text,32.62668,36.1198,528.1
union all
select 'fieldclimate_stations'::text,'002168CC','حلب تل حدية ايكاردا','حلب تل حدية ايكاردا','automatic'::text,35.997224,36.959152,276.7
union all
select 'fieldclimate_stations'::text,'002168CE','صلنفة','صلنفة','automatic'::text,35.605644,36.214268,1343.8
union all
select 'fieldclimate_stations'::text,'00216995','النبك','النبك','automatic'::text,34.019028,36.731604,1325
union all
select 'fieldclimate_stations'::text,'D0002592','AFRIN / VS','AFRIN / VS','automatic'::text,36.5119,36.8695,228.31
union all
select 'fieldclimate_stations'::text,'D0002593','JARABLUS / VS','JARABLUS / VS','automatic'::text,36.8175,38.0111,348.91
union all
select 'fieldclimate_stations'::text,'D0002594','AL-RAI / VS','AL-RAI / VS','automatic'::text,36.6119,37.4467,495
union all
select 'fieldclimate_stations'::text,'D0002595','Khirbet AL-JOZ / VS','Khirbet AL-JOZ / VS','automatic'::text,35.9014,36.1833,528.5
union all
select 'fieldclimate_stations'::text,'D0002596','Jabal al-Zawiya / VS','Jabal al-Zawiya / VS','automatic'::text,35.7014,36.4846,868
), inserted as (
 insert into public.station_catalogue
 (country_id,owner_authority_id,local_station_code,name_ar,name_en,station_type,
 operational_status,approval_status,source_system,source_table,source_record_id,
 is_demo,elevation_m,description)
 select o.country_id,o.authority_id,r.source_record_id,r.name_ar,r.name_en,r.station_type,
 'unverified','pending','INSERT',r.source_table,r.source_record_id,false,r.elevation_m,
 'Read-only import from legacy INSERT. Original source record retained; coordinates copied only when present in source.'
 from source_rows r cross join owner o
 on conflict (source_system,source_table,source_record_id)
 where source_table is not null and source_record_id is not null do nothing
 returning id,source_table,source_record_id
)
insert into public.station_coordinates
(station_id,latitude,longitude,coordinate_source,source_reference,accuracy_m,valid_from)
select i.id,r.latitude,r.longitude,'other',
 'INSERT.'||r.source_table||':'||r.source_record_id,null,now()
from inserted i join source_rows r using(source_table,source_record_id)
where r.latitude is not null and r.longitude is not null;
with owner as (
 select a.id authority_id,a.country_id from public.meteorological_authorities a
 join public.countries c on c.id=a.country_id
 where c.iso2_code='SY' and a.authority_code='LEGACY-UNASSIGNED'
), demos(code,name_ar,name_en,kind) as (
 values
 ('DEMO-CLASSIC-001','محطة تجريبية كلاسيكية 001','Demo Classic Station 001','classic'),
 ('DEMO-AUTO-001','محطة تجريبية آلية 001','Demo Automatic Station 001','automatic'),
 ('DEMO-SYNOPTIC-001','محطة تجريبية سينوبتيكية 001','Demo Synoptic Station 001','synoptic')
)
insert into public.station_catalogue
(country_id,owner_authority_id,local_station_code,name_ar,name_en,station_type,
 operational_status,approval_status,source_system,source_table,source_record_id,
 is_demo,description)
select o.country_id,o.authority_id,d.code,d.name_ar,d.name_en,d.kind,
 'unverified','pending','METRA-DEMO','demo_seed',d.code,true,
 'بيانات اصطناعية للاختبار فقط؛ ليست محطة حقيقية ولا يجوز استخدامها تشغيلياً.'
from owner o cross join demos d
on conflict (source_system,source_table,source_record_id)
where source_table is not null and source_record_id is not null do nothing;
commit;
