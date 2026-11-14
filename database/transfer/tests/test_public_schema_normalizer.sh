#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/valid.sql" <<'SQL'
CREATE SCHEMA public;
CREATE SCHEMA private;
CREATE TABLE public.fixture(id integer PRIMARY KEY);
CREATE FUNCTION private.fixture() RETURNS integer LANGUAGE sql AS 'SELECT 1;';
SQL
metra_normalize_public_schema_dump "$TMP_DIR/valid.sql" "$TMP_DIR/normalized.sql"
if grep -Fq 'CREATE SCHEMA public;' "$TMP_DIR/normalized.sql" || grep -Fq 'CREATE SCHEMA private;' "$TMP_DIR/normalized.sql"; then
  echo "FAIL: application schema creation was not removed." >&2
  exit 1
fi
grep -Fx "CREATE TABLE public.fixture(id integer PRIMARY KEY);" "$TMP_DIR/normalized.sql"
grep -F "CREATE FUNCTION private.fixture()" "$TMP_DIR/normalized.sql"

cat > "$TMP_DIR/missing.sql" <<'SQL'
CREATE SCHEMA public;
CREATE TABLE public.fixture(id integer PRIMARY KEY);
SQL
if metra_normalize_public_schema_dump "$TMP_DIR/missing.sql" "$TMP_DIR/missing.out.sql"; then
  echo "FAIL: dump without private schema statement was accepted." >&2
  exit 1
fi

cat > "$TMP_DIR/duplicate.sql" <<'SQL'
CREATE SCHEMA public;
CREATE SCHEMA public;
CREATE SCHEMA private;
CREATE TABLE public.fixture(id integer PRIMARY KEY);
SQL
if metra_normalize_public_schema_dump "$TMP_DIR/duplicate.sql" "$TMP_DIR/duplicate.out.sql"; then
  echo "FAIL: dump with duplicate public schema statements was accepted." >&2
  exit 1
fi

echo "PASS: public/private schema dump normalization guard."
