# METRA 2027 — Requirements Traceability Matrix

- Audit baseline: `main` at `87f71356083843b2abdef76baf011a82510686be`
- Audit date: 2026-11-11
- Scope: repository evidence only; no runtime or production verification was performed in this documentation pass.
- Status vocabulary: **Tested evidence** = implementation and relevant test evidence located; **Partial evidence** = code/docs/tests exist but end-to-end completion is not established; **Documented only** = requirement is described without adequate implementation proof; **Gap / unverified** = no implementation proof located in this audit.
- A route, file, migration, or test name is evidence of presence, not proof of production readiness.

## Traceability

| ID | Requirement / capability | Angular evidence | Flutter evidence | API evidence | Data evidence | Test evidence | Audit status / gap |
|---|---|---|---|---|---|---|---|
| REQ-001 | Authenticated access and session | `angular-app/src/app/features/auth/login.component.ts`; auth guard | `lib/core/auth/metra_auth.dart` | JWT bearer setup in `Program.cs` | Supabase Auth integration described | `ApiAuthenticationTests.cs` | Partial; production identity lifecycle and MFA/E2E not certified |
| REQ-002 | Registration request and approval | registration and registration-review components | No matching workflow located | registration submission/review endpoint services registered | migration/contracts referenced in security docs | registration request/decision guard tests | Partial; Flutter parity not shown |
| REQ-003 | Station-scoped authorization | guard is client navigation protection only | review screen consumes API | station permission policy and Supabase authorization services | permission RPCs / role allow-list docs | station authorization tests | Partial; verify each endpoint and live DB policy together |
| REQ-004 | Station directory/catalogue | no complete route-specific proof from route list | `station_directory_screen.dart` | station directory endpoints registered | catalogue referenced by migrations | station catalogue request guard tests | Partial; Angular parity and verified coordinates remain open |
| REQ-005 | Observation submission (daily/hourly/phenomenon) | daily/hourly report routes; workflow component | API client and observation screens | `POST /api/v1/stations/{stationId}/observations` | `metra_observations`, submission RPC | submission request guard and domain validators | Partial; full field parity and live E2E not proven |
| REQ-006 | Observation review queue | workflow route | `observation_review_screen.dart` | queue endpoint registered | operational observation tables | queue request guard tests | Partial; client parity and production test not certified |
| REQ-007 | Approve / return for correction | workflow route exists | review screen includes decision workflow per README | decision service registered | decision migrations / audit events | decision guard and workflow tests | Partial; inspect exact endpoint/transaction tests and E2E |
| REQ-008 | Daily reports | `reports/daily` | no corresponding page located | API submission exists; report query API not established | schema coverage not fully established | daily validator tests | Partial / reporting query gap |
| REQ-009 | Hourly reports | `reports/hourly` | no corresponding page located | submission path exists | schema coverage not fully established | hourly validator tests | Partial / reporting query gap |
| REQ-010 | Rainfall reports | `reports/rainfall` | no corresponding page located | no dedicated API evidence in inspected route map | not established | no dedicated test evidence located | Gap / unverified |
| REQ-011 | Climate reports and monthly/annual views | climate, monthly, annual routes | no corresponding pages located | no dedicated API evidence located | not established | no dedicated calculation tests located | Partial UI; calculation/API/data evidence gap |
| REQ-012 | Weather phenomena | phenomena and phenomena/input routes | no corresponding page located | validator exists; full operational API not established | schema proposal exists | phenomenon validator tests | Partial |
| REQ-013 | Agricultural reports | agriculture route | no corresponding page located | no dedicated API evidence located | not established | no dedicated tests located | Partial UI; backend/data/test gap |
| REQ-014 | Soil temperature | soil-temperature route | no corresponding page located | no dedicated API evidence located | not established | no dedicated tests located | Partial UI; backend/data/test gap |
| REQ-015 | Station user/authority administration | users route and authority/registration components | no equivalent admin UI located | authority access, assignment, directory and audit services registered | permission and audit migrations/docs | authority/assignment/audit tests | Partial; end-to-end role matrix verification required |
| REQ-016 | Paper-register / mechanical-recorder audit | no route located | no page located | no dedicated API located | no dedicated schema located | no dedicated tests located | Gap / unverified |
| REQ-017 | Climate homogeneity / R + Climatol | no route located | no page located | no R service/job evidence located | no data pipeline evidence located | no R test evidence located | Gap / unverified |
| REQ-018 | Forecast-centre comparison and live station values | no route located | no page located | no dedicated live feed/comparison API located | not established | no dedicated tests located | Gap / unverified |
| REQ-019 | UTC-only timestamps | report forms reference UTC; verify all forms individually | timestamps passed through API client; verify serialization | `DateTimeOffset`, ISO-8601 UTC contract in observation API | PostgreSQL `timestamptz` | no complete UTC contract test matrix located | Policy decision; implementation-wide proof outstanding |
| REQ-020 | Immutable audit and attributable decisions | UI evidence partial | review UI | actor from validated JWT `sub` | append-only observation audit table and trigger | workflow / decision tests | Partial; audit coverage across all modules not certified |
| REQ-021 | Secure production deployment | runtime config documented | HTTPS API config documented | health/readiness and server-only service credential | new Supabase target documented | CI workflows exist | Partial; README reports Pages deployment blocked by missing API URL secret |
| REQ-022 | Complete Angular/Flutter feature parity | multiple routes present | observation review + station directory only | shared API architecture documented | common persistence | Flutter tests exist | Gap / partial; feature parity matrix needed |

