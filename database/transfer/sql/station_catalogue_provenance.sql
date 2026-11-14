-- Reference station catalogue quality summary.
SELECT metric || '|' || value
FROM (
  SELECT 'station_catalogue_rows'::text AS metric, count(*)::text AS value
  FROM public.station_catalogue
  UNION ALL
  SELECT 'station_catalogue_demo_rows', count(*)::text
  FROM public.station_catalogue WHERE is_demo IS TRUE
  UNION ALL
  SELECT 'station_catalogue_non_demo_rows', count(*)::text
  FROM public.station_catalogue WHERE is_demo IS FALSE
  UNION ALL
  SELECT 'station_approval_pending_rows', count(*)::text
  FROM public.station_catalogue WHERE approval_status='pending'
  UNION ALL
  SELECT 'station_approval_approved_rows', count(*)::text
  FROM public.station_catalogue WHERE approval_status='approved'
  UNION ALL
  SELECT 'station_operational_unverified_rows', count(*)::text
  FROM public.station_catalogue WHERE operational_status='unverified'
  UNION ALL
  SELECT 'station_operational_active_rows', count(*)::text
  FROM public.station_catalogue WHERE operational_status='active'
  UNION ALL
  SELECT 'station_coordinate_rows', count(*)::text
  FROM public.station_coordinates
  UNION ALL
  SELECT 'stations_with_coordinates', count(DISTINCT station_id)::text
  FROM public.station_coordinates
  UNION ALL
  SELECT 'stations_without_coordinates', count(*)::text
  FROM public.station_catalogue s
  WHERE NOT EXISTS (SELECT 1 FROM public.station_coordinates c WHERE c.station_id=s.id)
  UNION ALL
  SELECT 'orphan_coordinate_rows', count(*)::text
  FROM public.station_coordinates c
  WHERE NOT EXISTS (SELECT 1 FROM public.station_catalogue s WHERE s.id=c.station_id)
  UNION ALL
  SELECT 'duplicate_coordinate_station_ids', count(*)::text
  FROM (
    SELECT station_id
    FROM public.station_coordinates
    GROUP BY station_id
    HAVING count(*)>1
  ) duplicates
) metrics
ORDER BY metric;
