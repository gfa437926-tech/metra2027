#!/usr/bin/env bash
# Static contract test: the comparison runner must execute every declared
# acceptance check and must fail closed when any comparison differs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
RUNNER="$ROOT/database/transfer/scripts/05_compare.sh"
SQL="$ROOT/database/transfer/sql"

require_file() {
  [[ -s "$1" ]] || { echo "FAIL: missing or empty file: $1" >&2; exit 1; }
}

require_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || {
    echo "FAIL: expected '$needle' in $file" >&2
    exit 1
  }
}

for file in \
  "$RUNNER" \
  "$SQL/compare_rowcounts.sql" \
  "$SQL/compare_data_hashes.sql" \
  "$SQL/compare_auth_fk_counts.sql" \
  "$SQL/compare_sequence_state.sql" \
  "$SQL/compare_objects.sql" \
  "$SQL/compare_acl_inventory_acceptance.sql" \
  "$SQL/compare_extensions.sql" \
  "$SQL/station_catalogue_provenance.sql" \
  "$SQL/compare_excluded_data.sql" \
  "$SQL/assert_empty_application_tables.sql" \
  "$ROOT/database/transfer/tests/assert_target_default_acl.sql" \
  "$ROOT/database/transfer/tests/assert_target_function_search_path.sql"; do
  require_file "$file"
done

# Every source/target comparison must be executed by the orchestrator.
for artifact in \
  rowcounts \
  data_hashes \
  auth_fk_counts \
  sequence_state \
  objects \
  acl \
  extensions \
  station_catalogue; do
  require_contains "$RUNNER" "\$OUT/\${side}_${artifact}.txt"
done

# Verify the target-only acceptance checks are actually run.
require_contains "$RUNNER" 'assert_target_default_acl.sql'
require_contains "$RUNNER" 'assert_target_function_search_path.sql'
require_contains "$RUNNER" 'compare_excluded_data.sql'
require_contains "$RUNNER" 'target_excluded_observation_rows.txt'

# The deliberately excluded observation-history table must not enter either
# the ordinary row-count or content-hash comparison scope.
require_contains "$SQL/compare_rowcounts.sql" "schemaname IN ('public','private')"
require_contains "$SQL/compare_rowcounts.sql" "tablename='metra_observation_records'"
require_contains "$SQL/compare_data_hashes.sql" "schemaname IN ('public','private')"
require_contains "$SQL/compare_data_hashes.sql" "tablename='metra_observation_records'"
require_contains "$SQL/compare_excluded_data.sql" 'FROM public.metra_observation_records'

# Auth UUID values are deliberately not hashed as application payload; their
# cardinalities are checked independently.
require_contains "$SQL/compare_data_hashes.sql" "con.confrelid='auth.users'::regclass"
require_contains "$SQL/compare_auth_fk_counts.sql" "con.confrelid='auth.users'::regclass"

# Extension acceptance requires every source extension/version/schema entry
# to exist on target. Additional target extensions are intentionally allowed.
require_contains "$RUNNER" 'comm -23'
require_contains "$RUNNER" 'missing_extensions.diff'

# All result statuses must participate in the final PASS gate.
for status in \
  rows_status \
  data_hash_status \
  auth_fk_status \
  sequence_status \
  objects_status \
  acl_status \
  extension_status \
  excluded_data_status \
  station_catalogue_status; do
  require_contains "$RUNNER" "$status"
done


# The workflow must execute the runtime guards, not merely keep them in-tree.
WORKFLOW="$ROOT/.github/workflows/transfer-auth-remap.yml"
require_file "$WORKFLOW"
require_contains "$WORKFLOW" 'bash database/transfer/tests/test_empty_target_guard.sh'
require_contains "$WORKFLOW" 'bash database/transfer/tests/test_excluded_observation_guard.sh'
require_contains "$WORKFLOW" 'bash database/transfer/tests/test_compare_runner_preflight.sh'
require_contains "$WORKFLOW" 'bash database/transfer/tests/test_excluded_dump_patterns.sh'
require_file "$ROOT/database/transfer/tests/test_excluded_dump_patterns.sh"
require_file "$ROOT/database/transfer/tests/test_compare_runner_preflight.sh"

# The empty-target runtime fixture must cover both application schemas.
require_contains "$ROOT/database/transfer/tests/test_empty_target_guard.sh" "CREATE TABLE public.\$fixture"
require_contains "$ROOT/database/transfer/tests/test_empty_target_guard.sh" "CREATE TABLE private.\$fixture"
require_contains "$ROOT/database/transfer/tests/test_empty_target_guard.sh" "public.\$fixture is not empty"
require_contains "$ROOT/database/transfer/tests/test_empty_target_guard.sh" "private.\$fixture is not empty"

# The excluded-history runtime fixture must exercise both empty and populated states.
require_contains "$ROOT/database/transfer/tests/test_excluded_observation_guard.sh" 'empty_count'
require_contains "$ROOT/database/transfer/tests/test_excluded_observation_guard.sh" 'populated_count'

echo "PASS: transfer comparison runner covers all declared acceptance checks and fails closed on mismatches."
