#!/usr/bin/env bash
# Path N: build METRA schema from empty PostgreSQL (verification only).
# Does NOT target hosted Supabase. Does NOT modify production migration files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DB_URL="${PATH_N_DATABASE_URL:-}"
if [[ -z "$DB_URL" ]]; then
  echo "Set PATH_N_DATABASE_URL e.g. postgres://metra_test:metra_test_isolated@127.0.0.1:5432/metra_path_n" >&2
  exit 2
fi

run_sql() {
  local file="$1"
  echo "==> $file"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$file"
}

echo "Path N start on $DB_URL"

# 1-2 Baseline
for f in database/baseline/00*.sql; do
  run_sql "$f"
done

# 3 Official role catalogue
run_sql database/seeds/001_role_catalogue.sql

# 4 Local Supabase role names only (no secrets)
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN CREATE ROLE anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE service_role NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE metra_api_runtime NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
SQL

# 5 Compat patches that must run before certain originals
run_sql database/baseline/compat/027_path_n_authority_code_column.sql

# 6 Migrations with Path N skips
for f in $(ls database/migrations/*.sql | sort); do
  base=$(basename "$f")
  case "$base" in
    020_authority_membership_and_permission_grant_lifecycle.sql)
      echo "==> SKIP original $base (Path N); applying compat"
      run_sql database/baseline/compat/020_path_n_skip_add_authority_id.sql
      ;;
    022_harden_authority_access_revocation_and_audit_index.sql)
      echo "==> SKIP original $base (Path N); applying compat"
      run_sql database/baseline/compat/022_path_n_revocation_check.sql
      run_sql database/baseline/compat/022_path_n_revocation_functions.sql
      ;;
    *)
      run_sql "$f"
      ;;
  esac
done

# 7 Optional observation stack (single source of truth remains supabase/migrations)
if [[ "${PATH_N_APPLY_OBSERVATIONS:-0}" == "1" ]]; then
  for f in $(ls supabase/migrations/*.sql | sort); do
    run_sql "$f"
  done
fi

echo "Path N schema apply completed successfully."