## Evidence inventory (selected)

- Angular route map: `angular-app/src/app/app.routes.ts`.
- Angular API adapters: `angular-app/src/app/core/api/`.
- Flutter client: `mobile/metra_mobile/lib/core/api/metra_api_client.dart`; auth: `lib/core/auth/metra_auth.dart`.
- ASP.NET composition root: `backend/Metra.Api/Program.cs`.
- Backend tests: `backend/Metra.Api.Tests/`.
- Database contract checks: `database/tests/`.
- Supabase migrations: `supabase/migrations/`.
- CI: `.github/workflows/backend-ci.yml`, `client-ci.yml`, `deploy-pages.yml`, `publish-api-container.yml`.

## Required next evidence

1. Run and retain current CI results from this branch/head; this audit did not execute builds or tests.
2. Map each user-approved page requirement to route, component, API operation, schema/migration, and named test.
3. Add API integration tests for each permission boundary and status transition.
4. Add Flutter feature-parity decisions: implemented, intentionally excluded, or scheduled.
5. Verify all date/time inputs, serialization, DB writes, report queries, and exports under UTC-only semantics.
6. Obtain product-owner decisions for unresolved paper audit, Climatol, forecast-centre, data catalogue, and full report calculation requirements.
7. Record production smoke-test evidence separately from CI evidence.


## Cross-assistant branch evidence

The current `main` matrix above records baseline evidence only. Do not silently replace its statuses with work from unmerged branches. See [ASSISTANT-PR-EVIDENCE-REGISTER.md](ASSISTANT-PR-EVIDENCE-REGISTER.md) for a PR-by-PR ledger, exact branch heads, changed-file scope, selected Actions run SHAs, and acceptance limitations.

Key interpretation rules:
- A PR description is an owner-reported claim, not independent implementation proof.
- Successful CI on an ancestor SHA does not certify tests or changes added later on the branch.
- Flutter UTC work (#21), API UTC enforcement (#22), R/Climatol hardening (#23), client CI changes (#27), and security hardening (#30) remain branch proposals until latest-head validation and review.
- The scientific review PR (#25) reports possible operational validation and humidity-range consistency gaps; these require direct source/test reproduction before being classified as confirmed defects.
- Database proposal PR (#26) is not authorization to apply SQL or migrations.
- PR #24's QA matrix is an audit artifact; it is not a substitute for executing tests.
