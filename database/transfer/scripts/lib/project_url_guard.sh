#!/usr/bin/env bash
# Validate that a Postgres URL belongs to the explicitly named Supabase project.
# Supports direct db.<ref>.supabase.co hosts and Supavisor usernames postgres.<ref>.
metra_assert_supabase_project_url() {
  local expected_ref="${1:?expected project ref required}"
  local database_url="${2:?database URL required}"
  local label="${3:-database}"

  if [[ "$database_url" != *"://"*"@"* ]]; then
    echo "Refusing $label URL: expected a Supabase Postgres URL with userinfo." >&2
    return 1
  fi

  local authority="${database_url#*://}"
  local userinfo="${authority%%@*}"
  local username="${userinfo%%:*}"
  local hostport="${authority#*@}"
  local host="${hostport%%/*}"
  host="${host%%:*}"

  if [[ "$host" != "db.${expected_ref}.supabase.co" && "$username" != "postgres.${expected_ref}" ]]; then
    echo "Refusing $label URL: host/user does not identify expected Supabase project $expected_ref." >&2
    return 1
  fi
}
