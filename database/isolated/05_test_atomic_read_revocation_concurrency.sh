#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"

station="aaaaaaaa-0001-0001-0001-000000000001"
authority="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
reviewer="22222222-2222-2222-2222-222222222222"
observer="11111111-1111-1111-1111-111111111111"

assert_blocked_update() {
 local sql="$1"
 local read_sql="$2"
 local restore_sql="$3"
 local name="$4"

 # Call the protected RPC, then keep its transaction open. Authorization
 # row locks must remain held until commit and block the concurrent update.
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; $read_sql; SELECT pg_sleep(2); COMMIT" >/tmp/metra-reader.log 2>&1 &
 local reader_pid=$!
 sleep 0.35

 local start_ns end_ns elapsed_ms
 start_ns="$(date +%s%N)"
 if ! psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$sql" >/tmp/metra-revoke.log 2>&1; then
   cat /tmp/metra-revoke.log >&2
   kill "$reader_pid" 2>/dev/null || true
   wait "$reader_pid" 2>/dev/null || true
   echo "FAIL: $name update failed" >&2
   exit 1
 fi
 end_ns="$(date +%s%N)"
 elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
 wait "$reader_pid"

 if (( elapsed_ms < 1000 )); then
   echo "FAIL: $name did not wait for active protected RPC (elapsed=${elapsed_ms}ms)" >&2
   exit 1
 fi
 if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$read_sql" >/tmp/metra-denied.log 2>&1; then
   echo "FAIL: $name left the protected RPC authorized after the update" >&2
   exit 1
 fi
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$restore_sql" >/dev/null
 echo "PASS: $name blocked on active protected RPC; subsequent RPC denied"
}

directory_read="SELECT * FROM public.get_station_user_directory_atomic('$reviewer','$station',1)"
reviewer_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$reviewer' AND authority_id='$authority' AND permission_code='users.station.view' LIMIT 1")"
if [[ -z "$reviewer_grant" ]]; then
  echo "FAIL: isolated reviewer station-view grant fixture is missing" >&2
  exit 1
fi
assert_blocked_update \
  "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$reviewer_grant'" \
  "$directory_read" \
  "UPDATE public.permission_grants SET revoked_at=NULL, approval_status='approved', approved_by='$observer', reviewed_at=now() WHERE id='$reviewer_grant'" \
  "station-view grant revocation"

reviewer_assignment="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.station_assignments WHERE user_id='$reviewer' AND station_id='$station' LIMIT 1")"
if [[ -z "$reviewer_assignment" ]]; then
  echo "FAIL: isolated reviewer station assignment fixture is missing" >&2
  exit 1
fi
assert_blocked_update \
  "UPDATE public.station_assignments SET valid_to=clock_timestamp()-interval '1 second' WHERE id='$reviewer_assignment'" \
  "$directory_read" \
  "UPDATE public.station_assignments SET valid_to=NULL WHERE id='$reviewer_assignment'" \
  "station-view assignment expiry"

archive_read="SELECT public.get_station_observation_archive_atomic('$observer','$station',NULL,NULL,NULL,1,NULL)"
archive_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$observer' AND authority_id='$authority' AND permission_code='observation.archive.read' LIMIT 1")"
if [[ -z "$archive_grant" ]]; then
  echo "FAIL: isolated archive grant fixture is missing" >&2
  exit 1
fi
assert_blocked_update \
  "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$archive_grant'" \
  "$archive_read" \
  "UPDATE public.permission_grants SET revoked_at=NULL WHERE id='$archive_grant'" \
  "archive grant revocation"

submit_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$observer' AND authority_id='$authority' AND permission_code='observation.submit' LIMIT 1")"
if [[ -z "$submit_grant" ]]; then
  echo "FAIL: isolated observation.submit grant fixture is missing" >&2
  exit 1
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; SELECT public.metra_submit_observation('$observer','$station','atomic-submit-race-001','hourly',now(),'{}'::jsonb,true); SELECT pg_sleep(2); COMMIT" >/tmp/metra-submit-reader.log 2>&1 &
submit_reader_pid=$!
sleep 0.35
submit_start_ns="$(date +%s%N)"
if ! psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$submit_grant'" >/tmp/metra-submit-revoke.log 2>&1; then
  cat /tmp/metra-submit-revoke.log >&2
  kill "$submit_reader_pid" 2>/dev/null || true
  wait "$submit_reader_pid" 2>/dev/null || true
  exit 1
fi
submit_end_ns="$(date +%s%N)"
submit_elapsed_ms=$(( (submit_end_ns - submit_start_ns) / 1000000 ))
wait "$submit_reader_pid"
if (( submit_elapsed_ms < 1000 )); then
  echo "FAIL: observation.submit revocation did not wait for active write transaction (elapsed=${submit_elapsed_ms}ms)" >&2
  exit 1
fi
if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT public.metra_submit_observation('$observer','$station','atomic-submit-after-revoke','hourly',now(),'{}'::jsonb,true)" >/tmp/metra-submit-denied.log 2>&1; then
  echo "FAIL: revoked observation.submit permission allowed a subsequent write" >&2
  exit 1
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=NULL WHERE id='$submit_grant'"
echo "PASS: observation.submit revocation waited for active write transaction; subsequent write denied"

archive_assignment="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.station_assignments WHERE user_id='$observer' AND station_id='$station' LIMIT 1")"
assert_blocked_update \
  "UPDATE public.station_assignments SET valid_to=clock_timestamp()-interval '1 second' WHERE id='$archive_assignment'" \
  "$archive_read" \
  "UPDATE public.station_assignments SET valid_to=NULL WHERE id='$archive_assignment'" \
  "archive station assignment expiry"
