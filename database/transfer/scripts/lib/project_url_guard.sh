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
  public_count="$(grep -Fc 'CREATE SCHEMA public;' "$input_file" || true)"
  private_count="$(grep -Fc 'CREATE SCHEMA private;' "$input_file" || true)"
  if [[ "$public_count" != "1" || "$private_count" != "1" ]]; then
    echo "Refusing schema normalization: expected one public and one private schema statement; found public=$public_count private=$private_count." >&2
    return 1
  fi
  grep -Fv -e 'CREATE SCHEMA public;' -e 'CREATE SCHEMA private;' "$input_file" > "$output_file"
  if grep -Fq 'CREATE SCHEMA public;' "$output_file" || grep -Fq 'CREATE SCHEMA private;' "$output_file"; then
    echo "Refusing schema normalization: existing schema creation statement remains." >&2
    return 1
  fi
  [[ -s "$output_file" ]] || { echo "Refusing schema normalization: output is empty." >&2; return 1; }
}

# Verify the provenance and safety assertions in an exported transfer package.
metra_verify_transfer_manifest() {
  local dump_dir="${1:?transfer export directory required}"
  local manifest="$dump_dir/MANIFEST.txt"
  if [[ ! -s "$manifest" ]]; then
    echo "Refusing import: MANIFEST.txt is missing." >&2
    return 1
  fi
  local required_line
  for required_line in \
    "source_project_ref=tbdnklyxjvbrilvnwgmq" \
    "auth_users_exported=false" \
    "auth_user_count=0" \
    "auth_user_fk_inventory_exported=true" \
    "observation_provenance_exported=true" \
    "observation_records_data_exported=false" \
    "all_observation_records_excluded=true" \
    "demo_observation_records_excluded=true" \
    "non_demo_observation_records_excluded=true" \
    "runtime_role_inventory_exported=true" \
    "required_extensions_inventory_exported=true" \
    "station_catalogue_provenance_exported=true" \
    "api_keys_and_jwt_secrets_exported=false"; do
    if ! grep -Fxq "$required_line" "$manifest"; then
      echo "Refusing import: manifest is missing required assertion: $required_line" >&2
      return 1
    fi
  done
}

# Ensure the decrypted application data dump contains no excluded observation rows.
metra_assert_no_excluded_observation_data() {
  local dump_file="${1:?decrypted data dump required}"
  if [[ ! -s "$dump_file" ]]; then
    echo "Refusing data import: decrypted data dump is missing or empty." >&2
    return 1
  fi
  if grep -Fq -e 'COPY public.metra_observation_records' \
      -e 'COPY "public"."metra_observation_records"' \
      -e 'INSERT INTO public.metra_observation_records' \
      -e 'INSERT INTO "public"."metra_observation_records"' "$dump_file"; then
    echo "Refusing data import: dump contains excluded observation-history rows." >&2
    return 1
  fi
}

# Verify the complete export checksum manifest, reject path traversal/extra files,
# and require every artifact used by restore to be covered exactly once.
metra_verify_transfer_checksums() {
  local dump_dir="${1:?transfer export directory required}"
  local sums="$dump_dir/SHA256SUMS"
  if [[ ! -s "$sums" ]]; then
    echo "Refusing import: SHA256SUMS is missing." >&2
    return 1
  fi

  local expected_files=(
    "01_schema_application.sql.gpg"
    "02_data_application.sql.gpg"
    "03_inventory_tables.txt"
    "03_inventory_functions.txt"
    "04_auth_user_fk_inventory.txt"
    "05_observation_provenance.txt"
    "06_runtime_role_inventory.txt"
    "07_extensions.txt"
    "08_station_catalogue_provenance.txt"
    "MANIFEST.txt"
  )
  local seen_files=()
  local checksum filename extra
  while read -r checksum filename extra; do
    [[ -z "${checksum:-}" && -z "${filename:-}" ]] && continue
    if [[ ! "$checksum" =~ ^[0-9a-fA-F]{64}$ || ! "$filename" =~ ^[A-Za-z0-9_.-]+$ || -n "${extra:-}" ]]; then
      echo "Refusing import: malformed or unsafe checksum entry." >&2
      return 1
    fi
    local expected=false
    local item
    for item in "${expected_files[@]}"; do
      if [[ "$filename" == "$item" ]]; then expected=true; break; fi
    done
    if [[ "$expected" != true ]]; then
      echo "Refusing import: unexpected checksum entry: $filename" >&2
      return 1
    fi
    for item in "${seen_files[@]}"; do
      if [[ "$filename" == "$item" ]]; then
        echo "Refusing import: duplicate checksum entry: $filename" >&2
        return 1
      fi
    done
    seen_files+=("$filename")
  done < "$sums"

  local required
  for required in "${expected_files[@]}"; do
    local found=false
    for item in "${seen_files[@]}"; do
      if [[ "$required" == "$item" ]]; then found=true; break; fi
    done
    if [[ "$found" != true ]]; then
      echo "Refusing import: checksum manifest omits required artifact: $required" >&2
      return 1
    fi
  done

  if [[ "${#seen_files[@]}" -ne "${#expected_files[@]}" ]]; then
    echo "Refusing import: checksum manifest does not cover the exact required artifact set." >&2
    return 1
  fi

  (
    cd "$dump_dir" || exit 1
    sha256sum --check --strict SHA256SUMS
  )
}
