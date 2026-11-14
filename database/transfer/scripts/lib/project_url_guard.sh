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
