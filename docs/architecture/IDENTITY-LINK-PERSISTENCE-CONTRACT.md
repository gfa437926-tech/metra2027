# METRA 2027 — External Identity Link Persistence Contract

Status: proposed persistence contract. This is not an executable migration and does not select a database schema, identity provider, or Supabase configuration.

Related documents:
- `IDENTITY-API-CONTRACT.md`
- `AUTHENTICATION-SESSION-SECURITY-DESIGN.md`
- `SECURITY-CRYPTOGRAPHY-BASELINE.md`
- `THREAT-MODEL-AND-SECURITY-REGISTER.md`

## 1. Security invariants

A persisted external identity link maps exactly one validated external identity to exactly one canonical METRA account.

1. The identity key is the exact pair `(issuer, subject)`. Both values originate only from a validated provider proof, never from a request body.
2. Issuer comparison is exact and case-sensitive. Do not lowercase it, remove a trailing slash, decode/re-encode its path, or otherwise normalize it. OIDC issuer identifiers are identifiers, not display URLs.
3. Subject is opaque and case-sensitive. Do not trim, lowercase, parse, or derive it from email, phone, username, or display name.
4. The same issuer+subject pair must never be linked to two METRA accounts.
5. A METRA account may have multiple external identities only if the product explicitly permits it and each additional identity has independently verified proof-of-possession.
6. Linking must not create or activate a METRA account. Account provisioning and approval remain separate workflows.
7. The account must be active both before the application operation and again inside the persistence transaction immediately before commit.
8. Link row and audit event commit atomically. A failed audit write means the identity link must not commit.
9. Reads and writes fail closed on missing, ambiguous, stale, or inconsistent identity data.
10. No endpoint, UI, support tool, or client-supplied ID may bypass these invariants.

## 2. Identity-key validation

The current application boundary performs basic defensive validation before calling the store:
- issuer is an absolute HTTPS URI;
- issuer contains no user information, query, or fragment;
- issuer length is at most 512 characters;
- subject is non-empty and at most 255 characters;
- neither value contains control characters;
- original issuer and subject strings are passed unchanged to the store.

This validation is not a substitute for OIDC validation. The trusted proof adapter must additionally validate signature, exact configured issuer, audience/client ID, nonce, state, authorization-code binding, PKCE, expiry, and provider-specific requirements. Provider-specific issuer allow-list configuration is mandatory. Do not accept an arbitrary HTTPS issuer.

## 3. Logical data model

The concrete migration must map the METRA account foreign key to the already-approved canonical account table. That table and key are not yet verified in this repository, so no guessed foreign key or executable migration is included.

### Identity link record

Required logical fields:

| Field | Requirement |
|---|---|
| id | Opaque server-generated primary key |
| metra_user_id | Foreign key to the canonical METRA account; never a provider subject |
| issuer | Exact validated issuer identifier, or an encrypted representation with a deterministic lookup key |
| subject | Exact opaque provider subject, protected at rest according to data classification |
| linked_at | UTC timestamp assigned by the server |
| linked_by_user_id | Canonical METRA account that initiated the link |
| status | Explicit active/revoked state; unknown values are not active |
| revoked_at | Nullable UTC timestamp |
| created_at | UTC timestamp |
| updated_at | UTC timestamp, updated only by controlled audited operations |

Constraints and indexes:
- unique exact issuer+subject for all active links;
- foreign key to canonical METRA account with deletion restricted or an approved anonymization workflow;
- index by METRA account ID for account identity listing and recovery;
- check constraints for non-empty issuer/subject and valid status values;
- no cascade delete from account to audit history;
- all timestamps use timezone-aware database types and UTC application values.

If the product requires historical relinking, retain revoked rows and enforce uniqueness only for active rows with a partial unique index. Re-linking a previously revoked identity must be a separately authorized operation, not an implicit upsert. Concurrent attempts must be serialized by the unique constraint and transaction.

### Audit event

The same transaction must append an event with:
- event ID and UTC timestamp;
- actor METRA account ID;
- target METRA account ID;
- action (`identity.linked`, and later separately approved `identity.revoked`);
- identity-link record ID;
- outcome and stable reason code;
- correlation/request ID;
- trusted authentication/proof timestamps and assurance context, without storing raw ID/access/refresh tokens;
- previous/new status where applicable.

Do not put raw provider tokens, authorization codes, client secrets, MFA secrets, or full subject values in audit logs. Avoid recording email/phone unless required by a documented audit purpose.

Application-level append-only behavior is not sufficient against a database owner. The deployed database role used by the API should have INSERT/SELECT privileges on audit records but no UPDATE/DELETE privileges. Migration/owner credentials must not be used by the runtime API. Where regulatory or insider-risk requirements justify it, export audit events to a separately controlled append-only/WORM destination.

