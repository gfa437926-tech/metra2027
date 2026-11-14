#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"

metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres:secret@db.tbdnklyxjvbrilvnwgmq.supabase.co:5432/postgres" "direct"
metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres.tbdnklyxjvbrilvnwgmq:secret@aws-0-eu-west-1.pooler.supabase.com:6543/postgres" "pooler"

if metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres:secret@db.vktcvkwqszehgmhqjrkb.supabase.co:5432/postgres" "wrong-project"; then
  echo "FAIL: wrong direct project URL was accepted." >&2
  exit 1
fi

if metra_assert_supabase_project_url "tbdnklyxjvbrilvnwgmq" \
  "postgresql://postgres:secret@unrelated.example.com:5432/postgres" "wrong-host"; then
  echo "FAIL: unrelated database URL was accepted." >&2
  exit 1
fi

echo "PASS: Supabase URL identity guard."
