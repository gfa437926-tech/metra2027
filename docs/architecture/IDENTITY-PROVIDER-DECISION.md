# METRA 2027 — Identity Provider Decision Record

Status: recommended provider selected for implementation planning; production activation gated on a read-only Auth configuration review.

## Decision

Recommend Supabase Auth in the existing Supabase project metra2027-angular as the credential and identity provider, with ASP.NET Core 10 as the sole METRA application authority.

Project reference: tbdnklyxjvbrilvnwgmq
Project URL: https://tbdnklyxjvbrilvnwgmq.supabase.co

This recommendation does not authorize a Supabase Auth setting change, a JWT signing-key rotation, a schema migration, or a production credential rollout.

## Why this is the preferred option

- The selected METRA project already has the managed Supabase Auth subsystem (auth.users, auth.identities, auth.sessions, MFA and recovery-related system relations).
- Angular and Flutter can use the same identity provider while the ASP.NET Core API independently validates bearer access tokens.
- Credential storage, email verification, MFA and recovery remain in a managed identity subsystem instead of being reimplemented in METRA tables.
- It avoids introducing a second identity database/provider before there is a demonstrated requirement for enterprise federation or organization-wide SSO.
- It keeps METRA-specific account state, approvals, station assignments, roles and permissions in the application domain rather than conflating them with provider identity claims.

## Observed project state (read-only inspection)

- Project status: ACTIVE_HEALTHY.
- PostgreSQL: 17.11.
- The public schema currently contains no application tables.
- The Supabase migration listing currently returns no application migrations.
- The managed Auth schema exists; the Auth users table currently reports zero rows.
- Security and performance advisors returned no lint notices in this inspection.

This means the current project is an empty application-data target, not evidence that the Auth provider has already been configured for METRA. No production identity endpoint is enabled by this decision.

## Required security configuration before enabling .NET JWT authentication

1. Inspect Authentication settings, enabled providers, email/phone confirmation requirements, redirect allow-list, password policy, MFA policy, session lifetime and rate limits.
2. Inspect the current JWT signing-key state without exposing private key material.
3. Prefer an asymmetric signing key, ideally ES256 (RS256 is acceptable where compatibility requires it). Do not make a new .NET API depend on the legacy HS256 shared JWT secret.
4. Confirm the project's JWKS endpoint returns the active public signing key(s): /auth/v1/.well-known/jwks.json.
5. Verify the exact issuer emitted in a non-production test access token. Expected issuer form: https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1.
6. Validate the access-token audience (normally authenticated), signature, issuer, audience, expiry, not-before and permitted signing algorithm. Do not accept ID tokens as API bearer access tokens.
7. Test key rotation and cache refresh behavior before production; the JWKS endpoint is cached by Supabase edge infrastructure.
8. Never place a Supabase secret/service-role key in Angular or Flutter. Do not use editable user metadata for authorization.

If asymmetric signing is not currently configured, stop and present a separate change plan for approval; do not rotate keys automatically.

## ASP.NET Core responsibility boundary

- Use the standard ASP.NET Core JWT bearer authentication handler with issuer-bound signing-key discovery from the project's JWKS endpoint, once its exact runtime behavior is verified.
- Read only immutable provider identity coordinates from the validated principal. The provider sub is a provider subject, not a METRA account ID.
- Resolve (issuer, subject) to the METRA account using authoritative persistence.
- Do not trust email as the identity-link key and do not use provider user metadata or client-supplied role/station claims for authorization.
- Initial registration is a separate operation: after Supabase Auth sign-up, the API creates the pending METRA account, Auth-user link, request and audit event atomically. The generic active-account identity-link service is not used for initial onboarding.
- Keep account lifecycle, station approvals, system approvals, role grants, station assignments and permission checks in ASP.NET Core.
- Deny protected application operations for pending, rejected, suspended, unlinked or unknown accounts.
- Re-check current permissions and station scope for every protected request.

## Approved registration workflow

1. User submits a registration request and completes the configured identity verification.
2. A station manager with the explicit station-approval permission and an active assignment for the requested station decides first.
3. A system manager with the explicit system-approval permission decides second.
4. Only after both approvals does the application activate the METRA account and create the approved role grant and station assignment in one database transaction.

The applicant cannot decide their own request. A request cannot skip either stage. A requested role or station is never an effective grant.

## Current implementation boundary

The API currently has an intentionally unconfigured authentication handler that returns no authenticated identity, plus fail-closed permission and resource evaluators. Keep that boundary until the Auth settings and signing algorithm have been inspected and the persistence model has been reviewed and approved.

The provider-independent .NET approval state machine and application-service contract already exist separately from persistence. The station approval policy now requires an explicit station-approval permission in addition to station scope. No production store adapter, identity token validator, database schema, or RLS changes are part of this decision.