## 4. Protecting the external subject

The subject is an account-linking identifier and should be treated as sensitive identity data, even though it is not a credential.

The implementation review must choose and document one of:
- database/storage encryption at rest with strict DB access controls, TLS in transit, restricted backups and logs; or
- application-level envelope encryption for the raw subject plus a keyed deterministic lookup fingerprint (HMAC) for uniqueness and lookup.

Do not use an unkeyed SHA hash as a substitute for encryption or a keyed fingerprint. If HMAC is selected:
- use a dedicated key managed by KMS/HSM, not a source-code or database-stored secret;
- include a domain separator and unambiguous length-prefix encoding of issuer and subject;
- store key version metadata;
- plan dual-fingerprint rotation and uniqueness conflict handling before rotating;
- never reuse encryption keys as HMAC keys;
- never log the fingerprint or raw subject.

No encryption scheme or key-management provider is selected by this contract. The chosen design must be tested for key rotation, backup restoration, key loss and incident revocation before production.

## 5. Atomic store operation

The production implementation of `IIdentityLinkStore.TryLinkAsync` must execute one transaction equivalent to:

1. Lock/read the canonical METRA account row and confirm it is active.
2. Validate that the actor is the same canonical account and that the verified identity proof is still within the allowed freshness window.
3. Look up the exact identity key under the approved issuer/subject comparison rules.
4. If active link exists for this same account, return `AlreadyLinkedToSameAccount` without creating a duplicate event unless an explicit idempotent audit policy says otherwise.
5. If active link exists for another account, return `IdentityLinkedToDifferentAccount`; never transfer it.
6. If a concurrent insert wins, catch only the expected unique-constraint violation, re-read the row and map to same-account or different-account outcome. Do not swallow unrelated database errors as a conflict.
7. Insert the identity link and its audit event in the same transaction.
8. Commit, then return `Linked`.

Map only known unique-constraint violations. A deadlock, timeout, serialization failure, audit failure or unknown database exception must not be reported as successful linking. Retry only errors known to be transient and only with bounded retry plus idempotent transaction semantics.

The store must propagate request cancellation and must not return database names, SQL text, constraint names or provider internals to the client.

## 6. Issuer/subject uniqueness and collation

PostgreSQL text equality is case-sensitive under deterministic collations, but the actual database collation and index definition must be verified. Do not assume that all database engines or collations behave identically.

The migration must explicitly select deterministic, case-sensitive comparison semantics for issuer and subject (or a byte-stable representation), and test:
- issuer with and without trailing slash are distinct identifiers;
- subject `AbC` and `abc` are distinct;
- Unicode and non-ASCII subject values follow provider specification;
- whitespace/control characters are rejected;
- tenant/realm issuers cannot collide;
- duplicate concurrent inserts yield exactly one active link.

## 7. Account lifecycle and recovery

- Suspending or rejecting a METRA account blocks identity linking and all protected operations even if provider authentication succeeds.
- Account deletion must not cascade-delete identity-link audit evidence. Use an approved retention/anonymization policy.
- Provider account deletion, compromise or issuer retirement must have a controlled incident/revocation workflow.
- Unlinking is not enabled by this contract. Before it exists, define last-login-method protection, alternative verified recovery method, recent step-up proof, notifications, cooldown, audit, and support escalation.
- A user must never be allowed to unlink the only usable authentication method without a verified replacement/recovery route.

## 8. Required tests before enabling a concrete adapter

- exact issuer and subject round-trip;
- issuer trailing-slash and subject case-sensitivity;
- duplicate link to same account;
- cross-account collision;
- concurrent same-key insert race;
- account suspension between service check and transaction commit;
- audit write failure rolls back identity link;
- cancellation and database timeout;
- database collation behavior;
- encryption/HMAC key rotation and backup restore, if selected;
- account deletion/anonymization retention;
- no raw token/subject leakage in logs and errors.

## 9. Activation gate

Do not create or apply a database migration until all of the following are confirmed:
1. canonical METRA account table and primary key;
2. approved PostgreSQL/Supabase hosting and migration ownership;
3. identity provider, issuer allow-list and subject semantics;
4. account-to-identity cardinality policy;
5. audit retention and access-control policy;
6. subject protection and KMS/HSM key ownership;
7. production transaction/concurrency integration tests;
8. backup, restore, monitoring and incident-response procedures.

Until then, `IIdentityLinkStore` remains an unimplemented contract. No live database, Supabase Auth, RLS, schema, existing account record or secret has been changed.
