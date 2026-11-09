-- REVIEW ONLY. Do not run against production or legacy databases.
-- Intended for an empty disposable Postgres after approved migration apply.
--
-- Pseudocode checklist (fill session GUCs to match NpgsqlOpsSession):
--   select set_config('app.user_id', '<user-a>', true);
--   select set_config('app.station_id', '<station-a>', true);
--   select count(*) from public.metra_equipment_faults; -- expect only station A
--   select count(*) from public.metra_equipment_faults where station_id = '<station-b>'; -- expect 0 under RLS
--   select set_config('app.station_id', '<station-b>', true);
--   select count(*) from public.metra_equipment_faults where station_id = '<station-a>'; -- expect 0
--
-- Repeat for public.metra_support_incidents.
-- Fail the harness if any cross-station count is non-zero.

SELECT 'ops_station_isolation_pg_test: placeholder for approved disposable DB run' AS status;
