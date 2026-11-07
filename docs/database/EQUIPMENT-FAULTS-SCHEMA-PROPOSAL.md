# Equipment Faults — Database Schema Proposal

**Review status:** Conditional technical approval of the logical model only.
**Execution status:** NOT APPROVED FOR DATABASE DEPLOYMENT.
**Target:** the new METRA Supabase project only, after the station-catalogue key is verified.
**Legacy database:** explicitly excluded.

This document is a design proposal, not a migration. It contains no executable DDL and must not be applied as SQL.

## 1. Review findings and blockers

The current application contracts support a two-table minimum model: the current fault record and an append-only audit history. The read-store contract is station-scoped, and list projections now carry `StationId` so the application boundary can reject a foreign-station row even if a future adapter accidentally returns one.

The creation-audit contract blocker has been addressed in the domain model: `EquipmentFaultAuditEntry.PreviousStatus` is nullable, and `EquipmentFaultAuditPolicy` accepts a null previous state only when the new state is `Submitted`. This models the initial Created event without inventing a Submitted-to-Submitted transition.

One schema-mapping decision remains before a migration can be generated:

1. **Station foreign key:** the exact table and primary-key column in the approved new station catalogue must be confirmed from its authoritative schema. This proposal deliberately does not guess a table name or reuse the legacy station catalogue.

The user identity reference assumes Supabase Auth user UUIDs. Confirm that the JWT `sub` used by the API maps directly to `auth.users.id` in the target project.

## 2. Proposed entities

### 2.1 `equipment_faults`

One row represents the current state of one reported equipment fault.

| Column | Proposed type | Nullability | Purpose |
|---|---|---|---|
| `id` | uuid | NOT NULL, generated | Stable fault identifier / primary key |
| `station_id` | uuid | NOT NULL | FK to the approved new station catalogue |
| `reporter_id` | uuid | NOT NULL | Auth user who submitted the fault |
| `category` | varchar(80) | NOT NULL | Equipment category |
| `equipment_name` | varchar(120) | NOT NULL | Equipment name |
| `description` | varchar(4000) | NOT NULL | Fault description |
| `severity` | text | NOT NULL | Low / Medium / High / Critical |
| `status` | text | NOT NULL, default Submitted | Current lifecycle state |
| `occurred_at` | timestamptz | NOT NULL | User-reported occurrence time |
| `is_operationally_blocking` | boolean | NOT NULL, default false | Whether station operation is blocked |
| `created_at` | timestamptz | NOT NULL, server-generated | Record creation time |
| `updated_at` | timestamptz | NOT NULL, server-generated | Last state change time |

Constraints:
- Primary key on `id`.
- Unique composite key on `(id, station_id)`, required by the audit table's composite foreign key.
- Foreign key `station_id` to the verified new station-catalogue key, with deletion restricted.
- Foreign key `reporter_id` to `auth.users(id)`, with deletion restricted or handled by an approved anonymisation policy.
- CHECK constraints for the exact status and severity strings used by the .NET domain.
- CHECK constraints for trimmed text and the same length limits as domain validation.
- CHECK constraint: when `is_operationally_blocking = true`, severity must be High or Critical.
- No hard-delete operation in the application contract.

### 2.2 `equipment_fault_audit`

Immutable history for creation and every lifecycle transition.

| Column | Proposed type | Nullability | Purpose |
|---|---|---|---|
| `id` | bigint identity | NOT NULL | Monotonic audit row identifier |
| `fault_id` | uuid | NOT NULL | Fault identifier |
| `station_id` | uuid | NOT NULL | Station scope captured at event time |
| `actor_id` | uuid | NOT NULL | Auth user performing the action |
| `event_type` | text | NOT NULL | Created / StatusTransition |
| `occurred_at` | timestamptz | NOT NULL, server-generated | Trusted event timestamp |
| `previous_status` | text | NULL only for Created | Previous lifecycle state |
| `new_status` | text | NOT NULL | Resulting lifecycle state |
| `reason` | varchar(1000) | NOT NULL | Creation/transition explanation |

