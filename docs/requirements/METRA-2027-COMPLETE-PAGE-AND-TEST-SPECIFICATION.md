# METRA 2027 — Complete Page, Workflow & Test Specification

- **Document type:** Master requirements and verification register
- **Status:** Working baseline — requires owner review and approval of unresolved domain rules
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `docs/metra-complete-page-test-matrix`
- **Last updated:** 2026-11-10
- **Source baseline:** `docs/architecture/WORKFLOW-INVENTORY.md`, `docs/architecture/LEGACY-AUDIT.md`, repository README, current Angular routes/features, Flutter modules and API/test structure.
- **Purpose:** One navigable inventory of the screens, responsibilities, role boundaries, workflows, and tests required to complete the whole METRA 2027 rebuild.

> This document consolidates observed repository structure and requirements already stated by the project owner. It is not a claim that every listed page is implemented or that every meteorological rule is known. Items marked **TBD / owner approval** must not be guessed. Do not treat UI visibility as authorization.

## 1. Product scope and non-negotiable constraints

METRA 2027 consists of three independently runnable applications:

| Application | Technology | Repository folder |
|---|---|---|
| Web client | Angular | `angular-app/` |
| Mobile client | Flutter | `flutter-app/` |
| Backend | ASP.NET Core / .NET | `backend/Metra.Api/` |

The backend is the authoritative boundary for authentication context, authorization, validation, workflow transitions and privileged data access. Clients must not connect directly to the operational database for authoritative business operations.

### 1.1 Project constraints

1. All meteorological report timestamps and displayed report times use **UTC only**. Do not convert to or display local time.
2. The 06:00 UTC and 18:00 UTC bulletin/report times belong to the hourly workflow. They are not daily reports. A daily report is a 24-hour summary.
3. Manual Excel archiving is a separate administrative process. The auditor records that an exported Excel report was archived, to prevent forgetting. The application does not automatically transfer those records to the primary database or archive database.
4. The application must not connect to the archive database.
5. The old database and old repository are reference-only and must not be modified. Do not migrate, overwrite, delete or write to the old database.
6. Use the new station catalogue supplied for this rebuild. Do not silently reuse the old station list or old database records.
7. No schema, migration, seed, RLS policy or database write is to be applied until the schema and migration plan have been reviewed and explicitly approved by the owner.
8. The exact role grants and national/global auditor scope are not fully established. Do not infer global access from a role name.
9. Rebuild legacy behavior from inspected requirements; do not copy protected legacy source files verbatim.
10. Keep web, mobile and backend independently buildable and testable. No production deployment or PR merge without approval.

### 1.2 Status vocabulary

- **Observed:** The screen, route, control or module exists in the inspected source.
- **Required:** A project-owner requirement or necessary workflow capability.
- **Planned:** Included in this master specification but not confirmed complete.
- **TBD:** Requires source inspection or owner decision.
- **Blocked:** Cannot be safely implemented until a prerequisite is resolved.
- **Verified:** Must be backed by a passing automated test or recorded manual acceptance evidence.

## 2. Page and module catalogue

The same business capability may appear in both clients. Each client must provide equivalent authorized workflows, but platform-specific layout may differ. A shared page name does not mean a shared permission.

### 2.1 Identity and account lifecycle

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| ID-01 | Sign in | Email, password, remember-me if approved, submit, loading and error states | Anonymous | valid/invalid credentials; empty fields; disabled/pending account; throttling; no token leakage |
| ID-02 | Registration request | First/father/family name, station, work role, email, phone, password/confirmation only if identity provider requires, terms | Anonymous; creates pending request | required fields; format; duplicate request; station selection; terms; no self-granted role |
| ID-03 | Registration review | Pending requests, applicant details, station and requested role, approve/reject/return with reason | Authorized registration reviewer; exact grants TBD | unauthorized denial; approve/reject; reason required; duplicate decision; audit trail |
| ID-04 | Password recovery | Identity-provider recovery flow; success/error feedback | Anonymous | valid/unknown account privacy; expired token; replay; rate limiting |
| ID-05 | Account/profile | Profile, account state, assigned station(s), role display, sign out | Authenticated; editable fields TBD | own profile only; stale session; revoked assignment; sign-out invalidates session |
| ID-06 | Access denied / session expired | Clear denied, expired, pending and unavailable states | All | deep-link denial; refresh denial; expired/revoked JWT; no protected data rendered |

