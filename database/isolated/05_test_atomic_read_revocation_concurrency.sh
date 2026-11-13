#!/usr/bin/env bash
set -euo pipefail
: "$DATABASE_URL"

station="aaaaaaaa-0001-0001-0001-000000000001"
authority="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
reviewer="22222222-2222-2222-2222-222222222222"
observer="11111111-1111-1111-1111-111111111111"

assert_blocked_update() {
 local actor_id="$1"
 local permission_code="$2"
 local sql="$3"
 local name="$4"
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; SELECT private.metra_lock_authorized_station_read('$actor_id','$station','$permission_code'); SELECT pg_sleep(2); COMMIT" >/tmp/metra-reader.log 2>&1 &
 local reader_pid=$!
 sleep 0.35
 local start
 start="$(date +%s)"
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$sql" >/tmp/metra-revoke.log 2>&1
 local elapsed=$(( $(date +%s) - start ))
 wait "$reader_pid"
 if (( elapsed < 1 )); then echo "FAIL: $name did not wait for active read lock (elapsed=$elapsed s)" >&2; exit 1; fi
 local allowed
 allowed="$(psql "$DATABASE_URL" -Atqc "SELECT private.metra_lock_authorized_station_read('$actor_id','$station','$permission_code')")"
 if [[ "$allowed" != "f" ]]; then echo "FAIL: $name did not deny subsequent authorization" >&2; exit 1; fi
 echo "PASS: $name waited for active read transaction; subsequent read denied"
}

reviewer_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$reviewer' AND authority_id='$authority' AND permission_code='users.station.view' LIMIT 1")"
if [[ -z "$reviewer_grant" ]]; then
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO public.permission_grants(user_id,permission_code,authority_id,requested_by,approved_by,reviewed_at,reason) VALUES('$reviewer','users.station.view','$authority','$reviewer','$observer',now(),'isolated concurrency grant')"
 reviewer_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$reviewer' AND authority_id='$authority' AND permission_code='users.station.view' LIMIT 1")"
fi
assert_blocked_update "$reviewer" "users.station.view" "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$reviewer_grant'" "station-view grant revocation"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=NULL, approval_status='approved', approved_by='$observer', reviewed_at=now() WHERE id='$reviewer_grant'"
reviewer_assignment="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.station_assignments WHERE user_id='$reviewer' AND station_id='$station' LIMIT 1")"
assert_blocked_update "$reviewer" "users.station.view" "UPDATE public.station_assignments SET valid_to=clock_timestamp()-interval '1 second' WHERE id='$reviewer_assignment'" "station-view assignment expiry"

archive_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$observer' AND authority_id='$authority' AND permission_code='observation.archive.read' LIMIT 1")"
assert_blocked_update "$observer" "observation.archive.read" "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$archive_grant'" "archive grant revocation"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=NULL WHERE id='$archive_grant'"
submit_grant="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$observer' AND authority_id='$authority' AND permission_code='observation.submit' LIMIT 1")"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; SELECT public.metra_submit_observation('$observer','$station','atomic-submit-race-001','hourly',now(),'{}'::jsonb,true); SELECT pg_sleep(2); COMMIT" >/tmp/metra-submit-reader.log 2>&1 &
submit_reader_pid=$!
sleep 0.35
submit_start="$(date +%s)"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$submit_grant'" >/tmp/metra-submit-revoke.log 2>&1
submit_elapsed=$(( $(date +%s) - submit_start ))
wait "$submit_reader_pid"
if (( submit_elapsed < 1 )); then echo "FAIL: observation.submit revocation did not wait for active submission (elapsed=$submit_elapsed s)" >&2; exit 1; fi
submit_allowed="$(psql "$DATABASE_URL" -Atqc "SELECT private.metra_lock_authorized_station_read('$observer','$station','observation.submit')")"
if [[ "$submit_allowed" != "f" ]]; then echo "FAIL: revoked observation.submit grant still authorizes a write" >&2; exit 1; fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=NULL WHERE id='$submit_grant'"
echo "PASS: observation.submit revocation waited for active write transaction; subsequent write authorization denied"

archive_assignment="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.station_assignments WHERE user_id='$observer' AND station_id='$station' LIMIT 1")"
assert_blocked_update "$observer" "observation.archive.read" "UPDATE public.station_assignments SET valid_to=clock_timestamp()-interval '1 second' WHERE id='$archive_assignment'" "archive station assignment expiry"
