#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
URL="${METRA_OPS_DATABASE_URL:-}"
if [ -z "$URL" ]; then
  echo "METRA_OPS_DATABASE_URL is required" >&2
  exit 1
fi
if echo "$URL" | grep -Eiq 'legacy|insert|old[_-]?metra' && [ "${METRA_ALLOW_LEGACY_HOST:-}" != "1" ]; then
  echo "Refusing to apply migrations: connection string looks legacy. Aborting." >&2
  exit 2
fi
echo "==> Prerequisites (optional isolated bootstrap)"
if [ "${METRA_APPLY_BOOTSTRAP:-0}" = "1" ]; then
  psql "$URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/bootstrap/00_test_prerequisites.sql"
fi
echo "==> Applying supabase/migrations in lexical order"
for f in $(ls -1 "$ROOT/supabase/migrations/"*.sql | sort); do
  echo "---- $(basename "$f")"
  psql "$URL" -v ON_ERROR_STOP=1 -f "$f"
done
echo "==> Migrations applied successfully against NEW METRA target"