Legacy shared registration passwords must not be reproduced. Registration must not directly create active privileged accounts.

### 2.2 Shared home, navigation and station directory

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| NAV-01 | Main dashboard | Summary cards, authorized work shortcuts, alerts, latest activity | Authenticated; cards filtered by server-authorized scope | role-specific cards; no data leakage; empty/loading/error |
| NAV-02 | Shared navigation/sidebar | One consistent shell, module links, selected state, responsive collapse | Authenticated | each route opens correct page; no duplicate sidebar; back/deep-link behavior |
| ST-01 | Station directory | New approved station catalogue, search/filter, station details and operational status | Read scope depends on role | approved catalogue only; pagination; inactive/unapproved handling; unauthorized station access |
| ST-02 | Station details / assignment | Station metadata and assignment history where authorized | Admin/authorized assignment manager; grants TBD | assignment lifecycle; overlap; expired assignment; station isolation |

The authoritative station catalogue must be sourced from the new approved catalogue. Missing or unverified attributes must remain explicitly unknown rather than fabricated.

### 2.3 Hourly observation entry and review

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| HR-01 | Hourly entry | UTC reporting date/time; station context; meteorological fields; save draft/submit according to approved workflow | Observer/authorized station user | requiredness; type/range; cross-field rules; UTC; station binding; duplicate submit |
| HR-02 | Hourly report list | Filter by station, UTC period, status; view records | User's authorized station/scope | filters; pagination; empty/error; no cross-station disclosure |
| HR-03 | Hourly report details | Full observation, validation results, history and status | Authorized read scope | record-level authorization; immutable audit history |
| HR-04 | Hourly review queue | Submitted records awaiting review; filters and detail navigation | Station reviewer/auditor within verified scope | queue scope; paging; stale queue; unauthorized access |
| HR-05 | Hourly review decision | Approve, return for correction or reject only where policy defines; mandatory reason where applicable | Authorized reviewer; transition matrix TBD | permitted/forbidden transitions; concurrency; reason; actor/time audit |
| HR-06 | Hourly correction | Correct/return workflow without erasing prior version | Role and transition rules TBD | version history; original retained; re-review; conflict detection |

**UTC rule:** the reporting time, filter, saved timestamp and displayed timestamp are UTC. 06:00 UTC and 18:00 UTC are hourly bulletin times. No local-time counterpart is to be shown.

**Hourly field inventory status:** the initial workflow inventory observed dry-bulb and wet-bulb temperature, station and sea-level pressure, pressure tendency/characteristic, relative humidity, vapour pressure, dew point, vapour-pressure difference, wind direction/speed and average wind direction/speed. This is not certified as a complete field list. Every remaining original field, unit, precision, missing marker, range and conditional rule must be extracted from the full source form and verified with the owner before implementation.

### 2.4 Daily observation entry and review

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| DY-01 | Daily entry | 24-hour summary form for one station and UTC reporting date/period | Observer/authorized station user | requiredness; range; date/period; cross-field rules; duplicates |
| DY-02 | Daily report list | Station, month/year or UTC period filters; summary counts; list | Authorized station/scope | filter boundaries; totals; pagination; station isolation |
| DY-03 | Daily report details | Full daily record, validation and status history | Authorized read scope | record authorization; audit history |
| DY-04 | Daily review queue | Pending daily records | Station reviewer/auditor within verified scope | scope and queue filters; paging; empty/error |
| DY-05 | Daily review decision | Approve/return/reject according to approved workflow | Authorized reviewer | state transition matrix; reason; concurrency; audit |
| DY-06 | Daily correction | Correct returned records while preserving prior values | Authorized submitter/reviewer as defined | history; revalidation; re-review |

Daily reporting is a 24-hour summary. It must not be confused with the 06:00 UTC or 18:00 UTC hourly bulletins. Exact start/end boundary, required fields and calculation rules are **TBD / owner approval**.

