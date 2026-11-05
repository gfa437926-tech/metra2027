# Legacy UI Migration Audit — METRA 2027

**Branch:** `work/legacy-ui-migration-audit`  
**Baseline:** `main` at `8094da69ac5e9ee210ec08532e49eebc1ba4e3fb`  
**Purpose:** Track complete migration of legacy web screens into the Angular web app and the independent Flutter mobile app without modifying legacy source files or database schemas.

## Guardrails

- Preserve every legacy HTML file as a read-only reference until its replacement is reviewed.
- Keep one shared navigation shell per client; do not duplicate sidebars inside feature pages.
- Reuse the approved new station catalogue only. Do not import legacy station records.
- Keep privileged database access in ASP.NET Core. Never expose Supabase service-role credentials to clients.
- Do not apply or modify Supabase schema/migrations until the user reviews and approves the schema.
- A screen is not considered migrated merely because a route or placeholder exists: its layout, fields, validation, actions, permissions, responsive behavior, and API integration must be checked.

## Legacy source inventory and target mapping

| Legacy source | Existing Angular target | Current migration assessment | Flutter target |
|---|---|---|---|
| `main.html` | Dashboard component at `/` | Dashboard exists; visual/functional parity audit required | Home overview exists; parity incomplete |
| `index.html` | Login/dashboard entry flow | Entry behavior needs comparison with legacy | Auth gate exists; parity incomplete |
| `rec-main.html` | Observation workflow / dashboard | Exact purpose and links need inspection | Observation review exists; parity incomplete |
| `hourly_reports.html` | `/reports/hourly` | Component exists; field/action parity audit required | Not implemented as a full screen |
| `climate_hourly_reports.html`, `h_climate_send.html` | `/reports/climate` | Component exists; source variants must be reconciled | Not implemented |
| `daily.html`, `daily_reports.html` | `/reports/daily` | Component exists; compare both legacy variants | Not implemented |
| `rainfall_reports.html` | `/reports/rainfall` | Component exists; parity audit required | Not implemented |
| `phenomena.html`, `weather_phenomena.html` | `/phenomena`, `/phenomena/input` | View and input routes exist; compare both sources | Not implemented |
| `soil-send.html`, `soil_temperature.html` | `/soil-temperature` | Component exists; entry/report flows need comparison | Not implemented |
| `agricultural_reports.html` | `/agriculture` | Component exists; parity audit required | Not implemented |
| `weather_analytics.html` | No confirmed dedicated route | Missing/unclear; inspect source and define destination | Not implemented |
| `fix.html` | No confirmed dedicated route | Missing: observation equipment fault reporting/management | Not implemented |
| `fix-tel.html` | No confirmed dedicated route | Missing: telecom fault reporting/management | Not implemented |
| `it.html` | No confirmed dedicated route | Missing: IT/software fault reporting/management | Not implemented |
| `it-maneger.html` | Users/authority area only partially related | Missing: IT manager workspace; do not conflate with user admin | Not implemented |
| `manag-net.html` | No confirmed dedicated route | Missing: network management workspace | Not implemented |
| `telecom-manager.html` | No confirmed dedicated route | Missing: telecom manager workspace | Not implemented |
| `workshop-manager.html` | No confirmed dedicated route | Missing: workshop/maintenance manager workspace | Not implemented |
| `manager-dashboard.html` | Dashboard component only partially related | Missing/unclear: management dashboard and role-specific content | Not implemented |
| `sidebar.html` | Shared navigation in `app.component.ts` | One shell exists, but its entries do not yet cover every legacy module | Flutter NavigationBar exists; mobile navigation parity incomplete |

## Existing client implementation snapshot

### Angular web
The current route table contains login, registration, dashboard, phenomena input/view, hourly, rainfall, daily, climate, agriculture, soil temperature, users, monthly, annual, and observation workflow. Monthly/annual are additional current routes; their presence does not prove a corresponding legacy screen was migrated.

The shared Angular shell currently exposes only a subset of the legacy sidebar destinations. Dedicated destinations for fault reporting, IT/network/telecom/workshop management, and weather analytics are not confirmed.

