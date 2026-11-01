# Legacy Code Audit — Initial Findings

This is a source-structure audit, not a complete functional sign-off. It records duplicated responsibilities visible in the current legacy repository so the rebuild can consolidate them without discarding workflows.

## Repository shape

The legacy root contains a large collection of standalone HTML, JavaScript and CSS files. The initial repository tree scan found 83 files with .html, .js or .css extensions outside the Angular application. Several files combine DOM initialization, validation, session handling, data shaping and persistence.

## Confirmed responsibility overlap

| Concern | Legacy files | Initial finding | Migration direction |
|---|---|---|---|
| Login page behavior | login.js, main.js | Both contain login-page initialization and password/input behavior | One identity UI feature; API/identity provider owns authentication |
| Session and user context | auth-manager.js, user-manager.js, user-data.js | Multiple managers read/write browser storage and derive user/session state | One identity/session adapter; server remains authoritative |
| Supabase client setup | supabase-config.js, database.js, daily_db.js, submit-handler.js | Client creation/configuration appears in multiple files | Database access only in backend infrastructure |
| Daily validation | daily_validation.js, enhanced-validation.js, daily_main.js | Validation, formatting and cross-field checks are split across scripts | One tested daily-observation rule set; client mirrors only UX feedback |
| Hourly validation and submission | hourly-send.js, submit-hourly.js, enhanced-validation.js | Validation and submit responsibilities are distributed | One hourly use case and one authoritative API validation path |
| Report persistence | daily_db.js, submit-hourly.js, submit-handler.js | Different modules construct and submit records independently | Feature-specific application use cases over shared persistence abstractions |

## Security and integrity risks requiring replacement

- Legacy authorization/session logic relies on browser storage such as localStorage and sessionStorage; browser state cannot be trusted for authorization.
- Legacy scripts include direct browser-to-Supabase data access. The rebuilt clients must call the backend API instead.
- Some legacy files contain embedded project configuration or public client keys. No secret or privileged key may be copied into a client bundle. Existing exposed credentials must be reviewed separately; this audit does not publish or reproduce them.
- Multiple record-submission paths risk inconsistent validation, metadata and status handling.
- The original code contains overlapping scripts and fixes; loading order may affect behavior. The rebuild must not preserve this dependency pattern.

## Current clean-project baseline

- Angular currently has a single application shell and shared sidebar in angular-app/src/app/app.component.ts.
- Angular routes currently cover dashboard, hourly/daily/climate reports, monthly/annual reports, agriculture, soil temperature and users.
- Several report pages are scaffolds or local UI only; they are not proof of complete data workflows.
- ASP.NET Core currently exposes only GET /api/v1/health; authentication, domain use cases and database persistence are not implemented.
- The Angular package includes the Supabase JS client, but the new architecture must not use a browser database client for authoritative business data.
- The current Supabase project has not been approved for schema changes. No database or RLS changes are included in this audit.

## What remains to inspect before migrating a workflow

For every observation type, inspect the original HTML form and all scripts it loads, then document:

- field identifiers, labels, units, allowed formats and missing-value markers;
- required/optional conditions and cross-field rules;
- time basis, UTC/local handling and reporting-period rules;
- station and user attribution;
- duplicate-submission behavior and record identifiers;
- persistence destination and existing schema expectations;
- edit, correction, review, approval and archive transitions;
- role and station-assignment requirements;
- print/export/report outputs.

## Audit status

- [x] Identify legacy file inventory and obvious overlapping modules.
- [x] Record current Angular and API boundaries.
- [ ] Map every original screen to its scripts and data tables.
- [ ] Extract and reconcile all field-level meteorological validation rules.
- [ ] Confirm original database schema and data relationships without modifying them.
- [ ] Establish automated parity tests for each migrated workflow.

Do not delete legacy files until the relevant workflow has passed parity and regression checks.