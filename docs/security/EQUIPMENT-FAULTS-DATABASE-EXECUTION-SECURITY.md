# Equipment Faults — Database Execution Security Decision

## Purpose
Resolve the authorization and transaction-boundary ambiguity in the equipment-fault storage proposal before implementing persistence. This is a design decision record only. It contains no executable SQL and authorizes no database changes.

## Current repository facts
- The API currently uses named HttpClient instances and Supabase PostgREST services.
- There is no PostgreSQL/Npgsql persistence adapter registered for EquipmentFaults.
- The existing API unit-test project targets .NET 10 and does not currently reference a PostgreSQL driver or a containerized database test framework.
- The equipment-fault schema proposal requires one atomic status update plus one audit insert.
- The proposal recommends an invoker-rights routine while requiring the application role to be unable to mutate audit history directly. These requirements need an explicit privilege model: an invoker routine cannot write tables unless its invoker has the required table privileges.

## Non-negotiable security properties
1. Browser/mobile clients never receive a Supabase service-role key or database credential.
2. Only the trusted .NET API can invoke the equipment-fault write path.
3. A transition matches fault_id, station_id, and expected current status in the authoritative database write.
4. The current-state update and audit append commit or roll back together.
5. The application-facing write identity cannot update or delete audit rows.
6. No direct client table write can bypass the transition state machine.
7. Cross-station misses and unknown fault IDs have the same externally visible result.
8. Database object ownership and privileged credentials are not used by normal application requests.

## Viable implementation models

### Option A — Dedicated PostgreSQL application role and direct transactional adapter
The .NET API connects through a restricted, non-owner PostgreSQL role. A single database transaction performs the conditional update and audit insert. The role receives only the exact required privileges; audit UPDATE/DELETE are not granted.

Advantages:
- Native PostgreSQL transaction semantics and straightforward integration testing.
- No RPC function required.
- Explicit database credentials and privileges can be scoped to the adapter.

Trade-offs:
- Requires a managed PostgreSQL connection string and secure secret rotation.
- Supabase connection-pooler mode, TLS, network access, and role provisioning must be reviewed.
- The role must not inherit broad privileges or BYPASSRLS.

### Option B — Narrow database routine exposed through PostgREST
The .NET API calls one routine for a transition. The routine performs the conditional current-row update and audit insert in one transaction.

A plain SECURITY INVOKER routine is only viable if its invoker has the table privileges needed by the routine. Granting broad table UPDATE/INSERT privileges to the API role weakens the intended boundary and may permit writes outside the state machine.

A narrowly privileged SECURITY DEFINER routine can provide a stronger boundary, but only if all of the following are implemented and independently reviewed:
- A dedicated non-login owner role owns the routine and has only the minimum table privileges needed.
- The routine has a fixed, trusted search_path; all application objects are schema-qualified.
- Dynamic SQL is avoided.
- EXECUTE is revoked from PUBLIC, anon, and authenticated; only the intended backend execution role receives it.
- The backend execution role is not exposed to clients and is not granted direct mutation privileges on the fault or audit tables.
- The routine validates all input values and performs station/status predicates itself.
- No caller-controlled actor, station ownership, or audit timestamp is trusted without server-side validation.
- Supabase/PostgREST exposed-schema and role behavior is verified in an isolated project before production use.

Trade-offs:
- Requires careful review of function ownership, grants, schema exposure, and Supabase role inheritance.
- A function security review is mandatory; SECURITY DEFINER is not a shortcut and must not be used with an unsafe search path or broad owner role.

## Recommended direction for this repository
Because the current backend already uses Supabase PostgREST and the approved schema proposal describes a REST-based adapter, Option B is the least disruptive integration path only if the restricted routine ownership and grants above can be implemented and verified. If Supabase role configuration cannot meet those requirements cleanly, use Option A rather than weakening table privileges.

This is a recommendation for a future reviewed implementation, not authorization to create the routine or roles.

## Integration-test architecture
Create a separate .NET 10 integration-test project rather than making the existing fast unit-test project depend on a database.

Candidate test dependencies, subject to package/version review:
- Testcontainers for .NET to provision an ephemeral PostgreSQL instance.
- Npgsql only if the adapter uses direct PostgreSQL connections or the test harness needs direct role/session setup.
- The real production adapter and the same reviewed database routine/schema used by the deployed service.

The test harness must:
- Start a disposable PostgreSQL instance for the test run.
- Refuse any connection string that is not explicitly marked as a test database.
- Apply only a reviewed, approved test schema.
- Create fixtures using a setup-only privileged connection.
- Execute application-path tests using the actual restricted application role.
- Keep the schema-owner credential out of application adapter configuration.
- Drop the disposable instance after the run.
- Publish integration test results separately from unit tests.

## Scenario-to-mechanism mapping
| Scenario | Required mechanism |
|---|---|
| List/count station isolation | Real adapter SQL with station predicate applied to both page and count |
| Cross-station detail | One lookup predicate containing both fault ID and station ID |
| Audit insert failure rollback | Deterministic test-only DB failure during audit append; assert unchanged fault and audit state |
| Concurrent transitions | Two independent database sessions synchronized at the write boundary; exactly one applied |
| Audit immutability | UPDATE/DELETE attempts through the actual restricted application role; verify unchanged audit row |

## Decision gates
Before implementation:
1. Confirm Option A or Option B after reviewing Supabase project role and connection configuration.
2. Review exact SQL, including ownership, grants, RLS, schema exposure, and any routine security mode.
3. Approve the SQL and isolated test-environment setup explicitly.
4. Only then create the disposable integration database schema and persistence adapter.

## Explicitly unchanged
- No SQL has been applied.
- No migration, table, function/RPC, role, grant, RLS policy, or trigger has been created or altered.
- No production or legacy database has been accessed or changed by this document.