### Flutter mobile
The current app has a home overview, station directory, and observation review. Reports/analytics currently use an informational placeholder. The mobile app therefore does not yet represent the complete legacy application and needs a planned feature-by-feature port with mobile-appropriate interaction patterns.

## Work plan and acceptance criteria

1. **Recover and inspect the full RAR archive.** Enumerate every HTML, JS, CSS, image, JSON, and supporting file, including nested folders. Compare that inventory with the root-level legacy HTML files listed above. Do not modify or delete the archive.
2. **Build a screen specification per source page.** Record title, purpose, user roles, fields, validation, calculations, tables/charts, buttons, exports, dependencies, and responsive behavior.
3. **Complete Angular parity.** Implement missing modules and reconcile duplicate/variant legacy pages. Use a single sidebar and shared design tokens/components. Connect actions only to documented ASP.NET API endpoints.
4. **Port all approved workflows to Flutter.** Provide mobile layouts for entry, review, reports, faults, and management features according to role permissions; do not simply embed web pages.
5. **Verify both clients.** Build, lint/analyze, test, inspect navigation, and run role-based end-to-end checks. Track every source screen as Not started / In progress / Implemented / Verified.
6. **Production integration.** Configure HTTPS API origin, CORS, runtime configuration, and secrets only after the target hosting environment is selected and verified.

## Current status

- Inventory from tracked root-level HTML files: **24 files identified**.
- Angular: core weather/report feature components exist, but legacy parity is not verified and several management/fault modules are absent or unclear.
- Flutter: foundational shell, station directory, and observation review exist; most legacy feature screens remain to be ported.
- RAR archive: present in repository root, but its nested contents have not yet been extracted and audited.
- Database: no schema changes made as part of this audit.

**Important:** This is an inventory and migration plan, not a claim that the legacy UI migration is complete.

## Verified source-page findings (2026-11-05)

### Shared legacy sidebar: `sidebar.html`
The original sidebar is a single RTL navigation shell with a dark blue gradient, logo/system identity, current-user and station card, live clock, section headings, icon-coded links, active/hover states, and a logout action. Its verified destinations and labels are:

1. لوحة التحكم — `main.html`
2. النشرات الساعية — `hourly_reports.html`
3. المناخ الساعي — `h_climate_send.html`
4. النشرات اليومية — `daily.html`
5. حرارة التربة — `soil-send.html`
6. النشرات الزراعية — `agricultural_reports.html`
7. الظواهر الجوية — `weather_phenomena.html`
8. النشرات المطرية — `rainfall_reports.html`
9. أعطال الرصد — `fix.html`
10. أعطال الاتصالات — `fix-tel.html`
11. أعطال البرامج — `it.html`
12. تسجيل الخروج

The current Angular shell already has one shared sidebar, but its menu differs: it adds monthly/annual reports, phenomena input/view, observation review, and user administration while omitting the three legacy fault destinations. The migration must reconcile these deliberately; do not add another sidebar inside individual pages. Preserve the legacy Arabic names where they represent the same workflow, and retain newer routes only where they are approved product features.

### Management dashboard: `manager-dashboard.html`
This is a substantial role-oriented management workspace, not merely a generic home dashboard. Verified UI elements include:
- Summary cards for total/active users, total/today reports, total/active stations, and pending registrations.
- Charts for users by station, report activity/distribution, monthly activity, users by role, and registration status.
- User table with search/pagination and actions for edit, delete, password reset, and WhatsApp reminder.
- Registration queue with approve/reject/details actions.
- Station/report detail tables and overall statistics export/print actions.
- Reminder history, bulk and scheduled WhatsApp reminders, connection test, and logs.

**Security/architecture migration note:** the legacy page loads the Supabase JavaScript client directly and has client-side management actions. Rebuild the capabilities through authenticated ASP.NET Core endpoints with server-side role authorization and audit logging. Never copy a Supabase service-role key or privileged WhatsApp credentials into Angular or Flutter. Deletion, password reset, bulk messaging, and scheduled reminders require explicit permission checks and safe server-side workflows.

