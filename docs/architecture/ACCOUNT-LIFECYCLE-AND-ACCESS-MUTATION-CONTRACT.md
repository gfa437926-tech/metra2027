# METRA 2027 — Account Lifecycle and Access Mutation Contract

Status: pure domain transition policies and framework-independent application orchestration contracts are implemented. Production storage adapters, HTTP endpoints and database changes are intentionally not activated.

## Account lifecycle

The policy supports only these transitions:

| Current state | Command | Next state |
|---|---|---|
| Active | Suspend | Suspended |
| Active | Disable | Disabled |
| Suspended | Restore | Active |
| Suspended | Disable | Disabled |

PendingApproval is governed by the registration approval workflow and cannot be changed by these lifecycle commands. Disabled is terminal in this contract. No automatic restore, deletion, or reactivation path exists.

The lifecycle application service resolves the actor from a server-side provider, requires a nonblank reason for suspension/disable, bounds reason length, applies the transition policy, and delegates to a transactional store. The store must reload and lock target + actor authorization facts, verify explicit permission, compare state and version, update account state, and append the immutable audit event in one transaction. Restore must not alter grants or assignments. Self-administration rules and exact permission codes require product approval before endpoints are introduced.

## Effective access consequences

The effective-permission evaluator denies every account state except Active. Suspension and disable therefore take effect at authorization evaluation without deleting grants or assignments. Restoring a suspended account changes only account state; it must not recreate revoked grants, add permissions, or widen station scope.

## Station assignments and permission grants

A station assignment supplies scope, not permission. A permission grant supplies permission, not station membership. Station-scoped operations require both records to be effective at the evaluation instant and to reference the exact same station. A global permission is not a wildcard for a station-scoped operation.

MetraAccessMutationApplicationService now coordinates four explicit operations:

- GrantPermission: a validated canonical permission code, optional exact station scope and UTC validity window.
- RevokePermission: an exact existing grant record ID; the store records revocation without erasing history.
- AssignStation: a validated exact station ID and UTC validity window.
- RevokeStationAssignment: an exact existing assignment record ID; the store records revocation without erasing history.

Every mutation requires a bounded reason and obtains actor identity only from the authenticated server context. New permission grants and station assignments require the target account to be Active. Revocation remains available for suspended or disabled accounts so administrators can remove residual access; the transactional store must still authorize the actor and re-check the exact record before revoking it. The store remains the authoritative security boundary and must, within one transaction, reload and lock actor/target/catalogue facts, re-check target state and actor permission for the exact action and scope, validate that the station is active and the permission is known/enabled, compare the expected version, persist the change and append an immutable audit event. It must return explicit conflict, not-found, unauthorized, unknown/disabled-catalogue, and already-revoked outcomes. The application layer deliberately does not infer role hierarchies or grant privileges.

The application service validates command shape, bounded account/record identifiers, reason length and control characters, and temporal record structure before actor lookup. It also rejects malformed actor context and inconsistent/non-positive target snapshots before attempting a commit. It does not decide whether a permission is product-approved, whether a station is active, whether a caller may administer another user, or whether a permission may be granted globally; those checks require authoritative catalogue and policy decisions inside the store transaction.

## Audit event minimum

For account lifecycle, station assignment, and permission grant/revoke events, persist at minimum: event ID, target account ID, action, previous and next state or exact resource scope, authenticated actor account ID, UTC occurrence time, reason/administrative note where policy permits, correlation/request ID, and concurrency/version reference. Never persist bearer tokens, passwords, or secrets. Audit records must be append-only to application roles. A revoke must preserve the original record and its history.

## Immutable administrative audit event contract

The domain now defines `MetraAdministrativeAuditEvent` as an immutable scalar fact and `MetraAdministrativeAuditEventPolicy` as a structural validator. Required fields include a unique event identifier, target account, authenticated actor, canonical action code, resource type and identifier, UTC occurrence time, reason, correlation identifier, and positive aggregate version. At least one bounded before/after value is required. Identifiers are bounded and restricted to safe ASCII identifier characters; action/resource codes must be canonical lowercase values. Reasons are trimmed, non-empty and bounded; control characters and oversized change values are rejected.

This validator is not a persistence or tamper-proofing mechanism. The future transactional store must generate trusted event IDs, actor/target references, occurrence time, correlation metadata and aggregate version from server-side transaction context; it must never accept those values as authoritative client input. It must append the event in the same transaction as the account/access mutation, enforce uniqueness and append-only permissions at the database boundary, and prevent application roles from updating or deleting prior events. Event values must be limited to non-secret change context; never include passwords, bearer tokens, signing material, recovery codes, or full request bodies. Retention, export, legal hold and privileged audit-reader policies remain approval items.

## Administrative audit read contract

`MetraAdministrativeAuditQueryService` now defines a read-only query boundary for audit history. Supported filters are target account, actor, canonical action code, resource type, and UTC occurrence-time bounds. Page size is bounded to 1–100. The cursor is opaque to the API, bounded in size, and must be interpreted only by the trusted store. The query service obtains actor identity from the authenticated server context; it does not accept an actor identifier from the request.

The read-store contract must enforce the approved audit-read permission and any approved data/station scope on every request. It must use keyset pagination with deterministic descending order by `(OccurredAtUtc, EventId)`, return no more than the requested page size, and never mutate audit records. The application service validates returned events against the audit event policy, rejects duplicate event IDs, rejects invalid page sizes/cursor combinations, and verifies deterministic ordering. An authorization failure is distinct from an invalid cursor or malformed store response.

The exact audit-reader role/permission, station visibility model, export capability, retention, and legal-hold policy remain unapproved. No endpoint or database adapter is activated by this contract.

## Not decided by this contract

No concrete role/permission catalogue values, grant duration defaults, station activation rules, reactivation eligibility checks, self-administration policy, reason taxonomy, global-grant policy, or retention schedule is selected here. These require approval. No database schema, migration, seed data, Supabase project access, production adapter, or endpoint activation is included.
