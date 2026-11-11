# METRA 2027 — Final Implementation Master Plan

**Document type:** Phase 0 inventory + execution roadmap to delivery  
**Repository:** `gfa437926-tech/metra2027`  
**Working branch:** `work/legacy-ui-migration-audit`  
**Audited tip:** `b069f648031c33aed478e20e11e9f3055f27eed9`  
**Audit date (UTC):** 2026-11-10  
**Method:** Live tree + routes + endpoints + docs on branch (not prior chat claims)  
**Constraints (non-negotiable):**
- No changes to `metra-old` or legacy database
- No SQL / Migrations / RLS / Seeds applied to Supabase without explicit owner approval
- No merge to `main` without owner approval
- UTC only for observation and report times
- No invented observation values, coordinates, or instrument charts
- Fail-closed station authorization on the server

---

## 1) Application topology (verified)

| App | Path | Notes |
|---|---|---|
| Angular web | `angular-app/` | Primary web UI; routes in `app.routes.ts` |
| Flutter (CI path) | `mobile/metra_mobile/` | Screens used by Client CI |
| Flutter (forecasting scaffold) | `flutter-app/lib/features/forecasting/` | Secondary path — **must unify before delivery** |
| Backend | `backend/Metra.Api/` | ASP.NET Core minimal APIs |
| SQL (review / not auto-applied) | `supabase/migrations/` | Owner-gated |
| Contracts & delivery docs | `docs/` | Specs, security, progress |

**Decision required (owner):** Designate **one** Flutter source of truth (`mobile/metra_mobile` recommended) and fold `flutter-app` forecasting into it.

---

## 2) Angular route inventory (from `app.routes.ts`)

| Route | Component | Status class |
|---|---|---|
| `/login` | LoginComponent | Partial (auth exists; full session matrix incomplete) |
| `/register` | RegistrationComponent | Partial |
| `/` | DashboardComponent | Partial (summary depends on available APIs) |
| `/stations` | StationDirectoryComponent | Done (API-backed) |
| `/stations/:stationId` | StationDetailComponent | Done / Partial detail depth |
| `/observations/workflow` | ObservationWorkflowComponent | Done (review/decide/return/resubmit) |
| `/phenomena` | PhenomenaComponent | Partial |
| `/phenomena/input` | PhenomenaInputComponent | Partial→wired on submit |
| `/equipment-faults` | EquipmentFaultWorkflowComponent | Partial (API yes) |
| `/support-incidents` | SupportIncidentWorkflowComponent | Partial (API yes) |
| `/admin/registration-review` | RegistrationReviewComponent | Partial / wired |
| `/admin/station-assignments` | StationAssignmentComponent | Done |
| `/admin/manual-archive` | ManualArchiveComponent | Done (ledger; durable DB owner-gated) |
| `/forecasting` | ForecastingCenterComponent | Partial (catalogue + geo compare; snapshot read not production) |
| `/reports/hourly` | HourlyReportsComponent | Scaffold / Partial |
| `/reports/daily` | DailyReportsComponent | Scaffold / Partial |
| `/reports/monthly` | MonthlyReportsComponent | Partial (archive admin path) |
| `/reports/annual` | AnnualReportsComponent | Scaffold (honest unbound) |
| `/reports/climate` | ClimateReportsComponent | Scaffold (honest unbound) |
| `/reports/rainfall` | RainfallReportsComponent | Scaffold / preview |
| `/reports/observation-status` | StationObservationStatusComponent | Partial |
| `/agriculture` | AgricultureComponent | Scaffold unbound |
| `/soil-temperature` | SoilTemperatureComponent | Scaffold unbound |
| `/users` | UsersComponent | Scaffold |
| (no route) | Password recovery / Profile | Missing as app pages |
| (no route) | **Electronic Auditor** | **Missing — planned module** |

---

## 3) Flutter screen inventory (`mobile/metra_mobile`)

| Screen | Path | Status |
|---|---|---|
| Home / nav | `features/home/metra_home.dart` | Partial hub |
| Station directory | `features/stations/station_directory_screen.dart` | Partial |
| Observation submit | `features/observations/observation_submit_screen.dart` | Done (hourly/daily contracts) |
| Observation review | `features/observations/observation_review_screen.dart` | Done |
| Returned editor | `features/observations/returned_observation_editor.dart` | Done |
| Equipment faults | `features/maintenance/equipment_fault_screen.dart` | Partial |
| Maintenance report | `features/maintenance/maintenance_report_screen.dart` | Partial |
| Support incidents | `features/support/support_incident_screen.dart` | Partial |
| Station ops hub | `features/ops/station_ops_hub_screen.dart` | Partial (admin links) |
| Forecasting | `flutter-app/.../forecasting_center_screen.dart` only | **Not in mobile path** |
| Manual archive / registration / assignment | via ops hub + client | Partial |
| Electronic Auditor | — | **Missing** |

---

## 4) Backend feature inventory (endpoints / domain)