### 2.5 Review, audit and data-quality workspaces

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| AU-01 | Auditor workspace | Authorized station/report filters, review queues, data quality indicators | Auditor scope not yet fully approved | role and station scope; global scope denied unless explicit grant |
| AU-02 | Station observation view | Read/inspect observations for assigned station | Station head for current assigned station; auditor per approved scope | cross-station denial; expired assignment; direct API denial |
| AU-03 | Missing-data register | Missing records/fields and issue classification | Auditor / authorized manager | deterministic missing detection; duplicate issue; resolved state |
| AU-04 | Review history | Actor, UTC timestamp, action, reason, before/after references | Authorized audit readers | immutable history; no unauthorized alteration |
| AU-05 | Monthly audit report | Monthly counts of archived Excel reports, missing records/fields identified by Head of Network Department, completed archive confirmations and outstanding items | Auditor records manual archive confirmation; management read scope TBD | month boundaries UTC; counts reconcile; duplicate archive prevention; outstanding list |

**Manual archive workflow:** exported Excel files are archived manually outside the application. The auditor records that the relevant report/file has been archived and when, using a reference or filename and reporting period. This ledger is a reminder and evidence log only. It does not upload, copy, move, migrate or write report data into any archive or primary database.

The person who identifies/defines missing data is the Head of Network Department, as specified by the owner. The monthly report is prepared by the auditor and must distinguish (a) missing records/fields identified, (b) Excel reports marked as manually archived, and (c) still-outstanding archive confirmations. Exact approval and edit rights for this register are TBD.

### 2.6 Management and administration

| ID | Page / route | Main contents and actions | Access / state | Required tests |
|---|---|---|---|---|
| AD-01 | User directory | Search users, account state, station and role summary | Admin grant TBD | protected fields; pagination; unauthorized denial |
| AD-02 | User details | Identity profile, current role grants and station assignments | Admin grant TBD | least privilege; audit; sensitive data minimization |
| AD-03 | Role/permission administration | View and change explicitly approved grants | Designated security admin; no implicit superuser | privilege escalation denial; change audit; last-admin protection |
| AD-04 | Station assignment administration | Assign/revoke station scope with effective dates | Designated authority | overlap; revocation immediate; history |
| AD-05 | Operational settings | Approved reference lists and configuration | Designated admin; individual settings TBD | validation; versioning; audit; no client-side trust |
| AD-06 | Management files | Approved administrative documents/reports | Role-specific access TBD | file type/size; malware scan; access; download audit |

No role matrix is final until owner approval. Existing labels such as station auditor and chief auditor do not prove national/global permission.

### 2.7 Reports and specialist modules

The repository contains or references additional report modules. Their presence in the code is not proof of complete business requirements or operational readiness.

| ID | Page / module | Observed / expected contents | Required tests / unresolved work |
|---|---|---|---|
| RP-01 | Hourly reports | Station/time filters, records and export/print | UTC filters; totals; export parity; access scope |
| RP-02 | Daily reports | Station, month/year filters, day/report/completion summaries, table, Excel/print | 24-hour definition; summary calculations; export parity |
| RP-03 | Monthly reports | Monthly aggregation and report output | aggregation formula and missing-data treatment TBD |
| RP-04 | Annual reports | Annual aggregation and report output | annual boundaries, formulas and completeness TBD |
| RP-05 | Climate reports | Climate summaries and filters | climate definitions and period rules TBD |
| RP-06 | Rainfall reports | Rainfall data and reports | units, accumulation and missing markers TBD |
| RP-07 | Agricultural reports | Agricultural/climatological measurements and statistics | complete field/rule inventory TBD |
| RP-08 | Soil temperature | Soil-temperature records, date/station filters and exports | depth, units, sensor/time rules TBD |
| RP-09 | Weather phenomena | Phenomena input, catalogue, reports and API/schema proposal | catalogue values, code mapping and validation approval |
| RP-10 | Station/operational dashboard | Station status and authorized operational summary | source-of-truth and metric definitions TBD |

The initial workflow inventory observed dashboard, hourly/daily/monthly/annual/climate/rainfall reports, agricultural reports, soil temperature, weather phenomena, user/registration and station-related features. A route-by-route parity audit must reconcile the current clients with the original required modules before declaring the catalogue complete.

## 3. Role and access model — approval required

This section defines security test expectations, not final grants.

