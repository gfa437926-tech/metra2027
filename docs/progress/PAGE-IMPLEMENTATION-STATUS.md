**Master plan:** `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-MASTER-PLAN.md`

**خطة الإكمال المركزية:** `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-AND-COMPLETION-PLAN.md`

# METRA 2027 — Page implementation status (live repository audit)

**Historical inventory tip:** `b069f648031c33aed478e20e11e9f3055f27eed9`  
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


---

## Flutter-first continuation — 2026-11-11 UTC

The detailed requirements-based mobile audit supersedes older top-level Flutter status labels where they conflict:
- docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md
- Canonical Flutter source: flutter-app/ (confirmed by its README, mobile/metra_mobile/README.md, and Client CI working directory).
- mobile/metra_mobile/ is a temporary reference tree, not the canonical build path.
- Forecasting Center was added to shared five-destination mobile navigation; secondary review/operations/account actions are grouped under “المزيد”.
- Regression test added for Forecasting navigation and the explicit no-live-snapshot state.
- Code commit: 3250acbad7f337f8d59f736a7d80c089963d316c.
- Client CI #808 was cancelled by subsequent branch updates. The latest observed Client CI run is #810 for the current Flutter code commit and was pending at 2026-11-11 13:23 UTC; do not mark it passed until its conclusion is successful.
- Flutter remains incomplete: registration request, recovery, profile, station detail, hourly/daily list/detail/history, phenomena, specialist reports, agriculture, soil, complete auditor workspace and live forecasting snapshots remain open or contract-blocked.

No SQL was applied, no main merge was performed, and metra-old was not modified.


## Flutter identity/account continuation — 2026-11-11 UTC

- FLT-AUTH-02: password recovery page added and linked from login using Supabase Auth resetPasswordForEmail. Success feedback is privacy-safe and does not reveal whether an account exists.
- FLT-ACCOUNT-01: account profile page added; shows authenticated email and explains that permissions are server-authoritative; sign-out requires confirmation.
- Widget tests added for recovery validation/privacy/error redaction and profile/sign-out confirmation.
- Detailed evidence and remaining gaps: docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md
- Current source tip before this status update: 4219b5d5492de6325dccc50f0ad24184abd48041.
- Verification: pending a completed Client CI run for the latest tip; Client CI #811 success applies only to the earlier baseline.


## Flutter station-detail continuation — 2026-11-11 UTC

- FLT-STATION-DETAIL-01: catalogue detail screen implemented and reachable from station map markers and directory list cards.
- Displays only fields present in the approved station-directory response; unavailable coordinates/WMO IDs are not invented, and catalogue metadata is clearly not live weather.
- Added station-detail widget test and directory navigation assertions.
- Evidence: docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md
- Source commits: 88d95df775b11b29399ce535e8c732bbdc313c2f and eb92c0dc77f7a615486aae83bbdaecfdab9ab4a3.
- Tests commits: abee1bbfb3480b8d4d250a9e2424bb8bfc29bdfb and 3431b93c4498edee6899ad7ff241e7db0032c1d4.
- Automated verification pending a completed Client CI run on the latest source tip.


## Flutter CI correction — 2026-11-11 UTC

- Client CI #823 failed in Flutter analyze on one unused legacy parameter in the home helper after the profile page refactor.
- Corrective source commit: a75bc36add6d7e3609eb84aa78b45f1faaabfe1f.
- Root cause and evidence are recorded in docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md.
- A fresh Client CI run #824 was triggered for the fix; status must be checked before marking the new screens verified.


## Flutter analyzer follow-up — 2026-11-11 UTC

- Client CI #824 failed again because the underlying _StatusCard retained an unused optional action parameter after the first correction.
- Second corrective commit: 416539c774d58d545010079c7d9ab47b9c48d4b3 removes that stale parameter and branch.
- Both analyzer findings and correction history are documented in docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md.
- New Client CI verification for this correction is required; the earlier #823 and #824 runs are failures, not passes.