### Angular parity checkpoint
The current Angular route table has routes for login, registration, dashboard, phenomena input/view, hourly, rainfall, daily, climate, agriculture, soil temperature, users, monthly, annual, and observation workflow. It does not yet declare dedicated routes for the three legacy fault pages, IT manager, network manager, telecom manager, workshop manager, or a clearly equivalent manager dashboard. A route alone is not acceptance: each screen still needs field/action/permission/API parity and visual review.


### Fault, maintenance, analytics, and network screens — source inspection

The following root-level sources were inspected beyond title-only inventory. Their controls establish concrete migration requirements:

| Source | Verified workflow and UI elements | Migration implications |
|---|---|---|
| `fix.html` | New observation-equipment failure form; reporter/station identity; automatic/classic/special equipment sections; description/date/severity/image/urgent repair; status counters; manual measurement modal; share-report action | Requires a complete fault-intake workflow, equipment-specific fields, attachment handling, urgency, and status tracking |
| `fix-tel.html` | Communications and IT equipment categories: phone, tower, satellite, fax, computer, laptop, printer, network, Wi-Fi; separate forms and details modal; pending/review/resolved/urgent counters | Model device category and category-specific details rather than a generic free-text fault form |
| `it.html` | Technical-problem report with reporter identity/position/phone, bulletin type, affected field, problem type/details/description/urgency; previous reports, filters, quick stats, save/send actions | Needs structured issue classification, validation, report history, filters, and safe submission semantics |
| `it-maneger.html` | IT report statistics: period selector, total reports, average resolution time, resolution rate, unique reporters; status/urgency/monthly/bulletin charts; station table and common problems | This is an analytics/manager screen, not the user-administration page |
| `manag-net.html` | Integrated network/system dashboard with station/observer/report counts and tabs/tables for weather reports, equipment faults, telecom faults, IT problems, reminders, activity log, user messages, registration queue, system stats, backups, and SMS | Broad operations dashboard; separate read permissions and controlled actions per tab |
| `telecom-manager.html` | Telecom fault management with search and filters by device/status/urgency/station; report details; status editing (pending/in progress/resolved/cancelled); device/urgent/description/reporter fields; charts; create-report modal; export/print/PDF/XLSX dependencies | Requires a full manager workflow with audit trail, filtering, status transitions, and export permissions |
| `workshop-manager.html` | Observation-equipment maintenance dashboard; pending/in-progress/resolved/urgent/today/total metrics; resolution and urgency rates; status/severity charts; filters by status/severity/station/date; details and image modal; assignment, progress percentage, expected resolution date | Requires assignment and progress tracking, image access control, and maintenance lifecycle |
| `weather_analytics.html` | Station/date-range selectors and charts for temperature/dew point/feels-like, humidity, wind, pressure, and solar brightness | Dedicated weather analytics feature is missing from the current Angular route table and Flutter feature set |

### Security and parity implications from this inspection

- The legacy screens rely on browser-side third-party libraries for charts, tables, PDF/XLSX export, QR generation, and direct data access. Treat these as UI references, not as an approved backend/security design.
- Implement server-side authorization for every read, create, update, export, assignment, bulk action, and attachment download. Enforce station scope on the API; hiding a menu item is not authorization.
- Preserve status vocabulary and operational distinctions where appropriate, but validate allowed transitions on the server and record who changed what and when.
- Do not carry over legacy direct Supabase privileged access, credentials, or test-data shortcuts into the new app.
- No source HTML, existing database, or Supabase schema was modified during this inspection.


### Client navigation and implementation gap — follow-up inspection

The Angular router and shared shell were inspected directly against the legacy page inventory.

**Angular routes currently present:** login, registration, dashboard, phenomena input/view, hourly, rainfall, daily, climate, agriculture, soil temperature, users, monthly, annual, and observation workflow.

**Legacy destinations still without a dedicated confirmed route/component:**
- Observation equipment faults (`fix.html`)
- Communications/technology faults (`fix-tel.html`)
- Software/IT problem reports (`it.html`)
- IT manager statistics (`it-maneger.html`)
- Integrated network/operations management (`manag-net.html`)
- Telecom manager (`telecom-manager.html`)
- Workshop/maintenance manager (`workshop-manager.html`)
- Weather analytics (`weather_analytics.html`)
- The full role-oriented manager dashboard (`manager-dashboard.html`)