| Area | Key types | Status |
|---|---|---|
| Auth / JWT | Supabase JWT validation | Partial–Done (HS256 path; ES256 transition documented) |
| Stations | StationDirectoryEndpoints, Catalogue review | Done (scoped) |
| Observations submit/validate | Submission, Validation endpoints | Done |
| Observation queue / decision / resubmit / returned | Queue, Decision, Resubmit, Returned | Done + SoD tests |
| Phenomena validate | observationType phenomenon | Partial |
| Equipment faults | EquipmentFaultEndpoints + Npgsql service | Done station-scoped |
| Support incidents | SupportIncidentEndpoints + Npgsql service | Done station-scoped |
| Users / registration / assignment / authority | Registration*, StationAssignment*, AuthorityAccess* | Partial–Done |
| Station user directory / audit | StationUserDirectory, StationAudit | Partial |
| Manual archive ledger | ManualArchive endpoints + in-memory / Npgsql adapter | Done code; table apply gated |
| Forecasting | ForecastingEndpoints (stations + compare) | Partial |
| WeatherObservationSnapshot | Domain DTO + Mapper + unit tests | **Contract + mapper only**; no production read API yet |
| Electronic Auditor | — | **Not started** |
| Climate / annual / rainfall aggregate APIs | — | Missing (no invented totals) |

**Migrations present (files only; apply = owner gate):** operational observations, decision SoD/audit, resubmit, equipment faults, support incidents, ops RLS/session, manual_archive_ledger_review_only.

---

## 5) Spec coverage vs implementation (summary)

Source: `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md` + `docs/progress/PAGE-IMPLEMENTATION-STATUS.md`

| Domain | Done | Partial | Scaffold / Missing |
|---|---|---|---|
| Accounts & auth | Login/register base | Session matrix, recovery, profile | Full profile product |
| Stations | Directory, detail, assignment | Status depth | — |
| Hourly / daily cycle | Entry, review, decide, return, resubmit | Lists/history depth | — |
| Phenomena | API validate + Angular input | Flutter parity | Full list UX |
| Maintenance / support | API + UI workflows | Flutter polish, RLS proof on live DB | — |
| Reports | Observation status, monthly archive admin | Hourly/daily report UX | Climate/annual/rainfall aggregates |
| Forecasting | UI shell + geo compare + snapshot contract | Live snapshot feed | External adapter |
| Admin users/roles | Assignment, registration review | Full user CRUD UI | Roles matrix UI |
| Electronic Auditor | — | — | **Entire module** |
| DB production apply | Files ready for review | — | Owner approval |
| Staging / production | Docs only | — | Secrets + host |

---

## 6) New module: Electronic Auditor (المدقق الإلكتروني)

**Status:** Design only in this commit — **no SQL applied**, no OCR accuracy claims.

### 6.1 Goal
Digitize mechanical recorder paper charts, extract time-series values, compare against METRA electronic observations, run physical and mathematical validation engines, produce an immutable audit outcome **without auto-mutating original observations**.

### 6.2 Instrument types (support list — specifications TBD from owner catalogue)
- Thermograph  
- Hygrograph  
- Barograph  
- Pluviograph  
- Additional mechanical recorders only when listed in the approved instrument catalogue (no invented models)

### 6.3 Workflow (logical)
1. Create audit case (station, instrument type, serial, chart period UTC)  
2. Upload original chart image (store original bytes + content hash)  
3. Quality check (resolution, contrast, completeness flags)  
4. Optional geometric correction (deskew/perspective) — **derived asset only; original retained**  
5. Axis / scale / calibration point definition  
6. Curve extraction → discrete (time UTC, value) samples  
7. Human review of extracted samples  
8. Fetch corresponding electronic METRA values (station-scoped, authorized)  
9. Diff + uncertainty  
10. Physical validation engine (instrument-specific rules with versioned references)  
11. Mathematical validation engine (consistency, rate-of-change, unit bounds with references)  
12. Record differences, auditor notes, decision  
13. Emit report; **never auto-write over observation payload** without a separate authorized correction procedure

### 6.4 Permissions (separate from observer / station chief)
Proposed permission codes (names only until owner approval):
- `electronic_auditor.case.read`
- `electronic_auditor.case.create`
- `electronic_auditor.image.upload`
- `electronic_auditor.extract.run`
- `electronic_auditor.compare.run`
- `electronic_auditor.decide`
- `electronic_auditor.report.read`

Read-only forecasting/view roles **do not** imply auditor decide rights.

### 6.5 Data (proposed — **not applied**)
Logical entities for later schema review package:
- `electronic_audit_case`
- `electronic_audit_image` (original + processed derivatives, sha256, uploaded_by, uploaded_at_utc)
- `electronic_audit_calibration`
- `electronic_audit_extracted_series`
- `electronic_audit_comparison`
- `electronic_audit_engine_result`
- `electronic_audit_decision` + append-only `electronic_audit_events`

All station-scoped; fail closed; original images non-deletable by app roles.

