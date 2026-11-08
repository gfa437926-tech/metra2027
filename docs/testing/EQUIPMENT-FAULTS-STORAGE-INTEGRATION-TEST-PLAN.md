# Equipment Faults — Storage Integration Test Plan

## Status and scope

This document defines the integration-test contract for the future equipment-fault persistence adapter. It does not implement a database adapter, create or alter a schema, run migrations, or connect to the production Supabase project.

The existing unit tests validate application policies and service orchestration. They are not evidence that PostgreSQL queries enforce station isolation, that audit writes are transactional, or that concurrent transitions are serialized.

## Test environment

- Run against a disposable PostgreSQL database using the same major version and relevant extensions as the approved target schema.
- Prefer an ephemeral database/container per test run or test collection. Never point destructive integration tests at production or the existing legacy database.
- Apply only the reviewed and explicitly approved schema to the disposable database.
- Use the same SQL statements, constraints, indexes, triggers, and transaction boundaries as the production adapter.
- Use a least-privilege application database role for application-path tests. Keep schema-owner/admin credentials restricted to fixture setup and teardown.
- Seed deterministic fixtures with at least two distinct stations (Station A and Station B), multiple faults per station, equal OccurredAt timestamps, and audit entries.
- Tests must clean up their own data or discard the disposable database. Do not rely on test ordering.

## Required scenarios and assertions

### 1. Station isolation in list and count queries

**Arrange**
- Insert faults for Station A and Station B.
- Include rows that match and do not match each supported status, severity, and occurred-at filter.
- Include equal OccurredAt values across multiple rows to exercise the stable tie-breaker.

**Act**
- Execute the list operation for Station A and for Station B with identical filters and page windows.

**Assert**
- Every returned item has the requested StationId.
- TotalCount counts only rows matching both the requested station and all supplied filters.
- The count query and page query use equivalent predicates; a matching row from Station B must not affect Station A's count or page.
- Ordering is deterministic: OccurredAt followed by unique FaultId, with the direction explicitly defined by the sort contract.
- Across successive pages, no row is duplicated or skipped for an unchanged fixture.
- Empty and out-of-range pages return correct metadata and an empty item set where appropriate.

**Negative regression**
- A fault in Station B that matches every other filter must remain invisible to Station A, including in TotalCount.

### 2. Cross-station detail lookup

**Arrange**
- Insert a fault owned by Station B.

**Act**
- Request its detail using the correct FaultId and Station A's StationId.

**Assert**
- The persistence query applies FaultId and StationId together in one predicate.
- The result is null / not found, matching the same externally visible result as an unknown fault ID.
- No detail fields or ownership information are returned or leaked.
- A request with Station B's ID returns the detail only when the caller is authorized for Station B.

### 3. Audit insert failure rolls back the transition

**Arrange**
- Insert a fault in a known initial status.
- Configure a deterministic database-side failure for the audit insert in the disposable test database (for example, a test-only constraint/trigger that raises an error for a designated fixture marker). Do not add a production bypass or test hook to the application code.

**Act**
- Execute a valid status transition through the real persistence adapter.

**Assert**
- The operation reports failure and never reports Applied.
- The fault status remains exactly the initial status.
- No audit row for the attempted transition exists.
- No partial side effect (outbox/event row, if part of the approved design) remains.
- The transaction is rolled back as a unit.

**Control**
- Run the same transition without the injected audit failure and assert that the status update and exactly one corresponding audit row both commit.

### 4. Two concurrent transitions

**Arrange**
- Insert one fault in a known initial status.
- Prepare two distinct valid transition requests that both expect that same initial status.
- Start both operations concurrently and coordinate them with a barrier so both contend at the persistence boundary; avoid timing-only sleeps.

**Act**
- Execute both against the same fault and station.

**Assert**
- Exactly one operation returns Applied.
- The other returns Conflict (or the single documented equivalent for a stale expected status).
- The persisted status equals the winning transition's next status.
- Exactly one audit event for the successful transition exists.
- No audit event exists for the losing transition.
- The final state and audit history agree.
- Repeat the test enough times to expose race conditions; do not assert which contender wins.

The database write must compare the persisted station and expected status as part of the authoritative write operation. An application-side pre-read or in-memory lock is not sufficient.

### 5. Audit immutability

**Arrange**
- Insert an audit event through the approved creation/transition path.
- Connect using the least-privilege application database role.

**Act**
- Attempt UPDATE and DELETE against the audit row using the application role.

**Assert**
- Both operations are rejected by database-enforced controls (privileges and/or an immutable-row trigger, according to the approved schema).
- The audit row remains byte-for-byte/logically unchanged.
- The application role cannot bypass immutability by calling an alternate application endpoint or repository method.
- Normal insertion of a new audit event remains possible through the approved transactional path.

**Important**
- Do not run the immutability assertion as the schema owner and infer application-role protection from it. PostgreSQL superusers and object owners have elevated capabilities; the test must exercise the actual application role.
- If the approved design uses a trigger, test both UPDATE and DELETE; if it uses grants, verify the effective privileges as well as the rejected statements.

## Test organization

Suggested test suite names (final names may follow the chosen persistence technology):

- EquipmentFaultStoreStationIsolationTests
- EquipmentFaultStoreDetailScopeTests
- EquipmentFaultTransitionAtomicityTests
- EquipmentFaultTransitionConcurrencyIntegrationTests
- EquipmentFaultAuditImmutabilityIntegrationTests

These belong in a distinct integration-test project or clearly isolated test collection. They must not silently run against a developer's configured production connection string.

## CI requirements

- Add a dedicated PostgreSQL service/container for integration tests, pinned to the approved major version.
- Fail fast if the integration connection string is missing or points to a non-disposable environment.
- Run schema setup only against the ephemeral test database.
- Publish test results separately from unit-test results so a green unit-test job cannot be mistaken for a green storage-integration job.
- Preserve logs for failed assertions and database exceptions, while redacting connection strings, credentials, and sensitive row data.
- Keep the existing .NET 10 unit-test workflow intact; add integration coverage as a separate job or explicit test stage.

## Exit criteria before storage implementation is considered verified

1. All five scenario groups above pass against the real PostgreSQL adapter.
2. Station isolation is enforced in SQL, not only by post-query validation.
3. Transition and audit insert share one database transaction.
4. The concurrent transition test consistently produces one winner and one conflict.
5. The application database role cannot update or delete audit rows.
6. CI reports the integration suite independently and successfully.

## Approval boundary

This plan is documentation only. No database schema, migration, SQL function/RPC, grants, RLS policy, trigger, or production data has been changed. Implementing these tests against a concrete schema requires review and explicit approval of the proposed SQL and disposable test-database setup.
