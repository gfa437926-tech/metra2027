# METRA 2027 — Supabase Auth Account-Link Contract

Status: logical persistence contract for review. Supabase Auth is the recommended identity provider. This document is not an executable migration and does not authorize changes to Supabase Auth, PostgreSQL, RLS, grants or keys.

Related documents:
- `IDENTITY-PROVIDER-DECISION.md`
- `CANONICAL-DATA-MODEL-PROPOSAL.md`
- `AUTHENTICATION-SESSION-SECURITY-DESIGN.md`
- `SECURITY-CRYPTOGRAPHY-BASELINE.md`

## 1. Provider and trust boundary

- Supabase Auth owns credentials, sign-in methods, sessions, MFA, email/phone verification and recovery.
- ASP.NET Core 10 owns METRA accounts, registration, roles, permission grants, station assignments and all application authorization.
- Angular and Flutter send Supabase Auth access tokens to the METRA API. They never choose the METRA account ID or Auth user ID used for account linking.
- The API validates the access-token signature, exact configured issuer, audience, expiry, not-before and permitted signing algorithm using the project's public JWKS. Expected issuer form: `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1`; confirm from live non-production metadata before activation. Expected audience is normally `authenticated`; confirm the actual access token.
- The immutable `sub` claim is the Supabase Auth user UUID and must correspond to `auth.users.id`.
- Never use editable `user_metadata` for authorization. Do not accept roles, permissions, station IDs or account state from JWT user metadata or client JSON.
- Never expose Supabase secret/service-role credentials to Angular or Flutter.

## 2. Proposed logical relationship

Proposed application table: `metra.account_auth_links`.

| Field | Logical meaning |
|---|---|
| `account_id` | FK to the canonical METRA account |
| `auth_user_id` | UUID FK to Supabase-managed `auth.users.id` |
| `linked_at` | Server-assigned UTC timestamp |
| `revoked_at` | Nullable timestamp for controlled unlink/revocation |

Proposed cardinality for the first release:
- One METRA account has one Supabase Auth user.
- One Supabase Auth user maps to at most one METRA account.
- Enforce uniqueness on both `account_id` and `auth_user_id`.
- Multiple login methods attached to the same Supabase Auth user (email/password, OAuth, etc.) remain within Supabase Auth and do not create additional METRA accounts.
- Linking a second distinct Supabase Auth user to an existing METRA account is not supported unless a separate security and recovery decision approves it.

The FK to `auth.users(id)` is a proposal only. It must be reviewed for schema ownership, deletion behavior and migration permissions before implementation. METRA must never insert, update or delete rows in platform-managed `auth` tables. Do not use cascading deletion to erase METRA account or audit evidence when an Auth user is deleted.

## 3. Registration is not ordinary identity linking

The current `IdentityLinkApplicationService` supports a separately re-authenticated identity being linked to an already-active METRA account. It deliberately rejects inactive accounts. It is therefore not the initial registration flow.

Initial registration should proceed as follows:

1. The user signs up/signs in through Supabase Auth. Supabase creates and manages the Auth user and session.
2. The client calls the METRA registration endpoint using the validated access token. The API derives `auth_user_id` from the trusted `sub` claim; the client does not send it.
3. The API validates the requested role and station against server-owned catalogues, validates the profile and terms, and rejects duplicate or already-linked submissions.
4. In one METRA database transaction, the API creates a pending METRA account, inserts the account-to-Auth link, creates the registration request in `PendingStationApproval`, and appends the submission audit event. No role grant or station assignment is created at this stage.
5. The station manager decides first, constrained by explicit station-approval permission and an active assignment for the requested station.
6. The system manager decides second, and only after station approval.
7. Final approval atomically activates the METRA account, creates the approved role grant and station assignment, advances the request to its final approved state, and appends the decision audit event.

The Supabase Auth sign-up operation and the METRA API transaction are separate transactions. If Auth sign-up succeeds but METRA registration fails, the Auth user remains in Supabase Auth without a METRA account link. The API must return a retry-safe outcome and provide a controlled resume/reconciliation path; it must not create a duplicate account or silently delete the Auth user.

## 4. Database invariants

- The `auth_user_id` value is obtained only from a fully validated Supabase access-token principal.
- A pending, rejected, suspended, closed, unlinked or unknown METRA account cannot access protected METRA resources.
- An authenticated Supabase user without an active METRA account has no application permissions by default.
- A registration request is not an account grant, role grant or station assignment.
- A requested role and station are validated against canonical server-side catalogues; they are not effective permissions.
- Account link, registration request and submission audit event commit atomically in the METRA database.
- Final approval, account activation, role grant, station assignment and approval audit event commit atomically.
- Identity link uniqueness and request idempotency are enforced by database constraints, not only application checks.
- Account suspension and permission revocation are re-checked within sensitive database transactions.
- Audit records are append-only for the runtime API role; runtime credentials must not UPDATE or DELETE audit rows.
- No password, access token, refresh token, authorization code, MFA secret or service-role key is stored in METRA application tables.

## 5. Supabase schema and Data API boundary

- Place application tables in a dedicated non-exposed schema, proposed as `metra`.
- Do not put privileged application tables in `public` merely for convenience.
- Do not grant `anon` or `authenticated` direct table access to METRA accounts, role grants, station assignments, registration requests or audit records.
- Use a dedicated least-privilege PostgreSQL runtime role for the .NET API, separate from migration/schema-owner credentials.
- RLS is defense in depth for any table that is intentionally exposed or directly reachable; it does not replace API authorization.
- Do not modify Supabase-managed `auth`, `storage` or `realtime` internals.
- The 2026-10-30 Data API exposure change means new public tables are no longer automatically exposed by default. Do not treat default exposure settings as an authorization mechanism.

## 6. Operational and recovery requirements

- A failed METRA transaction after successful Auth sign-up must be safe to retry using the authenticated Auth UUID and a defined idempotency strategy.
- A duplicate Auth UUID already linked to another METRA account must be rejected without disclosing the other account.
- Revocation/unlinking requires recent re-authentication, an explicit server-side authorization rule and an immutable audit event.
- Auth-user deletion, compromise or recovery must be coordinated with METRA account suspension/revocation. Deleting an Auth user alone must not be assumed to invalidate every already-issued access token immediately.
- Sensitive operations may require session validation/revocation checks in addition to JWT validation, according to the final session policy.
- Keep PII and provider identifiers out of application logs unless a documented purpose requires them.

## 7. Implementation status

Existing .NET code includes:
- a generic identity-link application service and `IIdentityLinkStore` contract;
- an identity context resolved by a trusted server-side adapter contract;
- unit tests for malformed identity keys, freshness checks, account state and atomic store outcomes.

Not implemented:
- the Supabase JWT bearer validator and live issuer/JWKS configuration;
- the initial registration submission service;
- the PostgreSQL adapter for account links, registration requests, role grants, station assignments and audit;
- physical constraints, RLS, grants or migrations;
- Auth settings review and production signing-key verification.

The generic issuer+subject service must not be treated as the final Supabase account-link adapter without a reviewed implementation decision. No live database, Supabase Auth setting, RLS, schema, existing account record or secret has been changed.
