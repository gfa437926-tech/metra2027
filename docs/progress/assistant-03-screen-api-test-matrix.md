# Flutter screen / API / test coverage matrix — assistant 03

**Updated:** 2026-11-11T00:05:00Z  
**Branch:** `assistant-3/flutter-mobile-audit`  
**Scope:** Read-only contract inspection of `main`; Flutter tests added on the assistant branch. No Backend, Angular, Supabase, or database changes.

## Screen-to-API matrix

| Flutter screen / capability | Current implementation | API contract / endpoint | Authorization boundary | Tests observed | Assessment |
|---|---|---|---|---|---|
| App bootstrap and configuration | `main.dart`, `api_config.dart` initialize Supabase only when configured; app requires both Supabase and HTTPS API origin | Supabase Auth client; API origin supplied via `METRA_API_BASE_URL` | No service-role key in client; HTTPS enforced | API config tests reject HTTP, credentials, query, fragment and path | Present; live deployment configuration remains unavailable/unverified |
| Login/session | `MetraAuthGate`, `metra_auth.dart`; secure session storage | Supabase Auth session; API sends bearer access token | Backend derives actor from verified JWT `sub` | Widget test coverage in `widget_test.dart`; API client tests for missing token | Present; no Flutter authority/membership/permission administration UI |
| Home | `MetraHome` overview; clearly marks live weather as disconnected | None | No operational weather data displayed | Basic widget coverage | Informational only; no live weather source |
| Station directory | `StationDirectoryScreen`; type filters, map/list toggle, coordinates validation, station selection | `GET /api/v1/stations?limit=&offset=&stationType=` | Backend station catalogue endpoint; operational actions remain separately scoped | API parsing, filters, pagination, coordinate validity, 10,000/10,001 cap tests | Present; no station catalogue approval UI or detailed station profile |
| Observation review queue | `ObservationReviewScreen`; displays submitted queue and UTC timestamps | `GET /api/v1/stations/{stationId}/observations?limit=` | Backend permits station-scoped `observation.review`, `observation.approve`, or `observation.return_for_correction` | Queue parsing/auth/empty/error widget tests | Present |
| Return for correction | Dialog requires a reason; sends decision | `POST /api/v1/stations/{stationId}/observations/{observationId}/decision` with `return_for_correction` | Backend requires station-scoped `observation.return_for_correction`; database RPC remains final transition authority | Widget network failure test; API request and required-note tests added in this round | Present; UI displays action without locally filtering by effective permission |
| Approve observation | Confirmation dialog; sends approval | Same decision endpoint with `approve` | Backend requires station-scoped `observation.approve` | API request and conflict-status tests added in this round | Present; UI currently displays approval action to all users who can open this screen; backend must deny unauthorized attempts. Improve UX only after a trusted effective-permissions read contract is exposed |
| Create/submit observation | API client method exists; no screen/form wired in `MetraHome` | `POST /api/v1/stations/{stationId}/observations`; `submit=false` draft, `submit=true` submission | Backend `observation.create`; submission also requires `observation.submit` in database workflow | API UTC serialization test added; no end-to-end form test because no form exists | API client only; UI capability missing |
| Daily/hourly/phenomenon entry and editing | No data-entry screens or editor forms found in current Flutter tree | Submission endpoint supports three observation types; no edit endpoint in reviewed API contract | Observer ownership and station scope enforced server-side for permitted operations | Domain validator tests exist in Backend; no Flutter entry UI tests | Missing Flutter feature |
| Reports/analytics | Informational placeholder in home navigation | No connected reporting endpoint identified in reviewed client | Not applicable | No data-backed report tests found | Placeholder |
| Account settings/profile | Displays session email and sign-out only | Supabase Auth session | Session identity; no editable profile/role workflow | Basic widget tests | Partial; profile editing and membership/permissions UI missing |
| Maintenance, support, notifications | No corresponding Flutter feature folders/screens found | No corresponding client endpoint usage found | Not applicable | No Flutter tests found | Missing |
| Authority/membership/permission management | No Flutter feature found | Backend contract documents authority catalogue, membership, permission-grant, queue, decision and revocation routes | Authority-scoped permission checks and server/database enforcement | Backend tests exist; no Flutter integration | Missing Flutter capability |

