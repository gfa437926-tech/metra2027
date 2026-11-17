-- C2.5 ROLLBACK candidate — drop uniqueness indexes only
-- Does not touch grant rows or audit.

DROP INDEX IF EXISTS public.permission_grants_active_station_unique;
DROP INDEX IF EXISTS public.permission_grants_active_authority_unique;