## Flutter Client CI #829 correction — 2026-11-11T13:37:38.156Z

- Task FLT-QUALITY-03: **قيد التنفيذ** — Flutter analyzer passed; Flutter widget tests reported 44 passed / 2 failed.
- Both failures were stale expectations for a bare station code; the UI renders the code with its visible label. Test assertions were corrected without weakening product behavior.
- Test commits: `c8213830edba2e0fafa6cacfa1e89313bb08ef3c`, `381eafab46153ac1d9d84248925f478f98a20470`.
- Client CI #829 Angular job passed including 3 Chromium PWA smoke runs; Flutter job failed only at `flutter test` after `flutter analyze` passed.
- Exact-head rerun is pending; Flutter verification remains open.
- Detailed evidence: `docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md`.
- No database changes, no legacy DB access, no PR merge.


## Flutter registration screen — 2026-11-11T14:06:21.913Z

- FLT-AUTH-03 status: **منجزة ضمن Flutter ومتحقق منها**.
- Added two-stage identity creation + institutional registration request/status flow; station and role choices are server sourced and server permissions remain authoritative.
- Flutter Client CI #43034587973 passed: analyze success, 48 tests passed. Source SHA: `39452b0ada03dffb536773dbca59c5786e3e93b4`.
- Evidence and failure/correction history: `docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md`.


## Flutter registration lifecycle — 2026-11-11T14:07:16.205Z

- FLT-AUTH-03: **منجزة ومتحقق منها**.
- Added identity creation + server-driven station/role request + approval-status tracking, linked from login and the shared menu.
- Client CI #43034587973: Flutter analyze passed and **48 Flutter tests passed**. Source SHA `39452b0ada03dffb536773dbca59c5786e3e93b4`.
- Detailed evidence: `docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md`.


## FLT-FORECAST-UI-01 — Forecasting centre station map — 2026-11-11T14:11:00Z

- Task status: **implemented baseline; exact-head CI verification pending**.
- Added an interactive catalogue map to `flutter-app/lib/features/forecasting/forecasting_center_screen.dart` using the existing `flutter_map` / `latlong2` dependencies.
- Only validated coordinates from the current approved station-directory API are plotted. Stations with missing/invalid coordinates remain visible in the station list and are explicitly counted; no coordinates or weather readings are fabricated.
- Map markers toggle station selection; selected stations can be compared by great-circle distance and elevation difference. The comparison is geographic metadata only and is not described as a meteorological correlation.
- Kept the live-observation boundary explicit: temperature, wind, rainfall and bulletin details remain unavailable until an approved live snapshot/bulletin API contract exists.
- Added `flutter-app/test/forecasting_center_screen_test.dart` covering catalogue map availability, station selection, geographic comparison and elevation delta.
- Source commit: `59cec32c4a37bbb921e87ba6e83f59d6549a91f1`.
- Widget test commit: `e59d272a0448b3d97cbabd218be1d09c46a7b8a7`.
- Current PR #11 head: `e59d272a0448b3d97cbabd218be1d09c46a7b8a7`. No workflow run was returned for this exact SHA at the time of this note.
- Client CI #861 (`43036054744`) was pending for the prior head `4af504672a1d1fc45839a2d33558f5960ad9b31c`; it cannot verify these newer commits.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-FORECAST-UI-01 verification update — 2026-11-11T14:14:00Z

- Client CI #865: Flutter analyze failed on unsupported test viewport setter methods; Flutter tests skipped. This is a failed CI run, not a pass.
- Test corrected in `0d8bc257451d1266faef827848b355cbedba92f4` to use supported TestFlutterView properties and synchronous reset methods.
- Exact-head verification pending; map and comparison remain unverified until Client CI succeeds.
- Full evidence: `docs/progress/FLUTTER-COMPLETION-AUDIT-2026-11-11.md`.


