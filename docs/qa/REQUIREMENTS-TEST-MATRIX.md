# METRA 2027 — QA Requirements-to-Tests Matrix

Audit baseline: main as inspected on 2026-11-11. Repository inventory only; tests were not executed in this session.

| Requirement / area | Existing automated coverage found | Status | Required next test work |
|---|---|---|---|
| Angular build | Client CI runs npm run build | Build-only | Add Angular unit/component tests; cover guards, API services, forms, validation and errors |
| Angular ↔ API contracts | No Angular test script or test files found under angular-app/src | Gap | Contract tests for DTOs, auth headers, status mapping and UTC serialization |
| Flutter API client | metra_api_client_test.dart | Partial | Expand success, malformed JSON, timeout, non-2xx, auth expiry, station denial and UTC round-trip |
| Flutter widgets | observation_review_screen_test.dart, widget_test.dart | Partial | Add responsive, RTL/Arabic semantics, keyboard/focus, accessibility and form error tests |
| .NET domain validation | Daily/hourly/phenomenon validators, request guards and workflow tests | Existing, breadth unverified | Add boundary/property cases against approved field rules |
| .NET auth and station authorization | ApiAuthenticationTests.cs, SupabaseStationAuthorizationServiceTests.cs, authorization policy tests | Partial | Test-server integration for cross-station denial, inactive/unassigned users, expired grants, self-review and role boundaries |
| .NET API endpoints | Request-guard tests for observation, station review, registration and assignment | Partial | WebApplicationFactory endpoint tests with fake services and exact status/ProblemDetails assertions |
| SQL authorization/workflows | 12 shell checks in database/tests, invoked by backend CI | Contract-level | Add PostgreSQL integration tests for transactionality, concurrency, RLS and append-only audit |
| UTC-only timestamps | API contract example uses ISO-8601 Z; no dedicated UTC suite identified | Gap | Assert UTC wire values across clients/API; test offset/local-time policy and round-trip |
| R / Climatol | No R project, R tests, or Climatol harness found in inspected paths | Not present | Establish R/testthat fixtures once the module is committed |
| RTL/accessibility/responsive | No automated browser/E2E or accessibility runner found | Gap | Add Playwright (or approved runner), axe, RTL snapshots and viewport matrix |
| Full end-to-end | No E2E workflow or test directory found in inspected structure | Gap | Add client + API E2E for sign-in, station-scoped submit, review and denial |

## Inventory counts
- .NET test project: 20 C# test source files across Domain, Features and Security.
- Flutter: 3 test files.
- SQL: 12 shell contract checks under database/tests.
- Angular: package scripts expose start, build and watch; no test script or test dependencies are declared.
- R: no project/test files identified in the inspected repository directories.

## Evidence and limitations
- CI definitions: .github/workflows/client-ci.yml and .github/workflows/backend-ci.yml.
- README reports historical successful CI runs dated 2026-11-04; those are not executions of this audit branch.
- Requested coordination/specification files were not found on main: واجهات/مهما.md, واجهات/تغيير.md, واجهات/README.md, docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md.
- This matrix records test-file presence, not adequacy or passing status. A test source file is not proof that its cases pass.

## QA-07 update — Observation review queue

| Requirement / area | New evidence on PR #22 | Status after static review | Remaining required work |
|---|---|---|---|
| Observation queue endpoint status handling | `ObservationQueueEndpointTests.cs`: six WebApplicationFactory tests for unauthenticated 401, invalid limit 400, denied scope 403/no queue call, fake station-A grant vs station-B request, dependency-unconfigured 503 and read-failure 503 | Endpoint test source now exists; execution for latest PR head was still in progress, so no pass claim | Confirm CI on exact latest SHA; add real DB integration for station grants, revocation-before-read, concurrent read/revocation and atomic auth+read |
| Review queue authorization atomicity | Endpoint still makes permission RPC then a separate service-role PostgREST SELECT without actor ID in the read | P1 TOCTOU remains open | Owner/schema-reviewed atomic actor+station-scoped queue read and race/linearization tests |

The fake Station A/Station B endpoint test verifies endpoint wiring to the authorization abstraction; it is not proof of real database station isolation. QA-06 did not execute tests locally.
