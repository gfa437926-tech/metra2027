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

Every mutation requires a bounded reason and obtains actor identity only from the authenticated server context. The target must be Active before the application service attempts a mutation. The store remains the authoritative security boundary and must, within one transaction, reload and lock actor/target/catalogue facts, re-check target state and actor permission for the exact action and scope, validate that the station is active and the permission is known/enabled, compare the expected version, persist the change and append an immutable audit event. It must return explicit conflict, not-found, unauthorized, unknown/disabled-catalogue, and already-revoked outcomes. The application layer deliberately does not infer role hierarchies or grant privileges.

The application service validates command shape and temporal record structure before actor lookup. It does not decide whether a permission is product-approved, whether a station is active, whether a caller may administer another user, or whether a permission may be granted globally; those checks require authoritative catalogue and policy decisions inside the store transaction.

## Audit event minimum

For account lifecycle, station assignment, and permission grant/revoke events, persist at minimum: event ID, target account ID, action, previous and next state or exact resource scope, authenticated actor account ID, UTC occurrence time, reason/administrative note where policy permits, correlation/request ID, and concurrency/version reference. Never persist bearer tokens, passwords, or secrets. Audit records must be append-only to application roles. A revoke must preserve the original record and its history.

## Not decided by this contract

No concrete role/permission catalogue values, grant duration defaults, station activation rules, reactivation eligibility checks, self-administration policy, reason taxonomy, global-grant policy, or retention schedule is selected here. These require approval. No database schema, migration, seed data, Supabase project access, production adapter, or endpoint activation is included.