Constraints:
- Composite foreign key `(fault_id, station_id)` references `equipment_faults(id, station_id)`; this prevents audit rows from being attached to a different station.
- Foreign key `actor_id` to `auth.users(id)`.
- `Created` requires `previous_status IS NULL` and `new_status = 'Submitted'`.
- `StatusTransition` requires a non-null previous status and a transition permitted by the domain state machine.
- Reason length 5–1000 and no leading/trailing whitespace, subject to a distinct creation-reason rule if needed.
- No UPDATE or DELETE privileges for application roles. Audit rows are append-only.
- The database, not the client, supplies `occurred_at`.

## 3. Index proposal

1. `equipment_faults(station_id, occurred_at DESC, id DESC)` — default newest-first station list and deterministic pagination.
2. `equipment_faults(station_id, status, occurred_at DESC, id DESC)` — common status-filtered lists.
3. `equipment_faults(station_id, severity, occurred_at DESC, id DESC)` — common severity-filtered lists.
4. `equipment_fault_audit(station_id, fault_id, occurred_at DESC, id DESC)` — station-scoped audit history.

The list COUNT and page SELECT must use the identical station predicate and filter predicate. The station predicate must be applied before COUNT, ordering, OFFSET, and LIMIT. The adapter must never fetch all stations and filter in application memory.

## 4. Authorization and data protection

- Enable RLS on both tables because they are in an exposed application schema.
- The initial access model is server-only: do not grant table access to `anon` or `authenticated`; grant only the minimum required privileges to the backend service role.
- The service-role key remains in the .NET host secret manager and is never included in Angular, Flutter, browser configuration, logs, or source control.
- RLS is defense-in-depth; server-side authorization must still verify the caller's identity, station membership, and `equipment_fault.read/create/review/assign/resolve/close` permission.
- The API derives `reporter_id` and `actor_id` from validated JWT `sub`; request bodies cannot supply or override them.
- No client may update `station_id`, `reporter_id`, `created_at`, audit rows, or lifecycle status directly.
- No public views or SECURITY DEFINER functions are proposed.
- Audit data must be retained according to the METRA records-retention policy; no retention duration is invented here.

## 5. Atomic transition requirement

The existing transition writer contract requires status update and audit append to be one atomic database operation. Two separate PostgREST requests are not acceptable.

For the current REST-based Supabase adapter, the recommended implementation is one narrowly scoped database routine in a dedicated API schema, callable only by the backend service role, using invoker rights and explicit expected-value predicates. It must:
1. match `fault_id`, persisted `station_id`, and expected current status;
2. validate the transition and reason;
3. update the current fault row and server-side `updated_at`;
4. append the corresponding audit row;
5. return Applied / Conflict / NotFoundOrWrongStation without disclosing cross-station existence.

The exact schema exposure and EXECUTE grants must be reviewed with the target project's PostgREST configuration before implementation. Do not use SECURITY DEFINER as a shortcut.

## 6. Integration-test requirements

After schema approval and migration in an isolated test project:
- Seed two stations and users with disjoint station permissions.
- Verify list rows and COUNT are scoped to station A for a station-A user, even when station B has more/newer rows.
- Verify status/severity/time filters do not widen station scope.
- Verify a detail read using a station-A route and a station-B fault returns the same non-disclosing result as a missing fault.
- Verify pagination and equal-timestamp ordering remain deterministic.
- Verify a station-B identifier supplied by a station-A user is denied by authorization.
- Verify cross-station transition attempts write neither status changes nor audit rows.
- Verify concurrent transitions yield exactly one applied update and exactly one matching audit event.
- Verify audit UPDATE/DELETE attempts fail.
- Verify no direct table access is available to anon/authenticated clients.
- Verify database advisors and query plans for the station-scoped list paths.

## 7. Review decision

**Conditionally accepted as the proposed logical design**, subject to confirmation of the target catalogue's exact key and identity mapping in section 1. The table shapes, constraints, indexes, server-only access model, and atomicity requirements are internally consistent with the current fault lifecycle and read contracts.

**Not approved for execution.** No SQL, migration, RPC, grants, RLS policy, or database object has been created. A separate explicit deployment approval is required after the station foreign-key mapping and creation-audit contract are resolved.