The Angular shared navigation has one sidebar, which is the correct structural approach, but it currently omits the above legacy destinations. Navigation should be expanded only alongside real feature routes and role-based visibility; adding dead links or placeholder routes would not count as migration.

**Flutter implementation confirmed:** the app currently has five bottom-navigation destinations (home, stations, observation review, reports, account settings). The reports destination is explicitly an informational placeholder pending a trusted approved-observation data source. No dedicated mobile workflows for faults, IT/telecom management, workshop maintenance, or weather analytics were found in the inspected home/navigation files.

### Security review items to resolve before exposing management pages

- The Angular dashboard route (`path: ''`) currently has no `requireAuthenticatedUser` guard, unlike the feature routes. Confirm the intended public/anonymous landing behavior before changing it; do not assume that hiding navigation is sufficient protection.
- Management routes must use explicit role/permission guards in the client for navigation and enforce the same authorization again in ASP.NET Core for every API operation.
- Station-scoped users must not be able to query or mutate another station by changing request parameters.
- User deletion, password reset, approval/rejection, report cancellation, bulk reminders, exports, backup access, and attachment retrieval are privileged operations and need server-side audit events.
- Keep the current Supabase schema untouched until the user has reviewed and approved a proposed schema and migration plan.

### Recommended implementation sequence after archive inspection

1. Recover the RAR and extract a complete file/dependency inventory.
2. Create an approved workflow specification and role/permission matrix for the nine missing or unclear destinations listed above.
3. Implement ASP.NET Core API contracts and authorization/audit behavior for faults, maintenance, analytics, and management before connecting client actions.
4. Build the Angular screens and connect them to those contracts; preserve the single shared sidebar.
5. Port approved workflows into native Flutter screens and role-aware navigation.
6. Run both clients' tests and verify role/station isolation end-to-end.

This follow-up is a source/navigation audit only. It does not claim that any missing screen has been implemented or verified.


### Backend capability cross-check

The ASP.NET Core API source and backend README were checked against the missing legacy workflows.

**Existing API feature families confirmed in source:** observation validation/submission/decision/review queue; station directory/catalogue review; registration submission/review; station user directory; station assignment management; station audit; authority access; health/readiness.

**Not found in the current backend feature tree or endpoint registration:** equipment-fault intake and maintenance lifecycle, telecom fault management, IT problem reporting/statistics, integrated operations dashboard, weather analytics queries/aggregations, manager dashboard aggregates, and reminder scheduling/delivery. These must be designed as new server-side feature families before client screens can be fully functional.

**Important architecture boundary:** the API applies a global authenticated-user fallback policy and has server-side station permission checks for operational routes. New management features must follow this pattern and must not query Supabase directly from Angular or Flutter with privileged credentials.

**Readiness maintenance requirement:** when new backend feature services are introduced, update the readiness dependency check and tests so the API cannot be marked ready while a required configured feature is unavailable. Do not claim production readiness solely from the existing health endpoint.

### Backend-first contract backlog

| Proposed API area | Initial contract scope (design target; not implemented) |
|---|---|
| Observation equipment faults | Station-scoped create/list/detail; image metadata and secure upload/download; severity and urgency; status lifecycle |
| Telecom/IT faults | Typed device/problem categories; create/list/detail; assignment; status transition; update notes; audit |
| Workshop maintenance | Queue; assignment; progress; expected resolution date; resolution details; controlled attachment access |
| Management dashboard | Permission-filtered summary counts and bounded aggregate datasets; no broad raw-table exposure |
| Weather analytics | Station/date-range query with explicit approved-data filters and bounded aggregation; documented units and missing-data handling |
| Reminders | Permission-checked preview, explicit confirmation, delivery status/history, rate limits, and provider credentials held only server-side |

No endpoint, database table, RPC, or migration was created by this cross-check. All proposed contracts remain subject to schema review and approval.

### Archive recovery
The repository contains the RAR archive, but GitHub's text-file retrieval cannot extract binary archive contents. Local extraction-tool availability has not yet been confirmed. The archive remains untouched.


## Follow-up implementation — equipment fault domain (2026-11-05)

A persistence-independent first implementation now exists on the work branch:

