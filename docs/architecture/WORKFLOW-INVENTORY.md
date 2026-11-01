# METRA 2027 — Initial Workflow Inventory

Status: preliminary source inspection. This inventory identifies screens and observable controls; it does not claim that every workflow or business rule has been fully reverse-engineered.

## Identity and account lifecycle

Reference: index.html and login.js.

Observed user-facing flows:
- Sign in with email and password.
- Remember-me option.
- Registration request with first name, father's name, family name, station, work role, email, phone, password and confirmation.
- Program/registration password field in the legacy UI. Its authorization semantics must be determined from the full workflow and replaced with a server-controlled invitation/approval policy; never reproduce a hard-coded shared password.
- Terms acceptance.
- Password recovery using email and phone fields.
- Separate alert/loading states for login, registration and recovery.
- The legacy code references separate authentication/session scripts; their overlapping storage behavior must not be carried forward.

Target behavior:
- OIDC sign-in with MFA provided by the selected identity provider.
- Registration creates a pending request, not an active privileged account.
- Approval is a server-side workflow with explicit actor, station and timestamp.
- Password recovery is delegated to the identity provider.
- User profile, account state, role grants and station assignments are distinct concepts.

## Daily observations and reports

Reference: daily_reports.html, daily_main.js, daily_db.js, daily_validation.js and related helpers.

Observed read/report screen controls:
- Station, month and year filters.
- Load, clear-filter and refresh-station actions.
- Summary statistics for days, reports, completion and period.
- Report table and Excel/print actions.

Observed daily entry implementation concerns:
- Form formatting and validation are split across daily_main.js and daily_validation.js, with additional overlapping enhanced-validation.js helpers.
- Database payload construction and submission live separately in daily_db.js.
- User/station attribution is read from browser storage in the legacy code.
- Field-level rules, requiredness, missing markers and all payload mappings still require systematic extraction before implementing the new API.

## Hourly observations

Reference: hourly_reports.html, hourly-send.js, submit-hourly.js and enhanced-validation.js.

Observed form structure includes:
- Reporting date/time and UTC selection.
- Dry-bulb and wet-bulb temperature, with a relationship check.
- Station and sea-level pressure, pressure tendency and pressure characteristic.
- Relative humidity, vapour pressure, dew point and vapour-pressure difference.
- Wind direction/speed and average wind direction/speed.
- Additional fields continue through the original form and must be inventoried before declaring parity.

Observed behavior:
- Inline field-level error/success states.
- Time-dependent fields driven by UTC selection.
- Form validation and submission logic are spread across multiple scripts.
- Submission has a local backup/sync path in the legacy code; the replacement offline strategy must be explicitly designed rather than silently trusting browser storage.

## Agricultural observations

Reference: agricultural_reports.html and agricultural_reports.js plus associated validation/submission scripts.

Observed form fields include average, maximum and minimum air temperature; minimum temperature at 2 m; maximum/minimum soil-surface temperature; humidity and additional agricultural/climatological measurements.

The screen includes station/user context, date, statistics and field-level validation feedback. A full field/rule/payload inventory remains outstanding.

## Soil-temperature records

Reference: soil_temperature.html and associated soil send/validation scripts.

Observed read/report controls include station and date filters, data container, no-data state, refresh/load behavior, debug panel and Excel exports. The entry form and persistence model must be inspected separately.

## Dashboards and navigation

Reference screens include main.html, rec-main.html and sidebar.html.

These are multiple competing shell/dashboard implementations with overlapping navigation concepts. The new Angular application retains one shell and one shared sidebar. The authoritative legacy navigation reference and the exact set of modules must be reconciled before visual parity sign-off.

## Explicitly not yet certified

- Rainfall, climate-hourly, weather phenomena and maintenance workflows.
- Monthly/annual calculations and aggregation definitions.
- Role matrix and station assignment lifecycle.
- Approval/rejection/correction and archive state transitions.
- Exact PostgreSQL table schemas, constraints and relationships.
- Complete field-level validation rules and units for every form.
- Export formats and report calculations.

## Next migration unit

Complete the daily and hourly field/rule inventories, then define API request/response contracts and executable validation tests before wiring either client to persistence. Do not create or modify database tables until the schema and migration plan have been reviewed and approved.