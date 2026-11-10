# METRA 2027 — Parallel assistant ownership and integration boundaries

This document defines work boundaries for parallel contributors. It does not grant permission to alter another unit's code or database.

| Assistant | Primary ownership | Allowed documentation/integration work | Must coordinate before |
|---|---|---|---|
| 1 | Angular web client | Angular route/component/API evidence and UI acceptance criteria | Shared contracts, navigation shell, shared DTO changes |
| 2 | ASP.NET Core backend and API | Endpoint contracts, validation, authorization, service and API tests | Database RPC/schema changes; client contract changes |
| 3 | Flutter mobile client | Flutter screens, API client, mobile tests and parity status | Shared API contracts, auth/token changes |
| 4 | Climate homogeneity and R/Climatol | Scientific processing specification, R scripts, reproducibility tests | Data model, quality flags, batch/API integration |
| 5 | Paper-register and mechanical-recorder audit | OCR/manual verification workflow, evidence model, discrepancy lifecycle | Observation schema, file storage, review permissions |
| 6 | QA and testing | Test strategy, acceptance tests, cross-client integration and evidence reports | Changes to test fixtures/contracts or CI gates |
| 7 | Security | Threat model, authn/authz review, secrets, audit and security tests | Permission model, identity provider, RLS/policies |
| 8 | Database engineering | Schema design, migrations, constraints, indexes and SQL contract tests | Any migration execution or production schema changes |
| 9 | DevOps and infrastructure | CI/CD, containers, hosting, observability and release automation | Secrets, production environments, deployment and branch protection |
| 10 | Requirements, documentation and architecture records | Requirements catalogue, traceability, terminology, decision records, status evidence | Any change to another unit's implementation or any requirement interpretation affecting scope |

## Shared rules

- Each assistant works only in its assigned unit unless the owner explicitly authorizes a cross-unit change.
- No assistant merges directly to `main`; use an isolated branch and reviewed PR.
- Do not modify the legacy database. Do not execute migrations against any environment as part of documentation work.
- Schema proposals require review and explicit approval before application.
- The API is the sole privileged database boundary; Angular and Flutter are API clients.
- No assistant may declare a capability complete from a document, screenshot, route declaration, or successful compilation alone.
- Cross-unit changes require a short contract proposal, affected requirement IDs, migration/test impact and approval from the relevant owners.
- Assistant 10 owns traceability and terminology records, not implementation acceptance. A unit owner supplies implementation evidence; QA supplies test evidence; release owner supplies production evidence.

## Handoff format

Every unit reports: requirement IDs, changed paths, branch/PR, API contract changes, schema/migration impact (proposal only unless approved), tests run with exact result links, known gaps, and decisions needed.
