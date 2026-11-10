**Master plan:** `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-MASTER-PLAN.md`

**خطة الإكمال المركزية:** `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-AND-COMPLETION-PLAN.md`

# METRA 2027 — Page implementation status (live repository audit)

**Audited tip:** `b069f648031c33aed478e20e11e9f3055f27eed9`  
**Spec source:** `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`  
**Method:** route/feature/API inventory in repo (not prior chat reports)  
**Legend:** `Done` = wired to backend and usable · `Partial` = UI and/or API incomplete · `Missing` = no real route/workflow · `Scaffold` = page exists without authoritative API data

| Spec ID | Page | Angular | Flutter | Backend API | Notes |
|---|---|---|---|---|---|
| AC-01 Login | تسجيل الدخول | Partial | Partial | Auth via Supabase JWT | Exists; not full session matrix |
| AC-02 Registration | طلب تسجيل | Partial | Missing | Yes (registration endpoints) | Angular registration present |
| AC-03 Registration review | مراجعة الطلبات | Partial | Missing | Yes | Angular UI at `/admin/registration-review` wired to API |
| AC-04 Password recovery | استعادة كلمة المرور | Missing | Missing | External/Supabase | Not found as app page |
| AC-05 Profile | الملف الشخصي | Missing | Missing | TBD | Not found |
| AC-06 User management | إدارة المستخدمين | Scaffold | Missing | Partial | Static role list only |
| AC-07 Roles/permissions | الأدوار والصلاحيات | Scaffold | Missing | Partial | Labels only; server grants exist |
| AC-08 Station assignment | تعيين المحطات | Done | Missing | Yes | request / pending decide / revoke UI |
| ST-01 Station directory | دليل المحطات | Done | Partial | Yes `GET /api/v1/stations` | Angular `/stations` + links to detail |
| ST-02 Station detail | تفاصيل المحطة | Done | Missing | Partial (from directory list) | Angular `/stations/:stationId` |
| ST-03 Station status | حالة المحطة | Partial | Partial | Partial | observation-status route |
| HR-01 Hourly entry | إدخال ساعي | Done | Done | Yes | UTC; offline queue Angular |
| HR-02 Hourly list | قائمة ساعية | Partial | Partial | Partial | Local/offline-oriented |
| HR-03 Hourly detail | تفاصيل | Partial | Partial | Partial | |
| HR-04 Hourly review queue | طابور التدقيق | Done | Done | Yes | workflow filter + Flutter review |
| HR-05 Decision | اعتماد/إرجاع | Done | Done | Yes | detail + return note + SoD |
| DY-01 Daily entry | إدخال يومي | Done | Done | Yes | 24h / 06utc / 18utc types |
| DY-02–05 Daily list/review | يومي | Done | Done | Yes | shared review queue with type filter |
| AD-* Auditor workspace | مساحة المدقق | Partial | Missing | Partial | No monthly archive confirmation page |
| RP-03..10 Specialist reports | شهري/سنوي/مناخ/مطر/زراعة/تربة/ظواهر | Scaffold/Partial | Missing | Missing/Partial | climate/monthly/annual/users scaffolds |
| OP Maintenance/Support | أعطال/دعم | Partial | Partial | Yes | Station-scoped |

## Constraints verified in code comments / docs
- UTC-only requirement documented in spec and observation contracts.
- 06/18 UTC treated as hourly bulletin times in daily vs hourly product rules (spec).
- No archive DB connection mandated; not introduced.
- No legacy DB writes in this branch work.
- DB migrations require owner approval before apply.

## Next implementation priority (no DB apply)
1. Station detail + assignment UI on existing APIs  
2. Registration review UI  
3. Auditor archive confirmation (manual Excel) page without auto-migration  
4. Replace report scaffolds with API-backed lists only when endpoints exist  
5. Password recovery / profile after identity product decision


## Phase A closure notes (admin + stations)
- Registration review UI: `/admin/registration-review`
- Station assignment UI with pending decisions: `/admin/station-assignments`
- Station directory + detail: `/stations`, `/stations/:stationId`
- Password recovery / profile remain product decisions (Supabase Auth); not invented as custom pages without owner rule set
- Flutter admin parity still open


## Phase B closure notes (observation cycle)
- Angular `/observations/workflow`: type filter (hourly/daily), detail panel, UTC-only timestamps, approve/return/resubmit.
- Hourly/daily entry pages link into the review workflow with station context.
- Flutter review queue shows UTC (not device local time).
- Server remains authoritative for decisions and station scope.