## FLT-FORECAST-UI-01 — CI #869 regression correction — 2026-11-11T14:16:00Z

- Client CI #869 (run `43036619447`) checked the map implementation and widget test.
- `flutter analyze` passed. Flutter tests: **51 passed, 1 failed**.
- The new `forecasting_center_screen_test.dart` passed, including map rendering, selection and distance/elevation comparison.
- The only failing test was the existing home-navigation assertion in `widget_test.dart`, which still expected the old explanatory copy `قيم الرصد اللحظية غير متاحة`; the forecasting screen now uses the more explicit phrase `قيم الرصد اللحظية وتفاصيل النشرات لا تُعرض...`.
- Corrected the assertion to match the current UI copy in commit `1945fb8857ef940526e8f8bfbfd6674ee6b109b9`. Product behavior was not weakened or changed.
- CI #869 remains a failed run; exact-head verification is pending. Do not mark the forecasting center verified until the rerun passes.
- Separate admin UI test evidence in CI run `43036091374`: Flutter analyze passed and 51 Flutter tests passed on that earlier source snapshot; Angular Chromium smoke was cancelled.


## Flutter-first continuation — forecasting comparison API (2026-11-11 UTC)

- Task: **FLT-FORECAST-API-02** — **Implemented; CI pending**.
- Flutter comparison now calls the documented backend `POST /api/v1/forecasting/compare` contract and displays its pair results rather than calculating distances independently on-device.
- Client validates 2–12 unique station IDs and response shape; authenticated API behavior has focused tests.
- The endpoint currently returns catalogue/geographic comparison only. Meteorological snapshots remain unavailable and are not simulated.
- Commits: `2b612d12fe2ec46115c146eacc72c9232c30ad9d`, `ce1f4b0cb3c3fe0600d9c938575cf7408a04dfa5`, `91c0cf202c441f5a49a4f04bb44a07c32c51bdc7`.
- CI #871: Flutter analyze and tests succeeded; Angular npm tests/build succeeded, but Chromium installation was cancelled. Current integration commits require a fresh complete CI run.


## Canonical Flutter consolidation and account-screen completion — 2026-11-11T16:59:55.309Z

- **Active branch:** `work/flutter-canonical-consolidation`; canonical destination remains `flutter-app/`. Grok's reference source `mobile/metra_mobile/` on `main` is not overwritten or deleted.
- **Source inventory:** every relative source file has a canonical counterpart except `lib/features/forecast_centres/forecast_centre_screen.dart`; its unique geographic calculation was not copied because canonical `forecasting_center_screen.dart` already provides server-side comparison for 2–12 stations, map/search and station profile. The reference screen would be a weaker duplicate.
- **Unique navigation:** responsive shared navigation was copied and integrated into canonical home; compact screens use NavigationBar and wide screens use NavigationRail.
- **Station metadata:** coordinate provenance/accuracy were added to canonical station model, station detail and forecasting profile, with source tests.
- **Account access:** active-only server account-state gate, pending registration routing, blocked/error states, profile registration-status display, authority membership/permission queue/request/review/revoke/audit, registration audit, station assignment expiry/detail/station audit, and password-recovery completion form/deep-link handling have been added.
- **Recovery external gate:** Supabase Additional Redirect URL `metra2027://auth-callback` must be allow-listed and tested using real email links on Android/iOS. See `docs/security/SUPABASE-AUTH-REDIRECT-SETUP.md`.
- **Account audit:** `docs/progress/ACCOUNT-SCREENS-AUDIT.md`; full source-path disposition: `docs/audit/FLUTTER-REFERENCE-PATH-CONSOLIDATION.md`; page matrix and architecture traceability were updated.
- **CI evidence:** run `43063206728` for source SHA `18bc47d8c62148afa6e18d9170e9f3c54a4f3683`: Flutter analyzer passed; widget tests reported 78 passed / 4 failed. Failures were a prematurely completed error future in the test, two registration fixtures/assertions using the old account-state shape, and a self-membership test fixture that did not mirror the JSON catalogue response. Corrections are in `1011ace8`, `b60318c`, and `7850c08`.
- **Current verification:** Client CI run `43063665760` is queued for corrected code SHA `7850c089e30ea08d83519494950b28f0d5bcaf5d`. No green result is claimed yet.
- **Still blocked by missing API contracts:** hourly/daily author history/read models and exports; full electronic audit cases/evidence/OCR workflow; live forecasting snapshots/bulletins; rainfall/climate/agriculture/soil aggregates; AI gateway; isolated Climatol worker; effective current-user access-context and searchable eligible-user directory.
- No database migrations/RLS/grants/seeds were applied, no legacy DB writes, no main merge and no deployment.


