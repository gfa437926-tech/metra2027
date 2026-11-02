# METRA 2027 — Clean Architecture

## Purpose
Rebuild METRA 2027 as a maintainable operational system while preserving the original application's verified workflows, meteorological rules, terminology, and user experience. The legacy source is a behavioral reference, not a code template.

## Applications and responsibilities

| Application | Responsibility | Must not do |
|---|---|---|
| Angular web | Web UI, navigation, client-side presentation and input assistance | Decide authorization, connect directly to PostgreSQL, or own business rules |
| Flutter mobile | Mobile UI and offline-friendly interaction where explicitly designed | Implement a second, divergent set of business rules |
| ASP.NET Core API | Authentication integration, authorization, business workflows, validation, persistence orchestration, audit | Trust client-supplied roles, station assignments, approval state, or actor identity |
| PostgreSQL | Durable records, constraints, relationships and transactional integrity | Contain duplicated business logic that conflicts with API rules |

Both clients use the same versioned API. No client connects directly to the database.

## Backend organization

The backend will be organized by business capability, with dependencies pointing inward:

- Domain/: entities, value objects, enumerations and domain invariants. No HTTP, database SDK or UI dependencies.
- Application/: use cases, commands/queries, validation contracts and authorization requirements.
- Infrastructure/: PostgreSQL repositories, identity-provider adapters, audit persistence and external integrations.
- Api/: endpoint mapping, request/response contracts, authentication middleware and dependency composition.
- Tests/: domain, application, API integration and authorization tests.

Feature capabilities are separated into Identity, Stations, Observations, Reports, Approvals, Administration and Audit. Shared code is limited to genuinely cross-cutting concerns; feature-specific rules remain with their feature.

## Frontend organization

Angular and Flutter are organized by feature rather than by duplicated page scripts:

- core/: API client, identity/session integration, route guards based on server-issued identity state, error handling and app-wide configuration.
- shared/: reusable visual components and presentation-only utilities.
- features/identity/: sign-in, registration request, account recovery and approval status screens.
- features/stations/: station selection and assignment views.
- features/observations/: daily, hourly, climate, agricultural and soil-temperature workflows.
- features/review/: validation feedback, correction requests and approvals.
- features/reports/: search, statistics, printing and export.
- features/admin/: users, roles, permissions and station management.

A shared sidebar and design tokens are defined once in the shell. Feature pages must not create their own competing navigation.

## Non-negotiable engineering rules

1. One authoritative implementation for each business rule.
2. Client validation is for usability; the API repeats all authoritative validation.
3. Authorization is enforced by the API for every protected operation.
4. A role alone never grants station access: the effective station assignment and its validity are checked.
5. Account identity is separate from work assignment.
6. Passwords are never stored by METRA. Use the approved OIDC identity provider; MFA and session revocation belong to the identity layer.
7. Audit records capture actor, action, target, timestamp and relevant change context.
8. Report submission and approval transitions are transactional and state-checked on the server.
9. No silent fallback to local storage for authoritative records or permissions.
10. Preserve the original visual behavior while replacing unsafe or duplicated implementation details.
11. Apply the mandatory cybersecurity and cryptography baseline in `SECURITY-CRYPTOGRAPHY-BASELINE.md`; security controls are release gates, not optional hardening.
12. Require TLS, managed secrets and key lifecycle, encryption at rest for databases/files/backups/logs, least-privilege access, MFA for privileged users, secure sessions, abuse protection, tamper-resistant audit, security scanning and independent penetration testing before production.
13. Never claim the platform is fully secure or certified without independent evidence and an explicit scope.

## Refactoring method

For each legacy workflow:
1. Inventory the screen, inputs, outputs, field formats, validation rules, status transitions, permissions and persistence behavior.
2. Record ambiguities and conflicting legacy implementations; do not silently choose one.
3. Define one domain/application contract and its test cases.
4. Implement and test the API behavior.
5. Connect Angular and Flutter to that same API contract.
6. Reproduce the reference UI and compare it against the original.
7. Mark the legacy workflow as migrated only after functional and regression tests pass.

## Delivery sequence

