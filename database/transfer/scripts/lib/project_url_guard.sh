#!/usr/bin/env bash
# Validate that a Postgres URL identifies the expected Supabase project.
# Direct connections must use db.<ref>.supabase.co.
# Supavisor connections must use postgres.<ref> and a *.pooler.supabase.com host.
metra_assert_supabase_project_url() {
  local expected_ref="${1:?expected project ref required}"
  local database_url="${2:?database URL required}"
  local label="${3:-database}"

  if [[ "$database_url" != *"://"*"@"* ]]; then
    echo "Refusing $label URL: expected a Postgres URL with userinfo." >&2
    return 1
  fi

  local authority="${database_url#*://}"
  local userinfo="${authority%%@*}"
  local username="${userinfo%%:*}"
  local hostport="${authority#*@}"
  local host="${hostport%%/*}"
  host="${host%%:*}"

  if [[ "$host" == "db.${expected_ref}.supabase.co" ]]; then
    return 0
  fi

  if [[ "$username" == "postgres.${expected_ref}" && "$host" == *.pooler.supabase.com ]]; then
    return 0
  fi

  echo "Refusing $label URL: host/user does not identify expected Supabase project $expected_ref." >&2
  return 1
}

# Refuse a pg_dump client older than the connected PostgreSQL server major version.
metra_assert_pg_dump_compatible() {
  local server_version_num="${1:?server_version_num required}"
  local dump_version="${2:?pg_dump version string required}"
  if [[ ! "$server_version_num" =~ ^[0-9]+$ ]]; then
    echo "Refusing export: invalid server_version_num." >&2
    return 1
  fi
  local server_major=$((server_version_num / 10000))
  local dump_version_number
  dump_version_number="$(awk '{print $NF}' <<< "$dump_version")"
  local dump_major="${dump_version_number%%.*}"
  if [[ ! "$dump_major" =~ ^[0-9]+$ ]]; then
    echo "Refusing export: cannot parse pg_dump version: $dump_version" >&2
    return 1
  fi
  if (( dump_major < server_major )); then
    echo "Refusing export: pg_dump major $dump_major is older than PostgreSQL server major $server_major." >&2
    return 1
  fi
}

# Supabase target projects already contain public; the target bootstrap creates
# private. Remove exactly one CREATE statement for each schema from pg_dump.
metra_normalize_public_schema_dump() {
  local input_file="${1:?input schema dump required}"
  local output_file="${2:?output schema dump required}"
  if [[ ! -s "$input_file" ]]; then
    echo "Refusing schema normalization: input dump is missing or empty." >&2
    return 1
  fi
  local public_count private_count
  public_count="$(grep -Ec '^CREATE SCHEMA "?public"?;
 "$input_file" || true)"
  private_count="$(grep -Ec '^CREATE SCHEMA "?private"?;
 "$input_file" || true)"
  if [[ "$public_count" != "1" || "$private_count" != "1" ]]; then
    echo "Refusing schema normalization: expected one public and one private schema statement; found public=$public_count private=$private_count." >&2
    return 1
  fi
  sed -E '/^CREATE SCHEMA "?public"?;$/d; /^CREATE SCHEMA "?private"?;$/d' "$input_file" > "$output_file"
  if grep -Eq '^CREATE SCHEMA "?public"?;$|^CREATE SCHEMA "?private"?;
 "$output_file"; then
    echo "Refusing schema normalization: existing schema creation statement remains." >&2
    return 1
  fi
  [[ -s "$output_file" ]] || { echo "Refusing schema normalization: output is empty." >&2; return 1; }
}