- `backend/Metra.Api/Domain/Maintenance/EquipmentFaultPolicy.cs` defines the equipment-fault report contract, severity/status enums, input validation, and permitted lifecycle transitions.
- `backend/Metra.Api.Tests/Domain/EquipmentFaultPolicyTests.cs` covers valid reports, missing identities, short text, future timestamps, blocking-severity consistency, and allowed/forbidden transitions.
- `docs/api/EQUIPMENT-FAULTS-CONTRACT.md` records the proposed station-scoped HTTP contract and security invariants.

This is domain groundwork only. No HTTP endpoints, persistence adapter, Supabase tables/RPCs/storage buckets, attachment upload, Angular screens, or Flutter screens have been implemented for this feature. The database remains unchanged and explicit schema approval is still required before persistence work.


## Follow-up implementation — IT and telecommunications incident domain (2026-11-05)

- Added `backend/Metra.Api/Domain/Support/SupportIncidentPolicy.cs` for station-scoped IT and telecom incident validation, severity consistency, and lifecycle transitions including waiting-for-information and rework.
- Added `backend/Metra.Api.Tests/Domain/SupportIncidentPolicyTests.cs` for both incident kinds, identity and text validation, future timestamps, operational impact severity, and lifecycle paths.
- Added `docs/api/SUPPORT-INCIDENTS-CONTRACT.md` with proposed station-scoped API routes, permission boundaries, audit expectations, validation, and response semantics.

These additions are domain and contract groundwork only. No support-incidents API endpoints, persistence adapters, Supabase schema, category catalogue, attachment storage, or client screens have been implemented. Explicit database approval remains a prerequisite for persistence.


## Follow-up implementation — workshop assignment policy (2026-11-05)

- Added `backend/Metra.Api/Domain/Maintenance/MaintenanceAssignmentPolicy.cs` to validate fault/station/assignee identifiers, assignment timestamp, expected resolution window, and assignment-note length.
- Added `backend/Metra.Api.Tests/Domain/MaintenanceAssignmentPolicyTests.cs` covering valid assignment, required identities, expected-resolution ordering, and note limits.

This is validation groundwork only. It does not implement assignment authorization, persistence, notifications, API routes, or workshop UI. Authorization must verify that the assignee is an active support user with access to the same station before any assignment is accepted.


## Authorization follow-up (2026-11-05)

Added `docs/security/SUPPORT-MAINTENANCE-AUTHORIZATION-MATRIX.md` defining proposed server-side identity resolution, station isolation, support/maintenance permission names, mutation/audit requirements, attachment privacy, and readiness gates. This remains a design contract: no routes, database changes, or UI integrations were introduced by this document.


## Support incident policy test checkpoint (2026-11-05)

The support incident policy test suite now exercises the following validation and lifecycle cases:

- valid IT and telecommunications reports;
- missing station/reporter identifiers and undefined kind/severity enum values;
- too-short and whitespace-only category/title/description values;
- maximum-length overflow for category, title, description, and affected-asset label;
- future occurrence timestamps, the exact five-minute future boundary, and a default timestamp;
- operational impact paired with insufficient severity;
- nullable affected-asset label and null report handling;
- supported review/assignment/progress/waiting/resolution/rework transitions, terminal closed/rejected states, and undefined lifecycle values.

**CI evidence:** GitHub Actions Backend build #786 completed successfully for commit `027270604fac9c493058f52fe1f25e4fb7cb31a0`. This confirms that the domain test batch built and passed in CI. It does not establish API, database, authorization, or client-screen readiness. The later documentation-only contract update is not represented by that CI run.


## Support incident optional asset validation hardening (2026-11-05)

The support incident domain policy now treats the optional affected-asset label as follows: null remains valid; a supplied whitespace-only value is rejected; and a trimmed label longer than 160 characters is rejected. Added tests cover blank strings, whitespace-only strings, and the exact 160-character accepted boundary. This closes the gap where a non-null blank label previously passed policy validation.

Commits: `9ecfc497db33e7fa5422d01491288b9ab015be72` (policy) and `a8fc6de2f7d813071a4ca9b94fb107ba2c702d3d` (tests). CI has not yet been checked for these commits; treat this as pending verification.
