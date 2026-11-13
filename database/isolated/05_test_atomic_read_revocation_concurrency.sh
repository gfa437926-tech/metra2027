#!/usr/bin/env bash
set -euo pipefail
: "\${DATABASE_URL:?DATABASE_URL is required}"
actor="22222222-2222-2222-2222-222222222222"
station="aaaaaaaa-0001-0001-0001-000000000001"
authority="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
assert_blocked_update() {
 local sql="$1"
 local name="$2"
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; SELECT private.metra_lock_authorized_station_read('$actor','$station','users.station.view'); SELECT pg_sleep(2); COMMIT" >/tmp/metra-reader.log 2>&1 &
 local reader_pid=$!
 sleep 0.35
 local start
 start="$(date +%s)"
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$sql" >/tmp/metra-revoke.log 2>&1
 local elapsed=$(( $(date +%s) - start ))
 wait "$reader_pid"
 if (( elapsed < 1 )); then echo "FAIL: $name did not wait for active read lock (elapsed=\${elapsed}s)" >&2; exit 1; fi
 local allowed
 allowed="$(psql "$DATABASE_URL" -Atqc "SELECT private.metra_lock_authorized_station_read('$actor','$station','users.station.view')")"
 if [[ "$allowed" != "f" ]]; then echo "FAIL: $name did not deny subsequent authorization" >&2; exit 1; fi
 echo "PASS: $name waited for active read transaction; subsequent read denied"
}
grant_id="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$actor' AND authority_id='$authority' AND permission_code='users.station.view' LIMIT 1")"
if [[ -z "$grant_id" ]]; then
 psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO public.permission_grants(user_id,permission_code,authority_id,requested_by,approved_by,reviewed_at,reason) VALUES('$actor','users.station.view','$authority','$actor','$actor',now(),'isolated concurrency grant')"
 grant_id="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.permission_grants WHERE user_id='$actor' AND authority_id='$authority' AND permission_code='users.station.view' LIMIT 1")"
fi
assert_blocked_update "UPDATE public.permission_grants SET revoked_at=clock_timestamp() WHERE id='$grant_id'" "grant revocation"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE public.permission_grants SET revoked_at=NULL, approval_status='approved', approved_by='$actor', reviewed_at=now() WHERE id='$grant_id'"
assignment_id="$(psql "$DATABASE_URL" -Atqc "SELECT id FROM public.station_assignments WHERE user_id='$actor' AND station_id='$station' LIMIT 1")"
assert_blocked_update "UPDATE public.station_assignments SET valid_to=clock_timestamp()-interval '1 second' WHERE id='$assignment_id'" "assignment expiry"