| Role concept | Minimum expected boundary | Must be denied |
|---|---|---|
| Observer / station operator | Submit records only for currently assigned station and permitted report types | Other stations; administration; review decisions unless explicitly granted |
| Station head | View and manage workflow for the currently assigned station according to approved policy | Any unassigned station; national queue by default |
| Station auditor | Review/read records within explicitly assigned station scope | Other stations and global scope unless separately granted |
| Chief / central auditor | Scope is **unproven**; must be explicitly approved and represented by a server-side grant | No inferred global access from role name |
| Registration reviewer | Review registration requests only | Observation/admin permissions not separately granted |
| System/security administrator | Manage only approved identity/role/assignment capabilities | Unlogged privilege changes; bypass of audit controls |
| Management/read-only roles | Read only the explicitly approved management views | Writes, review decisions and unrelated personal data |

### 3.1 Mandatory authorization rules

- Actor identity must come from a validated server-side JWT subject, never a client-supplied user ID.
- The server must verify role grant, station assignment, assignment validity and resource scope for every request.
- Navigation visibility is cosmetic and is never authorization.
- Deep links and direct API calls must fail closed.
- A station head must not read or mutate another station's records, even by changing IDs, filters, pagination, exports or request bodies.
- Revoked/expired assignments must stop granting access.
- Queue authorization and queue data retrieval must be atomic or otherwise protected against time-of-check/time-of-use races.
- Failures in authorization lookup must deny access, not fall back to broad access.
- Every privileged action and review decision must have actor, UTC timestamp, target, action and reason where applicable.

## 4. Cross-page workflow and state model

The exact transition matrix is a domain decision and must be approved. The following is the minimum workflow to test:

1. User authenticates.
2. Server resolves active account, role grants and current station assignment.
3. User opens an authorized entry page.
4. Client loads station/report context from the API.
5. User saves a draft or submits a record, depending on the approved feature.
6. API validates all field and cross-field rules independently of client validation.
7. Submitted record enters the defined review queue.
8. Authorized reviewer opens the record within scope.
9. Reviewer performs an allowed decision with required reason.
10. Submitter corrects a returned record without losing the previous version.
11. Record history preserves each state transition and actor.
12. Reports and exports reflect only authorized records and approved calculations.

### 4.1 Common states to define

