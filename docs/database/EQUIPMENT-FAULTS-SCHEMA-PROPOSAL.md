# Equipment Faults — Database Schema Proposal

**Review status:** Approved logical model after read-only verification of the target station catalogue and identity references.
**Execution status:** Migration/application remains gated; no database change has been made.
**Target:** the new METRA Supabase project only (`tbdnklyxjvbrilvnwgmq`).
**Legacy database:** explicitly excluded.

This document is a design proposal, not a migration. It contains no executable DDL and must not be applied as SQL.

## 1. Review findings and blockers

The current application contracts support a two-table minimum model: the current fault record and an append-only audit history. The read-store contract is station-scoped, and list projections now carry `StationId` so the application boundary can reject a foreign-station row even if a future adapter accidentally returns one.

The creation-audit contract blocker has been addressed in the domain model: `EquipmentFaultAuditEntry.PreviousStatus` is nullable, and `EquipmentFaultAuditPolicy` accepts a null previous state only when the new state is `Submitted`. This models the initial Created event without inventing a Submitted-to-Submitted transition.

Read-only inspection of the target project confirmed:
- `public.station_catalogue.id` is a UUID primary key; this is the only approved operational station catalogue and is already referenced by current METRA tables.
- Existing METRA identity tables reference `auth.users(id)`; the backend's validated JWT `sub` is the user UUID used by its authorization services.

No station-table or identity mapping blocker remains for the logical model. These checks were read-only; no schema or data was changed.

## 2. Proposed entities

### 2.1 `equipment_faults`

One row represents the current state of one reported equipment fault.

| Column | Proposed type | Nullability | Purpose |
|---|---|---|---|
| `id` | uuid | NOT NULL, generated | Stable fault identifier / primary key |
| `station_id` | uuid | NOT NULL | FK to `public.station_catalogue(id)` |
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
- Foreign key `station_id` to `public.station_catalogue(id)`, with deletion restricted. The target table and UUID key were confirmed by read-only schema inspection.
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

**Approved as the logical design for implementation.** The target station key and Auth identity mapping have been verified read-only. The table shapes, constraints, indexes, server-only access model, and atomicity requirements are internally consistent with the current fault lifecycle and read contracts.

**Database execution is still gated.** This is technical approval of the model, not permission to apply it to the live project. No SQL, migration, RPC, grants, RLS policy, or database object has been created. Before applying a migration, present its exact SQL and request your explicit deployment approval.


## 8. Atomic writer acceptance criteria (implementation gate)

The following criteria are mandatory for the future implementation of
`IEquipmentFaultTransitionWriter.TryTransitionAsync`; they clarify the
transaction boundary without prescribing executable SQL:

1. The routine receives the fault ID, expected station ID, expected current
   status, requested next status, authenticated actor ID, and validated reason.
   It must not accept a client-supplied audit timestamp or station owner.
2. It must validate that both statuses are defined and that the exact
   (previous, next) pair exists in the domain transition matrix. Terminal
   states, self-transitions, and all unlisted pairs are rejected.
3. The write predicate must match the fault ID, persisted station ID, and
   expected current status together. The current status used for the audit
   event must be the value matched by this same atomic operation, not a
   separately pre-read value.
4. A successful operation changes exactly one current fault row and appends
   exactly one corresponding immutable audit row in the same transaction.
   The audit row must carry the same fault and station IDs, actor, previous
   and next statuses, validated reason, and a database-generated timestamp.
5. If the current-row update affects no row, no audit row may be inserted.
   If audit insertion, a constraint, or any later transactional step fails,
   the current-row update must roll back. A partial success is never valid.
6. The operation returns Applied only after the transaction commits. A stale
   status returns Conflict; a missing fault or station mismatch returns the
   same non-disclosing NotFoundOrWrongStation result. Infrastructure and
   transaction failures must not be mapped to Applied.
7. Concurrent requests using the same expected status must yield at most one
   Applied result and exactly one audit event for that successful transition.
   The losing request must return Conflict (or the non-disclosing missing /
   wrong-station result if ownership no longer matches).
8. The application service's preliminary ownership and permission checks are
   not substitutes for these database predicates. The routine repeats the
   authoritative station and status checks at write time.

Required integration tests must assert the transaction effects, not merely
the returned enum: after a rejected or failed transition, both current status
and audit count remain unchanged; after one successful transition, exactly
one matching audit row exists; and after a concurrent race, exactly one
request succeeds and exactly one audit event is persisted.