- Stage 0 — repository audit and workflow specification.
- Stage 1 — identity, registration requests, account states, station assignments and authorization.
- Stage 2 — shared observation primitives, validation and daily/hourly entry.
- Stage 3 — climate, rainfall, agricultural and soil-temperature records.
- Stage 4 — review, correction, approval, audit and archival.
- Stage 5 — search, statistics, reports, printing and exports.
- Stage 6 — station/user administration and Flutter parity.
- Stage 7 — security architecture, threat modelling, cryptography/key management, secure operations and independent security verification; production release is blocked until the mandatory security gates pass.

## Database and deployment guardrails

The selected Supabase PostgreSQL target and its read-only baseline are recorded in `SUPABASE-TARGET-PROJECT.md`. The project has no application tables in `public` at inspection time. Supabase Auth is now the recommended provider selected for implementation planning; its Auth settings and signing-key configuration still require read-only review. Neither this selection nor the database target approves schema changes or legacy-data migration. Until the schema, identity mapping, least-privilege roles and migration plan are approved, do not create tables, alter RLS, change policies, or migrate legacy data. The existing GitHub Pages deployment serves only the Angular frontend; it does not host the API or database.

Security baseline: `SECURITY-CRYPTOGRAPHY-BASELINE.md` is mandatory for all new work. Authentication and session requirements are specified in `AUTHENTICATION-SESSION-SECURITY-DESIGN.md`; Supabase Auth is selected for implementation planning, while production activation remains blocked pending issuer/JWKS/signing-key verification and operational approval. The current repository is not yet production-secure; no production security certification or completed encryption configuration is claimed.
Effective permission and exact station-scope evaluation rules are specified in `ROLE-PERMISSION-STATION-ACCESS-CONTRACT.md`; the provider-independent domain evaluator and unit tests exist, but role mappings and persistence remain unapproved.
Identity linking and storage invariants are specified in `IDENTITY-LINK-PERSISTENCE-CONTRACT.md`. It is a proposed contract only; no database migration or identity-link persistence adapter is enabled.

The repository inspection and decision not to introduce a speculative database adapter or migration are recorded in `IDENTITY-PERSISTENCE-IMPLEMENTATION-DECISION.md`. The Supabase Auth + ASP.NET Core logical data model and its remaining decisions are documented in `CANONICAL-DATA-MODEL-PROPOSAL.md`; it is a review proposal, not an approved physical schema.


The legacy Supabase project `INSERT` has been inspected read-only and remains separate from the new target. Its schema, classic/automatic station counts, scientific record counts, and security-advisor findings are documented in `LEGACY-SUPABASE-READ-ONLY-REVIEW.md`. No legacy or target database objects were changed.

Supabase bearer-token validation configuration and its asymmetric-signing prerequisite are specified in `SUPABASE-JWT-AUTHENTICATION-CONFIGURATION.md`. The initial-registration actor context is now derived only from the authenticated JWT `sub` claim and accepts only a non-empty UUID; its provider is registered in the API composition root, but registration HTTP mapping and persistence/catalogue adapters remain disabled. The API now supports configuration-driven JWT bearer validation; without provider settings in Development it remains fail-closed, and production startup requires explicit issuer and audience settings. Production token validation still requires runtime verification against the selected Supabase Auth project.

Registration submission HTTP semantics and security requirements are specified in `REGISTRATION-SUBMISSION-API-CONTRACT.md`. The required single-transaction PostgreSQL behavior, idempotency/concurrency rules, rollback guarantees and integration-test gates are specified in `REGISTRATION-ATOMIC-PERSISTENCE-DESIGN.md`; this is a design contract only and does not authorize schema or database changes. The application service exists, the JWT `sub` actor provider is registered, and a fail-closed configuration-backed catalogue adapter is registered. The atomic store and authoritative active-catalogue integration remain pending; the HTTP endpoint is deliberately unmapped until all release gates pass.


The provider-independent role/permission catalogue structure and validation rules are specified in `AUTHORIZATION-CATALOGUE-CONTRACT.md`. A pure validator and unit tests now reject malformed/duplicate definitions and dangling or duplicate mappings. No concrete METRA role codes, permission codes, role mappings, seed data, or database objects have been selected or created.

## Authorization governance additions

- `AUTHORIZATION-CATALOGUE-CONTRACT.md` — provider-independent role/permission catalogue structure and structural validation, without preselecting METRA role codes or mappings.
- `ACCOUNT-LIFECYCLE-AND-ACCESS-MUTATION-CONTRACT.md` — explicit account lifecycle transitions, station assignment and permission grant/revoke application contracts, effective-access consequences, concurrency checks, and transactional audit requirements.