- Draft
- Submitted / pending review
- Returned for correction
- Resubmitted
- Approved
- Rejected (only if owner confirms this state)
- Archived confirmation recorded (administrative ledger state; not the observation's database migration state)

Whether drafts, rejection, reopening, editing after approval, and deletion are allowed is **TBD / owner approval**. Never silently introduce destructive deletion.

## 5. Field specification standard

Every meteorological field in hourly, daily, rainfall, agricultural, soil, phenomena and climate forms must have a row in an approved field catalogue containing:

| Attribute | Required definition |
|---|---|
| Field ID | Stable machine identifier |
| Arabic label | Exact approved UI label |
| English/internal name | Stable code/translation if needed |
| Data type | Integer, decimal, text, enum, boolean, date/time, structured value |
| Unit | Explicit physical unit or not applicable |
| Precision | Decimal places / integer width |
| Allowed values | Closed enum or documented range |
| Missing marker | Explicit code and meaning; never guess |
| Requiredness | Always, conditional, optional |
| Conditional dependency | Other field and condition |
| Cross-field validation | Formula or comparison rule |
| UTC/time relation | Timestamp basis and reporting period |
| Source | Original screen, approved table or owner decision |
| Test IDs | Unit/API/UI tests that enforce it |
| Approval status | Draft / approved / superseded |

Do not invent plausible meteorological ranges. The existing initial source inventory identifies some hourly fields, but complete numeric bounds, units, missing markers, precision, psychrometric lookup rules and daily requiredness must be extracted and approved.

## 6. Test strategy and required suites

Tests must exist at multiple layers. Passing a build or a widget test does not prove the end-to-end workflow.

### 6.1 Unit tests

- Field parsing, formatting, rounding and missing-value handling.
- Required/optional and conditional field rules.
- Cross-field meteorological relationships.
- UTC period calculations and 06:00/18:00 hourly bulletin handling.
- Daily 24-hour summary boundaries.
- Aggregation and report totals once formulas are approved.
- Workflow transition policy.
- Role/assignment policy predicates.
- Excel archive ledger calculations and duplicate detection.

### 6.2 API and backend integration tests

- Authentication required on every protected endpoint.
- Invalid, expired and revoked tokens.
- Actor identity cannot be spoofed in payload.
- Role and station assignment required.
- Cross-station GET/POST/PUT/review/export attempts denied.
- Unapproved or inactive station cannot be used for new submissions.
- Invalid fields rejected server-side even when client bypasses validation.
- Duplicate submissions and idempotency behavior.
- Review transition allowed/denied matrix.
- Concurrent review decisions and stale record versions.
- Audit history records the correct actor and UTC timestamp.
- Queue reads are protected from TOCTOU scope changes.
- Pagination and filtering cannot widen scope.
- Authorization lookup failure is fail-closed.
- No direct browser/mobile database credential or privileged key exposure.

### 6.3 Angular tests

- Route guard and deep-link behavior for anonymous, pending, disabled and authorized users.
- Shared sidebar appears once and selected navigation is correct.
- Each route renders loading, empty, error and success states.
- Form labels, required markers, field errors and keyboard navigation.
- Client validation matches approved rules but API remains authoritative.
- Filters, pagination, sorting and exports preserve authorized scope.
- Review actions require confirmation/reason where defined.
- Responsive layout and RTL/Arabic presentation.
- No local time conversion in report timestamps.

### 6.4 Flutter tests

- App startup and API configuration gate.
- Sign-in/session state and logout.
- Home navigation and station directory.
- Observation workspace loads and handles empty/error states.
- Hourly/daily form rendering and validation.
- Submission and review navigation.
- Deep-link and stale-session denial.
- Station isolation in list, details, search and actions.
- Offline/local draft behavior only after its design is approved.
- UTC display and no local conversion.
- Accessibility, screen size and RTL/Arabic layout.

### 6.5 End-to-end and regression tests

- Registration request → review → activation → sign-in.
- Observer submits hourly report → reviewer sees it → returns it → observer corrects → reviewer approves.
- Daily 24-hour report through equivalent workflow.
- Station head reads own station and is denied another station.
- Auditor access follows only explicitly approved scope.
- Monthly audit register reconciles Excel archive confirmations and missing-field list.
- Export totals equal filtered source records.
- All three applications use the same API contracts and server-side validation.
- Deployment smoke tests: HTTPS, health, readiness, CORS, authentication and a safe read/write test in a non-production test environment.

## 7. Test register and evidence checklist

Use stable test IDs and link each to a test file or CI run as implementation proceeds.

| Test ID | Scenario | Layer | Pass condition | Status |
|---|---|---|---|---|
| AUTH-001 | Anonymous access to protected route/API | Web/API/Mobile | Denied; no protected data | Planned |
| AUTH-002 | Pending/disabled account | API/clients | Cannot perform operational actions | Planned |
| AUTH-003 | Expired/revoked token | API/clients | Session rejected and protected view cleared | Planned |
| AUTH-004 | Client-supplied actor spoofing | API | Ignored/rejected; JWT subject authoritative | Planned |
| STN-001 | Station head reads assigned station | API | Only current assignment returned | Planned |
| STN-002 | Station head requests another station | API | Denied with no data leakage | Planned |
| STN-003 | Assignment revoked during active session | API | Subsequent access denied | Planned |
| STN-004 | Authorization lookup unavailable | API | Fail closed | Planned |
| HR-001 | Valid hourly observation | API/UI | Saved with UTC and correct station | Planned |
| HR-002 | Invalid hourly field/cross-field rule | API | Rejected server-side with field errors | Planned |
| HR-003 | 06:00 and 18:00 UTC bulletin | Unit/API/UI | Correct hourly classification; no local conversion | Planned |
| DY-001 | Valid 24-hour daily observation | API/UI | Correct reporting period | Planned |
| DY-002 | Daily period boundary | Unit/API | Exact approved UTC boundary enforced | Blocked: approval |
| REV-001 | Authorized reviewer approves | API/UI | Allowed transition and audit event | Planned |
| REV-002 | Unauthorized reviewer decision | API | Denied | Planned |
| REV-003 | Concurrent/stale review decision | API | Conflict safely handled | Planned |
| REV-004 | Returned record correction | API/UI | New version retained and re-reviewed | Planned |
| AUD-001 | Auditor reads within approved scope | API | Only approved scope returned | Blocked: scope approval |
| AUD-002 | Auditor global access without explicit grant | API | Denied | Planned |
| ARC-001 | Auditor records manual Excel archive | API/UI | Ledger entry recorded; no file/data migration | Planned |
| ARC-002 | Duplicate archive confirmation | API | Duplicate prevented or flagged | Planned |
| ARC-003 | Monthly missing/archive report | API/UI | Counts reconcile to source register | Planned |
| UI-001 | Shared sidebar and route selection | Angular/Flutter | One consistent navigation shell per client | Planned |
| UI-002 | Loading/empty/error states | Angular/Flutter | All states render safely | Planned |
| EXP-001 | Export respects filters and permissions | API/UI | Export matches authorized filtered set | Planned |
| UTC-001 | UTC-only display and filtering | All | No local-time conversion anywhere | Planned |
| SEC-001 | No privileged database secret in clients | Static/security scan | No service-role/secret exposure | Planned |
| E2E-001 | Hourly submit-review-correct-approve | E2E | Complete audited workflow passes | Planned |
| E2E-002 | Daily submit-review-correct-approve | E2E | Complete audited workflow passes | Planned |
| E2E-003 | Cross-station access denial | E2E | No cross-station data or action | Planned |

## 8. Current implementation baseline and known gaps

Based on the repository's initial workflow and legacy audits:

- Angular currently has a single application shell and shared sidebar.
- Angular routes/features include authentication/registration, dashboard, observations, reports, agricultural, soil, phenomena and user/authority management modules. Exact route inventory must be rechecked against the active branch before final sign-off.
- Flutter has home navigation, station directory and an observation workspace. A widget test currently has a known failure where the observation workspace title is not found after navigation; this remains an open defect until diagnosed and retested.
- The API and migrations have evolved beyond the initial baseline; verify current endpoints and migration files against the active PR before relying on old audit statements.
- The initial legacy workflow inventory explicitly says daily/hourly field rules, complete report types, approval transitions, role matrix and exact schema still require extraction/reconciliation.
- A successful Angular build does not establish full functional parity.
- A successful Flutter analyze does not establish widget or integration correctness.
- A CI green status does not establish production readiness.

### 8.1 Known open blockers

1. Diagnose and fix the Flutter observation workspace widget test.
2. Complete the exact page/route inventory for both clients and reconcile duplicate or legacy-only screens.
3. Finish the hourly and daily field catalogue with units, constraints, missing markers and UTC period rules.
4. Approve review/return/reject/approve transitions and role grants.
5. Resolve auditor scope explicitly; global/national scope must not be inferred.
6. Complete atomic/fail-closed station authorization and cross-station tests.
7. Approve database schema and migration plan before applying any database changes.
8. Implement and test the manual archive confirmation ledger and monthly report.
9. Complete full Angular, Flutter, .NET and end-to-end regression suites.
10. Verify production host, secrets, CORS, health/readiness and operational backup/recovery before deployment.

## 9. Delivery gates

A phase is complete only when its evidence is recorded.

| Gate | Acceptance evidence | Cannot pass if |
|---|---|---|
| G1 — Inventory | Every page/route/module has ID, owner, role boundary, field/action list and source reference | Unmapped legacy page or unclassified route remains |
| G2 — Domain rules | Approved field catalogue and workflow transition matrix | Numeric rules or missing markers are guessed |
| G3 — API contract | Versioned request/response schemas and backend validation tests | Client is authoritative for validation |
| G4 — Security | Role/assignment matrix approved; negative isolation tests pass | Global auditor access or station scope is ambiguous |
| G5 — Database | Reviewed schema, migration plan, rollback and explicit owner approval | Any unapproved database write/migration |
| G6 — Client parity | Angular and Flutter page/action/state tests pass | Screen exists but required action is nonfunctional |
| G7 — Archive/reporting | Manual archive ledger and monthly report reconcile | App writes/transfers archive data automatically |
| G8 — Release | Full CI, E2E, security, deployment smoke and recovery evidence | Critical/high unresolved issue or unapproved release |

## 10. Execution order and round tracking

The sequence below is a planning baseline, not a promise that each round will take one conversation. A round may repeat when tests reveal defects.

| Round | Work package | Exit evidence |
|---:|---|---|
| 01 | Freeze source inventory and branch baseline | Versioned file/route inventory |
| 02 | Map every Angular route and screen | Route-to-page register |
| 03 | Map every Flutter screen and navigation path | Screen-to-page register |
| 04 | Reconcile legacy screens to target pages | Parity matrix and exclusions |
| 05 | Complete sign-in/registration/profile specs | Identity page acceptance tests |
| 06 | Complete station directory/assignment specs | Station page and isolation tests |
| 07 | Complete hourly page and field inventory | Approved hourly catalogue |
| 08 | Complete daily page and field inventory | Approved daily catalogue |
| 09 | Complete review/audit workflows | Approved transition matrix |
| 10 | Complete reports and specialist module inventory | Report/module catalogue |
| 11 | Complete management, archive and monthly report specs | Archive/report acceptance rules |
| 12 | Complete role/permission matrix | Owner-approved grants |
| 13 | Finalize API contracts | Contract tests |
| 14 | Implement backend validation/use cases | Unit and integration tests |
| 15 | Review proposed database schema | Written schema approval |
| 16 | Apply approved schema only to new target | Migration/rollback evidence |
| 17 | Implement audit history and archive ledger | Persistence and audit tests |
| 18 | Complete Angular page workflows | Angular unit/component/e2e tests |
| 19 | Complete Flutter page workflows | Flutter widget/integration tests |
| 20 | Connect clients to API contracts | Contract and end-to-end tests |
| 21 | Complete station isolation and authorization | Negative security suite |
| 22 | Complete exports and monthly reports | Reconciliation evidence |
| 23 | Accessibility, RTL and responsive review | UI acceptance record |
| 24 | Dependency/supply-chain security review | Advisory/license report |
| 25 | Performance and reliability checks | Load/error/retry evidence |
| 26 | Full regression across three applications | Green required CI matrix |
| 27 | Production configuration and smoke test | HTTPS/health/readiness evidence |
| 28 | Backup/restore and operational runbook | Restore drill evidence |
| 29 | Owner acceptance review | Signed acceptance checklist |
| 30 | Release approval and controlled handover | Explicit release authorization |

## 11. Source references to maintain

- `docs/architecture/WORKFLOW-INVENTORY.md` — initial observed workflow inventory.
- `docs/architecture/LEGACY-AUDIT.md` — initial legacy responsibility/security audit.
- `README.md` — application boundaries, setup and current verification notes.
- `docs/security/` — role, authorization and security audits.
- `docs/api/` — API contracts and endpoint documentation.
- `docs/data-quality/` — station catalogue/data-quality evidence.
- `angular-app/src/app/app.routes.ts` — web route source of truth.
- `flutter-app/lib/` — mobile page/navigation source.
- `backend/` and `supabase/` — API, tests and proposed database artifacts.

Update this document whenever a page is added, removed, renamed or changes access/workflow behavior. Every change must include its test IDs and evidence. Do not mark an item verified merely because a source file exists.

## 12. Owner decisions required before final specification approval

- Confirm complete hourly and daily field lists, labels, units, precision, allowed values and missing markers.
- Confirm exact UTC reporting period boundaries for daily observations.
- Confirm allowed hourly/daily workflow states and transition permissions.
- Confirm each role's permissions and station scope, especially whether any auditor has national/global access.
- Confirm which specialist modules (agriculture, rainfall, soil, climate, phenomena) are in the first production release versus later phases.
- Confirm required export formats and monthly report calculations.
- Confirm the manual archive ledger metadata fields and who may edit/confirm/reopen an entry.
- Review and approve the new database schema and migration plan before any database change.

**Completion definition:** METRA 2027 is complete only when every approved page and workflow in this register is implemented in the required clients, all corresponding automated and manual acceptance tests pass, security scope is verified server-side, and the owner approves the release.

## Flutter source path clarification — 2026-11-11 UTC

The canonical Flutter client source is `flutter-app/`. The former `mobile/metra_mobile/` tree is retained as a temporary read-only reference; see `mobile/metra_mobile/README.md`, `flutter-app/README.md`, `.github/workflows/client-ci.yml`, and `docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md`. Do not merge or delete the reference tree without a separate diff/history review.
