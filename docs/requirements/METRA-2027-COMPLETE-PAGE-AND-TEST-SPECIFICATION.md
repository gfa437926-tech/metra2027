# METRA 2027 — Complete page and test specification (controlled index)

**Document state:** Initial controlled index / specification baseline incomplete.  
**Audit baseline:** 2026-11-11, main commit `87f71356083843b2abdef76baf011a82510686be`.

This file is established because the requested path did not exist on the audited main branch. It does not claim to reproduce a previously approved complete specification.

## Page inventory currently evidenced

Angular routes are declared in `angular-app/src/app/app.routes.ts`:

- Login and registration.
- Dashboard.
- Phenomena input and phenomena.
- Hourly, rainfall, daily, climate, monthly and annual reports.
- Agriculture.
- Soil temperature.
- Users.
- Observation workflow.

Flutter pages evidenced in the repository:

- Home shell.
- Observation review.
- Station directory/map.
- API client and authentication infrastructure.

The inventory above is not an acceptance sign-off. Route declaration does not prove all fields, permissions, API integration, database persistence or parity.

## Test inventory

- .NET: `backend/Metra.Api.Tests/` — domain validators, workflow, authorization, request guards, registration, station and authority tests.
- Flutter: `mobile/metra_mobile/test/` — API client, observation review and widget tests.
- Database: `database/tests/` — SQL contract shell tests for authority, registration, station assignment, audit and directory contracts.
- CI: `.github/workflows/backend-ci.yml` and `client-ci.yml`.

## Required page specification template

For each page, complete all fields before marking it accepted:

1. Stable requirement ID and canonical Arabic label.
2. User roles and station/authority scope.
3. Entry route, navigation parent and responsive states.
4. Inputs: technical field name, Arabic label, unit, precision, range, requiredness, null/missing semantics and cross-field rules.
5. UTC timestamp and observation-period semantics.
6. API operation, request/response schema and error states.
7. Database table/RPC, constraints, audit and retention behavior.
8. Angular and Flutter implementation paths, or an explicit parity exclusion.
9. Positive, negative, authorization, boundary, regression and accessibility tests.
10. Acceptance evidence and responsible unit owner.

## Required missing acceptance suites

- End-to-end registration and two-stage approval.
- Full station-scoped permission matrix across every API operation.
- Daily/hourly scientific field validation and persistence.
- Rainfall, climate, agriculture, soil and phenomena full workflows.
- Report aggregation and export correctness.
- Paper register / mechanical recorder reconciliation.
- R/Climatol processing and reproducibility.
- Forecast-centre station comparison and live data freshness.
- UTC conformance across UI, API, DB, scheduled work and exports.
- Production deployment and authenticated smoke tests.

The authoritative status of each requirement is maintained in [the Requirements Traceability Matrix](TRACEABILITY-MATRIX.md).
