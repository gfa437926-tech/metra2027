#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB_URL="${PATH_N_DATABASE_URL:?}"
# Use isolated suite on a dedicated DB recommended; optional lightweight checks:
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'permission_grants_archive_requires_station'
  ) THEN
    RAISE EXCEPTION 'missing archive station CHECK';
  END IF;
  RAISE NOTICE 'PASS: archive requires station_id check present';
END $$;
SQL