# Current authoritative frontend status — 2026-11-11T17:48:59.359Z

**Audited branch:** `work/flutter-canonical-consolidation`  
**Audited tip:** `51ed88afa415072e9e41679f585610e5615b9b5d`  
**Canonical Flutter source:** `flutter-app/`  
**Reference-only source:** `mobile/metra_mobile/`

The older table above is a historical Phase A–H snapshot. The following status supersedes it for the current Flutter-first implementation wave.

| Area | Current Flutter implementation | Current state | Remaining gate |
|---|---|---|---|
| Identity and accounts | Login, registration, active-only account gate, profile status, password recovery, authority membership/permission lifecycle, registration and station audit, assignment details | UI/API workflows implemented; analyzer and tests pass | Effective access-context API, eligible-user search, delegated target/validity UI, Supabase redirect allow-list and device test |
| Stations | Directory, map/search, station detail and coordinate provenance | API-backed baseline | Verify original visual design and all station-history/maintenance fields |
| Hourly/daily/phenomena | Entry, validation, submit, review, return/edit flows | API-backed baseline | Full author history/read models, expanded domain edge-case and concurrency tests |
| Forecasting centre | Map/search, server comparison for 2–12 stations, station profile | Partial | Live weather snapshot, time series and bulletin APIs absent |
| Rainfall/climate/agriculture/soil | Station-scoped specialist forms and local-only previews | UI only | Approved field catalogue, scientific validation and report/write APIs |
| Electronic audit | 8-tab workspace: dashboard, paper register, mechanical charts, comparison, review, library, training, reports | UI only | Case/evidence/file storage/OCR/digitization/comparison/decision APIs |
| AI | 5-tab workspace: overview, analysis, anomalies, reports, governance | UI only | Secure ASP.NET AI Gateway, model registry, provenance, permissions and audit |
| Climatol | Station/variable/period selection, processing pipeline, diagnostics and versions | UI only | Isolated worker, job/result API, immutable dataset/version evidence and approval |
| AFTN | Inbox, outbox, local composer, channel/audit | UI only | Secure AFTN gateway, message templates, routing, delivery receipts and station/centre isolation |
| Reports/export | Report hub and archive/observation status | Partial | Hourly/daily history read models, climate aggregates and PDF/Excel export APIs |
| Role workspace catalogue | Includes station, forecast, AFTN, auditor, audit approver, AI analyst, model manager/approver, Climatol and upload roles | Navigation metadata only | Effective permissions must come from server access-context; labels never grant access |

## CI evidence for exact current code

- Workflow run `43071280050`, commit `51ed88a`: Flutter analyzer passed and **85 tests passed**.
- Angular job: npm tests passed, production build passed, and Chromium PWA/IndexedDB smoke test passed three times.
- CI verifies code/tests, not production identity configuration, real weather feed, physical device behavior, screenshot parity, or external AFTN/AI/Climatol integrations.

## Explicit non-changes

- No migrations, RLS, grants, seeds or schema modifications applied.
- No legacy database access or writes.
- No merge to `main`, no deployment and no deletion of reference source.
- No fabricated weather observations, AI findings, audit totals, climatology or message traffic.
