#!/usr/bin/env bash
# Encrypted export of public schema/data from the approved experimental source.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${METRA_TRANSFER_OUT:-$ROOT/database/transfer/artifacts/$STAMP}"
: "${METRA_TRANSFER_PASSPHRASE:?Set METRA_TRANSFER_PASSPHRASE in the secure shell environment}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: only the approved experimental source project is allowed." >&2
  exit 3
fi
metra_assert_supabase_project_url "$SRC_REF" "$SRC_URL" "source"
command -v pg_dump >/dev/null 2>&1 || { echo "pg_dump is required." >&2; exit 4; }
command -v psql >/dev/null 2>&1 || { echo "psql is required." >&2; exit 4; }
command -v gpg >/dev/null 2>&1 || { echo "gpg is required for encrypted exports." >&2; exit 4; }

SERVER_VERSION_NUM="$(psql "$SRC_URL" -X -At -v ON_ERROR_STOP=1 -c "SHOW server_version_num")"
metra_assert_pg_dump_compatible "$SERVER_VERSION_NUM" "$(pg_dump --version)"

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Exporting approved source $SRC_REF to encrypted artifacts."
pg_dump "$SRC_URL" --format=plain --schema-only --no-owner --no-privileges \
  --schema=public --schema=private --file="$TMP_DIR/01_schema_public.raw.sql"
metra_normalize_public_schema_dump "$TMP_DIR/01_schema_public.raw.sql" "$TMP_DIR/01_schema_public.sql"
pg_dump "$SRC_URL" --format=plain --data-only --no-owner --disable-triggers \
  --schema=public --schema=private --file="$TMP_DIR/02_data_public.sql"

for dump in 01_schema_public.sql 02_data_public.sql; do
  printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
    --passphrase-fd 0 --symmetric --cipher-algo AES256 \
    --output "$OUT_DIR/$dump.gpg" "$TMP_DIR/$dump"
done

psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_tables.txt" -c "\
SELECT table_schema, table_name FROM information_schema.tables \
WHERE table_schema IN ('public','private') ORDER BY 1,2;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_functions.txt" -c "\
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) \
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace \
WHERE n.nspname IN ('public','private') ORDER BY 1,2,3;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/04_auth_user_fk_inventory.txt" -c "\
SELECT n.nspname, c.relname, con.conname, pg_get_constraintdef(con.oid) \
FROM pg_constraint con \
JOIN pg_class c ON c.oid = con.conrelid \
JOIN pg_namespace n ON n.oid = c.relnamespace \
WHERE con.contype = 'f' AND con.confrelid = 'auth.users'::regclass \
ORDER BY 1,2,3;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/05_observation_provenance.txt" -c "\
SELECT source_system, source_table, is_demo, count(*)::bigint AS rows, \
       count(DISTINCT station_id)::bigint AS distinct_station_ids, \
       count(*) FILTER (WHERE station_id IS NULL)::bigint AS rows_without_station \
FROM public.metra_observation_records \
GROUP BY source_system, source_table, is_demo \
ORDER BY source_system, source_table, is_demo;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/06_runtime_role_inventory.txt" -c "\
SELECT item::text
FROM (
  SELECT '01_role'::text AS sort_key,
         jsonb_build_object('kind','role','rolname',rolname,'rolsuper',rolsuper,'rolinherit',rolinherit,
           'rolcreaterole',rolcreaterole,'rolcreatedb',rolcreatedb,'rolcanlogin',rolcanlogin,
           'rolreplication',rolreplication,'rolbypassrls',rolbypassrls) AS item
  FROM pg_roles WHERE rolname='metra_api_runtime'
  UNION ALL
  SELECT '02_schema',
         jsonb_build_object('kind','schema_privilege','role',r.rolname,'schema',n.nspname,
           'usage',has_schema_privilege(r.rolname,n.oid,'USAGE'),
           'create',has_schema_privilege(r.rolname,n.oid,'CREATE'))
  FROM pg_roles r CROSS JOIN pg_namespace n
  WHERE n.nspname IN ('public','private')
    AND r.rolname IN ('anon','authenticated','service_role','metra_api_runtime','postgres')
  UNION ALL
  SELECT '03_table',
         jsonb_build_object('kind','table_privilege','grantee',grantee,'schema',table_schema,
           'table',table_name,'privilege',privilege_type,'grantable',is_grantable)
  FROM information_schema.role_table_grants
  WHERE table_schema IN ('public','private')
    AND grantee IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '04_sequence',
         jsonb_build_object('kind','sequence_privilege','grantee',r.rolname,'schema',n.nspname,
           'sequence',c.relname,
           'usage',has_sequence_privilege(r.rolname,c.oid,'USAGE'),
           'select',has_sequence_privilege(r.rolname,c.oid,'SELECT'),
           'update',has_sequence_privilege(r.rolname,c.oid,'UPDATE'))
  FROM pg_roles r CROSS JOIN pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind='S' AND n.nspname IN ('public','private')
    AND r.rolname IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '05_routine',
         jsonb_build_object('kind','routine_privilege','grantee',grantee,'schema',routine_schema,
           'routine',routine_name,'specific_name',specific_name,'privilege',privilege_type,
           'grantable',is_grantable)
  FROM information_schema.role_routine_grants
  WHERE routine_schema IN ('public','private')
    AND grantee IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '06_public_acl',
         jsonb_build_object('kind','public_acl','schema',n.nspname,'object_type','function',
           'object_name',p.proname,'identity_arguments',pg_get_function_identity_arguments(p.oid),
           'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f',p.proowner))) a
  WHERE n.nspname IN ('public','private') AND a.grantee=0
  UNION ALL
  SELECT '07_default_acl',
         jsonb_build_object('kind','default_acl','owner',pg_get_userbyid(defaclrole),
           'schema',defaclnamespace::regnamespace::text,'object_type',defaclobjtype,
           'acl',defaclacl::text)
  FROM pg_default_acl
  WHERE defaclrole='postgres'::regrole
    AND defaclnamespace='public'::regnamespace
  UNION ALL
  SELECT '08_membership',
         jsonb_build_object('kind','membership','granted_role',granted.rolname,
           'member_role',member.rolname,'admin_option',m.admin_option)
  FROM pg_auth_members m
  JOIN pg_roles granted ON granted.oid=m.roleid
  JOIN pg_roles member ON member.oid=m.member
  WHERE granted.rolname='metra_api_runtime' OR member.rolname='metra_api_runtime'
) inventory(sort_key,item)
ORDER BY sort_key,item::text;"

(
  cd "$OUT_DIR"
  sha256sum 01_schema_public.sql.gpg 02_data_public.sql.gpg 03_inventory_tables.txt 03_inventory_functions.txt 04_auth_user_fk_inventory.txt 05_observation_provenance.txt 06_runtime_role_inventory.txt > SHA256SUMS
)

{
  echo "source_project_ref=$SRC_REF"
  echo "exported_at_utc=$STAMP"
  echo "host_tool=$(pg_dump --version | head -1)"
  echo "encryption=gpg-symmetric-AES256"
  echo "auth_users_exported=false"
  echo "auth_user_fk_inventory_exported=true"
  echo "observation_provenance_exported=true"
  echo "runtime_role_inventory_exported=true"
  echo "api_keys_and_jwt_secrets_exported=false"
} > "$OUT_DIR/MANIFEST.txt"

echo "Encrypted export complete: $OUT_DIR"
echo "Plaintext temporary dumps were removed on exit. Keep the passphrase separately."
