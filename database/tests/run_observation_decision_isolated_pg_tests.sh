#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMA_SQL="$ROOT/database/tests/observation_decision_test_schema.sql"
SCENARIO_SQL="$ROOT/database/tests/observation_decision_scenarios.sql"
DECIDE_MIGRATION="$ROOT/supabase/migrations/20261107020000_harden_observation_decision_sod_and_audit.sql"
RESUBMIT_MIGRATION="$ROOT/supabase/migrations/20261107021500_observation_resubmit_after_return.sql"

test -f "$SCHEMA_SQL"
test -f "$SCENARIO_SQL"
test -f "$DECIDE_MIGRATION"
test -f "$RESUBMIT_MIGRATION"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for isolated observation decision tests" >&2
  exit 1
fi

DB_NAME="metra_obs_decision_test_$$"
export PGUSER="${PGUSER:-postgres}"
# Prefer local socket; fall back to localhost TCP if needed.
export PGHOST="${PGHOST:-/var/run/postgresql}"

psql_q() {
  psql -v ON_ERROR_STOP=1 "$@"
}

cleanup() {
  psql_q -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" >/dev/null 2>&1 || true
}
trap cleanup EXIT

psql_q -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" >/dev/null
psql_q -d postgres -c "CREATE DATABASE ${DB_NAME};" >/dev/null

echo "Applying test schema stubs..."
psql_q -d "$DB_NAME" -f "$SCHEMA_SQL" >/dev/null

echo "Applying real migration: harden observation decision..."
psql_q -d "$DB_NAME" -f "$DECIDE_MIGRATION" >/dev/null

echo "Applying real migration: observation resubmit..."
psql_q -d "$DB_NAME" -f "$RESUBMIT_MIGRATION" >/dev/null

# Confirm the audit immutability trigger exists before scenarios.
TRIGGER_COUNT="$(psql_q -d "$DB_NAME" -Atc "select count(*) from pg_trigger where tgname = 'metra_observation_audit_immutable';")"
if [[ "$TRIGGER_COUNT" != "1" ]]; then
  echo "Expected metra_observation_audit_immutable trigger, found count=${TRIGGER_COUNT}" >&2
  exit 1
fi

echo "Running sequential decision/resubmit scenarios..."
SCENARIO_OUT="$(psql_q -d "$DB_NAME" -f "$SCENARIO_SQL" 2>&1)"
echo "$SCENARIO_OUT" | grep -q "OBSERVATION_DECISION_SCENARIOS_PASSED"

echo "Running concurrent decision race with two independent connections..."
# Seed a fresh submitted observation dedicated to the concurrency probe.
psql_q -d "$DB_NAME" -c "
insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  '99999999-9999-4999-8999-999999999999',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'hourly', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-race', now()
) on conflict do nothing;
" >/dev/null

RACE_DIR="$(mktemp -d)"
# Connection A: lock the row, hold briefly, then decide as reviewer 2222.
cat > "$RACE_DIR/conn_a.sql" << 'SQL'
begin;
select id from public.metra_observations
 where id = '99999999-9999-4999-8999-999999999999'
   and station_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
 for update;
select pg_sleep(1.5);
select public.metra_decide_observation(
  '22222222-2222-4222-8222-222222222222',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '99999999-9999-4999-8999-999999999999',
  'approve',
  null
);
commit;
SQL

# Connection B: attempt decide as reviewer 3333 after a short delay (while A holds lock).
cat > "$RACE_DIR/conn_b.sql" << 'SQL'
select pg_sleep(0.3);
begin;
select public.metra_decide_observation(
  '33333333-3333-4333-8333-333333333333',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '99999999-9999-4999-8999-999999999999',
  'approve',
  null
);
commit;
SQL

set +e
psql_q -d "$DB_NAME" -f "$RACE_DIR/conn_a.sql" >"$RACE_DIR/a.out" 2>"$RACE_DIR/a.err" &
PID_A=$!
psql_q -d "$DB_NAME" -f "$RACE_DIR/conn_b.sql" >"$RACE_DIR/b.out" 2>"$RACE_DIR/b.err" &
PID_B=$!
wait "$PID_A"
STATUS_A=$?
wait "$PID_B"
STATUS_B=$?
set -e

SUCCESS_COUNT=0
if [[ $STATUS_A -eq 0 ]] && grep -q '"status"[[:space:]]*:[[:space:]]*"approved"' "$RACE_DIR/a.out"; then
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
fi
if [[ $STATUS_B -eq 0 ]] && grep -q '"status"[[:space:]]*:[[:space:]]*"approved"' "$RACE_DIR/b.out"; then
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
fi

# Exactly one connection may commit an approval.
if [[ "$SUCCESS_COUNT" -ne 1 ]]; then
  echo "Concurrent decision race failed: expected exactly 1 success, got ${SUCCESS_COUNT}" >&2
  echo "--- conn A (exit ${STATUS_A}) ---" >&2
  cat "$RACE_DIR/a.out" "$RACE_DIR/a.err" >&2 || true
  echo "--- conn B (exit ${STATUS_B}) ---" >&2
  cat "$RACE_DIR/b.out" "$RACE_DIR/b.err" >&2 || true
  exit 1
fi

FINAL_STATUS="$(psql_q -d "$DB_NAME" -Atc "select status from public.metra_observations where id = '99999999-9999-4999-8999-999999999999';")"
if [[ "$FINAL_STATUS" != "approved" ]]; then
  echo "Concurrent race left unexpected status=${FINAL_STATUS}" >&2
  exit 1
fi

AUDIT_COUNT="$(psql_q -d "$DB_NAME" -Atc "select count(*) from public.metra_observation_audit_events where observation_id = '99999999-9999-4999-8999-999999999999' and event_type = 'approved';")"
if [[ "$AUDIT_COUNT" != "1" ]]; then
  echo "Expected exactly one approved audit event after race, got ${AUDIT_COUNT}" >&2
  exit 1
fi

echo "Isolated observation decision PostgreSQL tests passed (including concurrency)."