### 6.6 Clients
- **Angular:** primary auditor workstation (image tools, tables, decisions)  
- **Flutter:** optional field review of cases (not full calibration workstation)  
- **Backend:** case API, authorization, comparison against observation store  
- **Image service:** OpenCV-based worker (separate process); no service-role keys in clients  

### 6.7 Acceptance for claiming OCR accuracy
Forbidden until independent human reference chart set is provided and measured. Until then: “extraction pipeline scaffold” only.

Design detail: `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md`

---

## 7) Execution roadmap (aligned with owner 0–17 phases)

| Phase | Focus | Gate |
|---|---|---|
| 0 | This master inventory | Doc complete on branch |
| 1 | Contracts (snapshot, pending units, auditor data contract) | Owner review of contracts |
| 2 | Backend APIs (snapshot read policy, auditor APIs as approved) | API tests green; no DB apply |
| 3 | Database package | **Owner SQL approval** then apply only new DB |
| 4–6 | Angular completeness (auth, stations, observations, roles) | Per-page acceptance |
| 7 | Forecasting live snapshot + parity | Snapshot policy decision |
| 8 | Reports/maps only with real sources | No fake aggregates |
| 9 | Flutter unification + parity | Single tree; CI green |
| 10–11 | Integration + notifications | E2E scenarios |
| 12–14 | Security, performance, full E2E | Isolation tests proven |
| 15–17 | Defect closure, staging, delivery pack | Owner merge/publish |

**Electronic Auditor** inserts after Phase 1 contracts and runs in parallel with Phases 2–7 (design → scaffold UI → image worker → gated schema).

---

## 8) Open owner decisions (blockers)

1. Flutter canonical path: `mobile/metra_mobile` vs `flutter-app`  
2. Snapshot `receivedAtUtc` mapping (`submitted_at` vs `created_at`)  
3. Snapshot read policy: all authenticated activated accounts vs station permission  
4. Freshness thresholds by station type  
5. Apply which migrations to new Supabase (list in security package)  
6. Instrument catalogue + chart scale specs for Electronic Auditor  
7. Whether Flutter needs full auditor workstation or read-only case list  

---

## 9) Explicit non-goals until approved

- Applying any migration  
- Merging PR #11 / #13 / others to `main`  
- Connecting to or modifying legacy DB  
- Claiming electronic auditor measurement accuracy  
- Fabricating climate/rainfall totals  

---

## 10) Progress snapshot (honest, evidence-based)

| Layer | Estimate | Basis |
|---|---|---|
| Backend observation/ops core | ~75–85% | Endpoints + tests on branch |
| Angular operational pages | ~65–75% | Routes wired; reports mostly scaffolds |
| Flutter operational pages | ~55–70% | Submit/review strong; admin/forecasting gaps |
| Forecasting module | ~35–45% | UI + geo + contract; no live snapshot API |
| Electronic Auditor | ~5% | Design only |
| Database applied in production | Unknown / gated | Files exist; apply not verified here |
| Staging / production delivery | ~15–25% | Docs; host/secrets pending |
| **Overall operational delivery** | **~60–70%** | Not acceptance-complete |

Estimates are engineering judgment from inventory, **not** a formal acceptance certificate.

---

## 11) Immediate next commits (safe, no SQL apply)

1. Keep snapshot contract + mapper tests green  
2. Implement snapshot **read** endpoint only after owner picks read policy (or behind feature flag returning structured 501 with contract ref)  
3. Angular/Flutter: show “no data” honestly in forecasting when snapshot API absent  
4. Electronic Auditor: design doc + permission names + empty Angular route shell labeled scaffold  
5. Unify Flutter forecasting into `mobile/metra_mobile`  
6. Expand station-isolation tests for any new read paths  

---

## 12) Related documents

- `docs/progress/PAGE-IMPLEMENTATION-STATUS.md`  
- `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-AND-COMPLETION-PLAN.md`  
- `docs/contracts/WEATHER-OBSERVATION-SNAPSHOT-CONTRACT-V1.md`  
- `docs/features/WEATHER-FORECASTING-CENTER.md`  
- `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md`  
- `docs/security/DATABASE-REVIEW-PACKAGE-FOR-OWNER-APPROVAL.md`  
- `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`  

**End of Phase 0 master plan.**

---

## Addendum — Intelligent Audit program (AI paper + mechanical)

**Formal specification:** `docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md`

Program scope beyond single-chart digitization:
- Track A: official paper station registers (page OCR / document understanding)
- Track B: mechanical recorder charts (curve digitization)
- Triple-source compare: paper ↔ mechanical ↔ electronic METRA
- Controlled AI training laboratory (human-approved labels only)
- Offline extraction without station connectivity; electronic match optional

**Status:** Specification + Angular structural scaffold only. No production models, no SQL apply, no accuracy claims.

**Phased codes:** IA-0 (spec) → IA-10 (acceptance). Prefer manual-digitization MVP (IA-3/IA-4) before any model promotion.
