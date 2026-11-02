# METRA 2027 — Registration Atomic Persistence Design

**Status:** implementation design for review; not an approved physical schema or migration.  
**Scope:** the PostgreSQL implementation boundary for the existing `IRegistrationSubmissionStore` contract.  
**Safety:** this document adds no database objects and authorizes no connection to the legacy project or changes to the selected Supabase project.

## 1. Required atomic outcome

A successful first registration must commit exactly one logical bundle:

1. A METRA account in `PendingApproval`.
2. One account-to-Supabase-Auth link using the validated JWT `sub` UUID.
3. One registration request in `PendingStationApproval`.
4. One append-only registration-submitted audit event.

The transaction must not create an effective role grant, station assignment, approval decision, or notification delivery. The requested role and station remain request data until both approval stages finish.

## 2. Adapter boundary

The production adapter will implement only:

`IRegistrationSubmissionStore.TryCreatePendingAsync(PendingRegistrationSubmission, CancellationToken)`

It must receive an already validated, normalized application command. It must not accept an Auth subject from HTTP input, call Supabase Auth, infer roles, or resolve labels. It must use the API's least-privilege PostgreSQL runtime identity and a single database connection/transaction.

The adapter must not be registered in dependency injection until the physical schema, constraints, runtime grants and integration-test database are approved.

## 3. Transaction algorithm

Use PostgreSQL `READ COMMITTED` with unique constraints as the final concurrency arbiter (or a stricter isolation level only if integration tests prove it is required). Within one transaction:

1. Check cancellation and begin the transaction.
2. Resolve an existing idempotency result scoped to `(auth_user_id, idempotency_key)`. If present and its canonical request payload matches, return the original account/request IDs as `AlreadyCreatedForSameIdempotencyKey`. If the key is reused with a different payload, return `Conflict`; never silently treat it as a replay.
3. Check whether the Auth UUID is already linked. If so, return `AuthUserAlreadyLinked` without exposing the linked account.
4. Check whether an outstanding registration request exists for this Auth UUID. If so, return `ExistingPendingRequest`.
5. Insert the pending account.
6. Insert the account/Auth link. The unique Auth UUID and account constraints must reject races.
7. Insert the registration request with requested role/station, terms version, idempotency key, and server timestamp.
8. Append the submission audit event, including correlation/trace reference where available and minimal necessary metadata.
9. Commit once. Return `Created` with the persisted account and request IDs.

Any failure before commit must roll back all four writes. A unique-constraint race must be caught outside the failed transaction (after rollback); then perform a fresh, bounded read to classify the winner as exact idempotent replay, already-linked identity, existing pending request, or conflict. Do not continue issuing SQL in an aborted PostgreSQL transaction.

## 4. Constraint and index requirements

The eventual reviewed schema must enforce, not merely document:

- Unique active Auth link per `auth_user_id`.
- Unique active Auth link per `account_id` for the one-to-one first-release policy.
- Unique idempotency key per Auth UUID.
- A rule preventing more than one outstanding initial registration per Auth UUID (partial unique index over the defined outstanding states, or an equivalent concurrency-safe design).
- Foreign keys from link/request/audit references to their canonical METRA records.
- Valid state values and non-null required fields.
- Append-only audit behavior for the runtime role (no UPDATE/DELETE privileges).
- Appropriate indexes for Auth UUID, request state, station review queue and idempotency lookup.

Exact table/column names, state literals, partial-index predicate and FK deletion behavior must be aligned with the approved canonical physical schema. This document intentionally does not provide executable DDL.

## 5. Idempotency payload binding

An idempotency record must be bound to the semantic request, not only the key. Compare normalized persisted fields or a server-computed versioned digest over canonical serialization of:
- first, father and last names;
- normalized optional phone;
- requested role code and station ID;
- exact terms version and acceptance.

Do not include bearer tokens, passwords, refresh tokens, or other credentials. Do not use a client-provided digest as authoritative. A changed payload under a reused key is a conflict. Keep the canonicalization version explicit so future normalization changes do not reinterpret historic keys.

## 6. Audit and privacy

The audit event should capture the Auth subject reference, account/request IDs, event type, UTC timestamp, correlation ID, terms version, and outcome. Avoid copying the complete registration body into audit or application logs. Never store credentials or raw JWTs. Restrict audit reads and writes by dedicated permissions; runtime API identity may append but not alter prior events.

## 7. Failure and retry matrix

| Condition | Store result / behavior |
|---|---|
| First valid submission | Commit all four records; `Created` |
| Same Auth UUID, key and same semantic payload | Return original IDs; no new writes or audit event |
| Same key, changed semantic payload | `Conflict` |
| Auth UUID already linked | `AuthUserAlreadyLinked` |
| Different key but outstanding request exists | `ExistingPendingRequest` |
| Concurrent duplicate requests | Unique constraint selects one winner; loser classifies after rollback |
| Audit insert fails | Roll back account, link and request too |
| Connection drops during commit | Treat outcome as unknown; retry with same idempotency key and reconcile, never generate a new key automatically |
| Caller cancellation before commit | Roll back; propagate cancellation |
| Caller cancellation after commit may have occurred | Reconcile with same key; do not assume rollback |

## 8. Operational boundaries

- Notification/email/SMS delivery must use an outbox written in the same transaction only if an approved outbox schema exists; otherwise keep notification outside this change and retry it from a separately approved workflow.
- Do not call Supabase Auth admin APIs inside the PostgreSQL transaction.
- Do not delete an Auth user when METRA persistence fails. Preserve the retry/reconciliation path for orphaned Auth identities.
- Do not grant browser/mobile clients direct table access.
- Do not use service-role or migration credentials as the API runtime connection.
- Do not enable the registration endpoint until the real store, authoritative active catalogue, integration tests, rate-limit identity strategy, and approval workflow are ready.

## 9. Integration test gate

Use an isolated disposable PostgreSQL database created by CI/test infrastructure, never either Supabase project. Required tests:

1. A successful transaction creates all four records and no grants/assignments.
2. Failure injected after each individual write leaves zero partial records.
3. Same key/same payload returns the same IDs and does not append another audit event.
4. Same key/different payload is rejected.
5. Same Auth UUID/different keys cannot create duplicate pending requests.
6. Parallel submissions produce exactly one pending bundle.
7. A concurrent link insertion is classified safely after transaction rollback.
8. Simulated connection loss around commit is reconciled by retrying the same idempotency key.
9. Runtime database role cannot update/delete audit rows or write effective grants/assignments during submission.

## 10. Approval checklist before implementation

- [ ] Physical schema and state machine approved by the domain owner.
- [ ] Auth-link FK to `auth.users(id)`, deletion semantics and ownership reviewed.
- [ ] Unique and partial indexes reviewed against actual account/request lifecycle.
- [ ] Runtime database role and grants approved.
- [ ] CI PostgreSQL test environment isolated from all production and legacy projects.
- [ ] Authoritative role/station catalogue read adapter approved.
- [ ] Audit event vocabulary and retention approved.
- [ ] Integration tests pass under real PostgreSQL concurrency.
- [ ] Endpoint mapping separately approved after all above gates.

Until those approvals are recorded, the implementation remains an interface and design contract. No schema migration, database adapter, database connection, or endpoint activation is authorized by this document.
