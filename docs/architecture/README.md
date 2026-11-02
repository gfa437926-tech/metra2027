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

The new Supabase project is not yet approved for schema changes. Until a schema and migration plan are explicitly approved, do not create tables, alter RLS, change policies, or migrate legacy data. The existing GitHub Pages deployment serves only the Angular frontend; it does not host the API or database.

Security baseline: `SECURITY-CRYPTOGRAPHY-BASELINE.md` is mandatory for all new work. The current repository is not yet production-secure; no production security certification or completed encryption configuration is claimed.