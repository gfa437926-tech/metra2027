# METRA 2027 — Account Lifecycle and Access Mutation Contract

Status: pure domain transition policy and framework-independent application orchestration contract implemented. Production storage adapter, HTTP endpoints and database changes are intentionally not activated.

## Account lifecycle

The policy supports only these transitions:

| Current state | Command | Next state |
|---|---|---|
| Active | Suspend | Suspended |
| Active | Disable | Disabled |
| Suspended | Restore | Active |
| Suspended | Disable | Disabled |

PendingApproval is governed by the registration approval workflow and cannot be changed by these lifecycle commands. Disabled is terminal in this contract. No automatic restore, deletion, or reactivation path exists.

The policy is intentionally pure. `MetraAccountLifecycleApplicationService` resolves the actor from a server-side actor provider, requires a nonblank reason for suspension/disable, bounds the reason length, applies the transition policy, and delegates to a transactional store contract. The store must reload and lock target + actor authorization facts, verify the required explicit permission, compare state and version, update account state, and append the immutable audit event in one transaction. Self-administration rules and the exact permission codes require product approval before endpoints are introduced.

## Effective access consequences

The existing effective-permission evaluator already denies every account state except Active. Therefore suspension and disable take effect at authorization evaluation without deleting grants or station assignments. Restoring a suspended account changes only account state; it must not recreate revoked grants, add permissions, or widen station scope.

## Station assignments and permission grants

A station assignment supplies scope, not permission. A permission grant supplies permission, not station membership. Station-scoped operations require both records to be effective at the evaluation instant and to reference the exact same station.

A future grant/revoke application service must:
- accept permission code, optional exact station scope, UTC start/end, and an explicit actor;
- reject unknown/disabled permission codes and unknown/inactive stations using authoritative server-side catalogues;
- reject malformed time windows and non-UTC timestamps;
- prevent clients from choosing actor identity, account state, approval status, or audit metadata;
- append a grant/revoke audit event in the same transaction as the change;
- serialize grant/revoke against authorization checks and concurrent mutations;
- preserve historical records rather than overwriting or deleting grant/assignment history;
- treat repeated revoke and stale expected-version operations as explicit idempotency/conflict outcomes, never as silent success.

## Audit event minimum

For account lifecycle, station assignment, and permission grant/revoke events, persist at minimum: event ID, target account ID, action, previous and next state or exact resource scope, authenticated actor account ID, UTC occurrence time, reason/administrative note where policy permits, correlation/request ID, and concurrency/version reference. Never persist bearer tokens, passwords, or secrets. Audit records must be append-only to application roles.

## Not decided by this contract

No concrete role/permission catalogue values, grant duration defaults, station activation rules, reactivation eligibility checks, self-administration policy, reason taxonomy, or retention schedule is selected here. These require approval. No database schema, migration, seed data, Supabase project access, production adapter, or endpoint activation is included.
