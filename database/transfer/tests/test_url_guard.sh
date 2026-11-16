#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"

metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres:secret@db.tbdnklyxjvbrilvnwgmq.supabase.co:5432/postgres" "direct"
metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres.tbdnklyxjvbrilvnwgmq:secret@aws-0-eu-west-1.pooler.supabase.com:6543/postgres" "pooler"

reject_url() {
  local label="$1"
  local url="$2"
  if metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" "$url" "$label"; then
    echo "FAIL: $label URL was accepted." >&2
    exit 1
  fi
}

reject_url "wrong-project" \
  "postgresql://postgres:secret@db.vktcvkwqszehgmhqjrkb.supabase.co:5432/postgres"
reject_url "wrong-host" \
  "postgresql://postgres:secret@unrelated.example.com:5432/postgres"
reject_url "spoofed-pooler-user" \
  "postgresql://postgres.tbdnklyxjvbrilvnwgmq:secret@attacker.example.com:6543/postgres"
reject_url "wrong-pooler-user" \
  "postgresql://postgres.wrongproject:secret@aws-0-eu-west-1.pooler.supabase.com:6543/postgres"
reject_url "missing-userinfo" \
  "postgresql://db.tbdnklyxjvbrilvnwgmq.supabase.co:5432/postgres"

metra_assert_pg_dump_compatible "170011" "pg_dump (PostgreSQL) 17.5"
metra_assert_pg_dump_compatible "160009" "pg_dump (PostgreSQL) 17.5"
if metra_assert_pg_dump_compatible "170011" "pg_dump (PostgreSQL) 16.9"; then
  echo "FAIL: older pg_dump client was accepted." >&2
  exit 1
fi
if metra_assert_pg_dump_compatible "170011" "pg_dump version unknown"; then
  echo "FAIL: unparseable pg_dump version was accepted." >&2
  exit 1
fi

echo "PASS: Supabase URL and pg_dump compatibility guards."