## Phase C closure notes (manual Excel archive ledger)
- API: `GET/POST /api/v1/stations/{stationId}/archive-confirmations`, monthly summary endpoint.
- Permissions: `archive.read`, `archive.confirm` (fail closed).
- UI: `/admin/manual-archive` — records confirmation only; no archive DB connection; no observation data migration.
- Persistence: process-local interim ledger until owner approves durable migration (`20261110180000_manual_archive_ledger_review_only.sql` is review placeholder only).
- Monthly summary counts confirmations only; full missing-field meteorology formulas remain TBD.


## Phase D notes (reports — partial, honest)
- Monthly report page now binds to **manual archive confirmation** API + station directory (administrative only).
- Station observation status uses review/returned queues with UTC display and hourly/daily counts.
- Climate / annual / rainfall remain **not data-bound** for meteorological aggregates until formulas and report APIs are approved.
- No fabricated observation totals are shown as real data.


### Phase D continuation
- Climate and annual pages converted to **honest unbound shells** with real station picker and links to live observation/archive flows.
- No fabricated climate totals.
- Rainfall remains preview-only until rainfall contract is approved.


## Phase E — database approval package
- Document: `docs/security/phase-e-database-approval-package.md`
- Archive SQL remains review-only / not applied.
- No hosted Supabase apply performed in this phase.
- Owner decision form included before any migration execution.


## Phase F — UX shell
- Angular sidebar regrouped (رصد / مراجعة / تقارير / إدارة محطة / صيانة).
- Admin station links shown only when authenticated session present (UX only; API still enforces).
- Shared `.metra-state-*` CSS tokens for loading/empty/error/ok/warn.
- Flutter `MaterialApp` forced RTL + `locale: ar`.


## Phase G — security tests
- Added `ManualArchiveStationAuthorizationTests` for cross-station archive isolation.
- Coverage matrix: `docs/security/phase-g-security-test-coverage.md`
- No SQL applied; no PR merge.


## Phase H — delivery package
- See `docs/operations/phase-h-delivery-package.md`
- Staging/production and PR merge remain owner-gated

## Continuation batch (C durable path + D inventory + Flutter archive)
- Npgsql manual archive ledger adapter (activated by MetraOps; table apply still Phase E).
- Expanded in-memory list/summary/station isolation tests.
- Flutter `ManualArchiveScreen` + API client methods.
- Report inventory: `docs/progress/phase-d-report-inventory.md`


## Flutter admin parity
- Registration review screen (station + system stages) wired to live API.
- Station assignment request/decision/revoke wired to live API.
- Linked from station ops hub with station scope.


## Final honest UI pass
- Soil and agriculture converted to unbound shells (no fake save).
- Flutter reports hub: observation status + archive monthly path.
- Completion boundary: `docs/operations/PROJECT-COMPLETION-BOUNDARY.md`


## Phenomena
- Backend accepts `observationType: phenomenon` and exposes `/api/v1/observations/phenomena/validate`.
- Angular phenomena input requires station UUID and submits to live API on stop (no silent local success).


## Electronic Auditor (المدقق الإلكتروني)

| Spec ID | Page | Angular | Flutter | Backend API | Notes |
|---|---|---|---|---|---|
| EA-01 Case list/create | سجل تدقيق إلكتروني | Missing | Missing | Missing | Design only: `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md` |
| EA-02 Chart upload & quality | رفع المخطط | Missing | Missing | Missing | Original image immutable policy |
| EA-03 Calibration & extract | معايرة واستخراج | Missing | Missing | Missing | No accuracy claim without reference set |
| EA-04 Compare & engines | مقارنة ومحركات | Missing | Missing | Missing | Must not mutate observations |
| EA-05 Decision & report | قرار وتقرير | Missing | Missing | Missing | Separate permissions from observer roles |

**Inventory date:** 2026-11-10 UTC — Phase 0 master plan published; no SQL applied; no main merge.

## Intelligent Audit program (AI)

**Spec:** `docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md`

| Area | Status |
|---|---|
| Formal requirements | Documented (IA-0) |
| Paper register track | Not implemented |
| Mechanical chart track | Design only |
| Training laboratory | Not implemented |
| Triple-source engine | Not implemented |
| Angular UI | Scaffold `/electronic-auditor` only |
| Flutter capture | Not implemented |
| Production models | None |
