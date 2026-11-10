# METRA 2027 — QA Audit Report

**Audit date:** 2026-11-11  
**Base:** main  
**Branch:** qa/metra-2027-test-coverage-audit  
**Scope:** test inventory, CI wiring, coverage gaps and integration-risk triage. No application logic or database schema was changed.

## Executive result

The repository has a meaningful backend test foundation and basic Flutter tests, but it does not yet have a complete cross-client quality gate. Angular currently has build verification only; no R/Climatol test project or browser E2E/accessibility suite was found. UTC-only behavior is described in API examples but is not evidenced by a dedicated cross-layer test suite.

**Execution status:** no local test command was executed. The available GitHub integration can inspect repository contents and CI definitions but does not provide a shell runner for npm, flutter, dotnet, PostgreSQL or R in this session. No test is marked passed or failed. Historical CI outcomes in README are historical and are not a run of this branch.

## Findings and priorities

### P0 — release-blocking verification gaps
1. **No real identity / authority / cross-station integration proof.** Security documentation itself says real-user, cross-authority, self-approval and concurrency tests remain outstanding. Existing unit tests do not establish live authorization enforcement across API + database.
2. **No authenticated end-to-end workflow.** No E2E runner/workflow was found. Login, station-scoped observation submission, review, approval/rejection and forbidden cross-station access are not proven end to end.
3. **UTC-only invariant lacks dedicated tests.** API contract documentation uses ISO-8601 UTC (Z), but no identified test suite proves the invariant through Angular, Flutter, API and persistence.
4. **R/Climatol test scope is absent.** No R module/test project was found; QA cannot certify it until implementation is present.

### P1 — important coverage gaps
5. **Angular has no test target.** angular-app/package.json defines build/start/watch only; CI runs production build only. No unit/component test command or test dependencies are declared.
6. **Flutter coverage is narrow.** Three test files exist and CI runs analyze + test, but explicit RTL, responsive viewport, semantics/accessibility, validation/error-state and cross-station authorization cases were not identified from the inventory.
7. **Backend endpoint integration depth is unclear.** The test project has domain/request-guard/security tests; add test-server integration tests for actual routes, middleware, JWT claims, ProblemDetails and status-code contracts.
8. **SQL tests are contract scripts, not full database integration tests.** Twelve shell checks run in backend CI, but a live PostgreSQL test layer is needed for RLS, concurrent decisions, rollback and audit immutability.

### P2 — CI reliability / maintainability
9. **Backend workflow path filter omits the active migration directory.** It watches database/migrations/**, while current migrations are under supabase/migrations/**. A migration-only change may not trigger this workflow.
10. **Backend CI path filters omit API contract documentation.** Consider adding docs/api/** and relevant QA contract changes to workflow filters.
11. **Coverage reporting is not configured.** Add machine-readable coverage output and thresholds after missing test layers are established.

## Existing inventory
- .NET: 20 C# test files in Domain, Features and Security.
- Flutter: 3 test files.
- SQL: 12 shell contract scripts under database/tests.
- Angular: no test script/test dependencies found; build only.
- R: no project or test files found in inspected repository directories.
- E2E/accessibility: no runner or workflow found.

See REQUIREMENTS-TEST-MATRIX.md for per-area traceability.

## Repository artifacts not found
The following requested files were absent from main at the requested paths:
- واجهات/مهما.md
- واجهات/تغيير.md
- واجهات/README.md
- docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md

They were not recreated or overwritten. Creating replacement logs without their prior entries would violate the requirement to append cumulatively and preserve history. QA findings are recorded under docs/qa/ instead.

## Recommended next execution sequence
1. Run existing CI commands on this branch in GitHub Actions and attach run URLs/results.
2. Add Angular unit/component tests and Flutter RTL/responsive/accessibility tests.
3. Add .NET test-server integration cases for JWT, exact station scope and documented error responses.
4. Add cross-layer UTC serialization/validation tests.
5. Add PostgreSQL integration tests for RLS, transactional workflow, concurrency and audit immutability.
6. Add R testthat fixtures and deterministic Climatol regression fixtures when the R module exists.
7. Add Playwright E2E + axe checks as release gates.

## Change boundary
This QA branch changes documentation only. It does not alter Angular, Flutter, .NET, R implementation, SQL migrations, database configuration or database data. No PR is merged.