## Authorization observations

- `role-permission-matrix.md` assigns `observation.review` and `observation.return_for_correction` to `station_head` and `station_auditor`; `observation.approve` belongs to `chief_auditor`. The UI currently renders both buttons without a client-side effective-permission model.
- This is a usability gap, not an authorization bypass: Backend queue and decision endpoints perform station-scoped permission checks and return forbidden when the actor lacks the required permission. Do not add role claims or permission assumptions in Flutter.
- The queue endpoint intentionally accepts any one of review/approve/return permissions, so a decision-only reviewer can retrieve the submitted queue.
- The station directory may include pending, unverified or demo entries. Selection is navigation only; it must not be treated as proof of operational authorization. Backend remains authoritative for every protected operation.

## Documentation inconsistency requiring owner follow-up

`docs/api/operational-observation-submission.md` currently says review, return, approval, list/detail endpoints and frontend integration remain follow-up work. However, on `main`:
- `ObservationQueueEndpoints.cs` maps the submitted queue GET route.
- `ObservationSubmissionEndpoints.cs` also defines and maps the decision POST route.
- `Program.cs` calls both `MapObservationDecisionEndpoints()` and `MapObservationQueueEndpoints()`.
- Flutter has the queue screen and decision client/UI.

The API document should be reconciled by its owner; assistant 03 does not edit Backend or shared API contract documentation.

## Tests added in this round

- Verify decision POST route, bearer token and request body.
- Verify return-for-correction rejects a whitespace-only note before network access.
- Verify HTTP 409 is preserved for the review UI.
- Verify observation submission serializes an offset timestamp to UTC.

## Remaining Flutter work

1. Build a trusted effective-permission capability contract before hiding or showing approve/return controls by role.
2. Implement hourly/daily/phenomenon entry forms from approved field specifications; do not invent fields or station data.
3. Implement draft listing/editing only after a documented API contract exists.
4. Add station details and catalogue review only against approved contracts.
5. Add profile, authority access, maintenance, support, notification and data-backed reporting screens where contracts are defined.
6. Complete RTL/accessibility/responsive checks and end-to-end coverage.

**Current completion estimate remains 10%** under the existing ten-domain audit rubric; this matrix is evidence gathering, not completion of the missing product areas.


## Field-specification audit (M7)

The backend validators were inspected as read-only evidence; they are not treated as a complete mobile form specification.

- **Hourly:** `HourlyObservationValidator` defines field codes, formats, ranges, and conditional required fields. Precipitation is required at UTC hours 00/06/12/18; synoptic fields are required at 00/03/06/09/12/15/18/21. The validator does not define a complete mobile presentation contract (field grouping/order, reference option lists, display units, or interaction behavior).
- **Daily:** `DailyObservationValidator` defines validation for known legacy field codes, but required fields are supplied externally through `requiredFields`. The inspected API documentation does not define how a report type selects that set.
- **Submission API:** the generic `payload` object is capped by the API contract but has no detailed hourly/daily JSON schema in the inspected documentation.
- **Decision:** do not build speculative forms or reuse old-database station data. Request an approved UI/payload specification covering required/optional fields, labels, units, reference values, and UTC behavior before implementation.
- No Backend, Angular, Supabase, or database files were modified.


## Accessibility improvement (M8)

- Password visibility IconButton now exposes a localized dynamic tooltip/semantics label: `إظهار كلمة المرور` while obscured and `إخفاء كلمة المرور` while visible.
- Added a widget test asserting both tooltip states and the corresponding `TextFormField.obscureText` value before/after each toggle.
- Scope limited to Flutter authentication UI and its widget test.
- Local Flutter test execution was not performed in this round; CI is the verification source of truth.
