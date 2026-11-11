# METRA 2027 — FRONTEND Completion Matrix (Flutter)

**Updated (UTC):** 2026-11-11  
**Branch:** `work/flutter-canonical-consolidation`  
**Canonical source (CI):** `flutter-app/` only  
**Reference only:** `mobile/metra_mobile/` (do not develop in parallel)

Acceptance rule: design + functions + real API (when contract exists) + Arabic errors + station scope + tests. Shell ≠ complete. No fabricated weather values.

| ID | Arabic / English | Design | Functions | API | Permissions | Tests | CI | Result |
|---|---|---|---|---|---|---|---|---|
| FLT-AUTH-01 | تسجيل الدخول / Login | جيد | بوابة Supabase | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-AUTH-02 | التسجيل / Registration | جيد | طلب انضمام | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-AUTH-03 | استعادة كلمة المرور / Password recovery | جيد | reset email | مربوط | — | موجود | معلق | قيد العمل |
| FLT-AUTH-04 | الملف الشخصي / Profile | جيد | بريد + حالة الحساب + حالة طلب الانضمام + خروج | `GET /api/v1/account/registration-status` | لا يعرض أدواراً/محطات دون access-context | موجود مصدرّياً | CI معلق | جزئي — ACC-02 مطلوب |
| FLT-AUTH-05 | الصلاحيات UI / Permissions view | جيد | شاشة إدارة عضويات وصلاحيات الجهات: طلب/مراجعة/رفض/إلغاء/سجل تدقيق | Authority access APIs + server checks | لا تستنتج صلاحيات محلية | موجود مصدرّياً | CI معلق | جزئي — access-context وvalidity/user-target UI مطلوبان |
| FLT-AUTH-06 | منع الوصول/انتهاء الجلسة | جيد | بوابة حالة الحساب + شاشة منع الوصول/فشل التحقق + إعادة محاولة/خروج | `GET /api/v1/account/registration-status` | fail-closed؛ لا تعرض مساحة العمل عند حالة غير نشطة أو تعذر التحقق | موجود مصدرّياً | CI معلق | جزئي — اختبار revoked/expired session مطلوب |
| FLT-STN-01 | دليل المحطات / Directory | جيد | قائمة+خريطة+بحث | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-STN-02 | تفاصيل المحطة / Detail | جيد | بيانات الدليل + مصدر الإحداثيات ودقتها | مربوط | لا تمنح تعديل المحطة | موجود مصدرّياً | CI معلق | مواءمة المصدر/الدقة تمت؛ تحقق CI مطلوب |
| FLT-STN-03 | اختيار محطة العمل / Active station | جيد | الرئيسية+تنقل | محلي+API | — | جزئي | معلق | جيد |
| FLT-STN-04 | الإسناد / Assignment | جيد | طلب/قرار/إلغاء | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-OBS-01 | إدخال ساعي / Hourly entry | جيد | عقد+إرسال | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-OBS-02 | إدخال يومي / Daily entry | جيد | 24h/06/18 | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-OBS-03 | الظواهر / Phenomena | جيد | مؤقت+تحقق+إرسال | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-OBS-04 | سجل/تفاصيل نشرة / Log+detail | جيد | من طابور API | مربوط | خادم | جزئي | معلق | قيد العمل (تفاصيل أُضيفت) |
| FLT-REV-01 | طابور المراجعة / Review queue | جيد | فلتر نوع | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-REV-02 | اعتماد/إرجاع / Decide | جيد | قرار+ملاحظة | مربوط | فصل واجبات خادم | موجود | معلق | قيد العمل |
| FLT-REV-03 | تصحيح وإعادة تقديم / Resubmit | جيد | محرر مُرجَع | مربوط | ملكية | موجود | معلق | قيد العمل |
| FLT-OPS-01 | مركز العمليات / Ops hub | جيد | روابط | — | محطة | موجود | معلق | جيد |
| FLT-OPS-02 | أعطال المعدات / Faults | جيد | دورة حالات | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-OPS-03 | الدعم / Support | جيد | دورة حالات | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-OPS-04 | ملخص التشغيل / Summary | جيد | أعداد API | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-OPS-05 | صيانة محلية قديمة / Local maintenance draft | — | مسودة محلية | غير مربوط | — | — | — | غير إنتاج |
| FLT-RPT-01 | حالة النشرات / Observation status | جيد | طوابير | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-RPT-02 | تقارير المحطة / Reports hub | جيد | روابط | جزئي | محطة | جزئي | معلق | جزئي |
| FLT-RPT-03 | تقارير مناخية/مطرية/سنوية | هيكل | غير متاح | غير متاح | — | لا | معلق | محجوبة |
| FLT-FC-01 | مركز التنبؤ / Forecasting | جيد | خريطة+بحث+اختيار+مقارنة خادمية 2–12+ملف محطة+مصدر/دقة الإحداثيات | كتالوج ومقارنة خادمية | قراءة | موجود؛ metadata tests أضيفت | CI معلق | جزئي — الرصد اللحظي محجوب بعقد API |
| FLT-FC-02 | رصد لحظي / Live snapshot | — | غير معروض | عقد غير معتمد | — | لا | — | محجوبة |
| FLT-SPEC-01 | أمطار/مناخ/زراعي/تربة | هيكل | حالة عدم توفر | غير متاح | — | هيكل | معلق | محجوبة |
| FLT-AUD-01 | التدقيق الإلكتروني | هيكل | تصميم فقط | غير متاح | — | هيكل | معلق | محجوبة |
| FLT-AI-01 | الذكاء الاصطناعي | هيكل | بوابة خادم مطلوبة | غير متاح | — | لا | معلق | محجوبة |
| FLT-CLIMATOL-01 | Climatol | هيكل | عامل معزول لاحقاً | غير متاح | — | لا | معلق | محجوبة |

## Phase order (owner plan)
1. Foundation (nav, station, RTL, errors) — in progress  
2. Observation cycle closure — in progress  
3. Stations & ops — in progress  
4. Forecasting (no live values until contract)  
5. Reports & specialist UIs with unavailable states  
6. Electronic audit / AI / Climatol shells → real only after contracts  
7. Flutter acceptance gate + CI  
8. Angular after Flutter acceptance  

## Constraints
No SQL · no legacy DB · no main merge · no publish without approval · UTC only · no fake weather data.


## Review FLT-005 — Forecast-centre path and evidence audit (2026-11-11T16:16:41.107Z)

- **Status:** Review completed; canonical integration gap remains open.
- Grok commits reviewed: `1d3286c` (screen), `bfe0282` (navigation), `6271ce5` (widget test), `a08613f` (formatting fix), `4b894b8` (round report), `6ff6f36` (roadmap).
- The new screen, navigation change and test are committed under `mobile/metra_mobile/`, which is documented as reference-only. The CI Flutter job runs from `flutter-app/`.
- `flutter-app/` already contains a separate `ForecastingCenterScreen` with map/search, station selection, server-side comparison via `compareForecastingStations`, and a station profile sheet. Its API client contains the corresponding comparison/profile methods. The Grok FLT-005 implementation is therefore not a new feature in the canonical source; it is a divergent implementation in the legacy/reference tree.
- The canonical `flutter-app/test/widget_test.dart` contains a navigation smoke test for the existing forecasting centre, but the new two-station fixture/live-feed guard test is only in `mobile/metra_mobile/test/widget_test.dart`.
- CI evidence: combined commit statuses and PR-triggered workflow runs returned empty for the reviewed FLT-005 code commits and roadmap commit. This is **no CI evidence**, not a pass. Workflow configuration currently has `push.branches: [main]` and `pull_request.branches: [main]`; work-branch pushes are not configured to trigger this workflow.
- Scientific guard: the reference implementation explicitly states live observations/bulletins are unavailable and avoids fabricated values. Live snapshot remains blocked pending an approved API contract.
- **Required next action:** reconcile the stronger/reference-only changes into `flutter-app/` deliberately (without copying files blindly), port the comparison test into the canonical test suite, then obtain a CI run on the work branch. Do not delete `mobile/metra_mobile/` until the full source/assets/configuration comparison is complete.
- No Flutter source was modified during this review. No database, migration, RLS, main-branch merge, or deployment changes were made.


## Review FLT-004 — Station metadata path audit (2026-11-11T16:17:13.811Z)

- FLT-004 commits reviewed: `0f6dd68`, `e399ea2`, `5de8d78`, `549b147`, `8e136e3`; delivery report commit `eeb82bd`.
- The metadata parsing enhancement (elevation plus coordinate source/accuracy) and station-details UI/test changes were committed under `mobile/metra_mobile/`, not the canonical `flutter-app/`.
- The canonical station model currently parses `elevation_m` but does not expose `coordinateSource` or `coordinateAccuracyM`; therefore provenance/accuracy parity from FLT-004 is not established in the canonical Flutter app.
- FLT-004 report states implementation and test execution/visual acceptance are pending; no analyzer/test pass is claimed.
- Required action: port only the missing verified provenance/accuracy fields and corresponding details UI/test to canonical Flutter after a source-level reconciliation. Preserve the canonical implementation and do not delete the reference tree prematurely.


## Canonical consolidation round — 2026-11-11T16:28:04.698Z

- Branch: `work/flutter-canonical-consolidation`; this branch was created from `work/legacy-ui-migration-audit` to isolate consolidation work from Grok's current `main` changes.
- Canonical destination: `flutter-app/`; source/reference: `mobile/metra_mobile/` on `main`.
- The canonical tree already contains more complete versions of the API client, auth, home, station directory, observations, maintenance, support, operations and reports than the reference tree. These were preserved; no wholesale overwrite/copy was performed.
- Ported and integrated the unique responsive navigation widget into the canonical home shell.
- Ported FLT-004 station coordinate provenance and accuracy into the canonical API model, station detail screen and forecasting station profile.
- Account profile now reads the existing server registration-status projection and displays account state, registration stage, review note and UTC submission time. It does not invent role or station assignments.
- Added source tests for responsive navigation, coordinate provenance parsing/detail display, and account status/error handling. **Not executed**: no Flutter SDK is available in this execution environment.
- Forecast-centre implementation in canonical is retained because it already has station map/search, profile API and server-side comparison endpoint (2–12 stations), which is stronger than the reference screen's local-only distance calculation. The reference screen is not copied as a duplicate.
- Account audit: `docs/progress/ACCOUNT-SCREENS-AUDIT.md`. Effective role/assignment access context, global permissions UI and global user administration remain blocked pending API contract and owner approval.
- No database changes, no migrations/RLS/grants, no old database access, no main merge, no deployment.


## Master-spec page parity gaps (METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION)

| Master ID | Required screen/workflow | Canonical Flutter evidence | Status / next work |
|---|---|---|---|
| HR-02 | Hourly report list | Review/status queues only; no complete author-facing hourly history page | Missing — add station/UTC filters, pagination and status |
| HR-03 | Hourly report details/history | Shared read-only observation detail sheet | Partial — add version/history timeline and record scope |
| HR-04/05 | Hourly review queue/decision | Shared observation review screen | Partial — extend stage/state and concurrency tests |
| HR-06 | Hourly correction | Returned observation editor | Baseline exists — verify all field contracts and history |
| DY-02 | Daily report list | Reports hub links; no full daily list | Missing |
| DY-03 | Daily report details/history | Shared observation detail sheet | Partial |
| DY-04/05 | Daily review queue/decision | Shared observation review screen | Partial — verify daily-specific rules |
| DY-06 | Daily correction | Returned observation editor | Baseline exists — verify daily field contract and version history |
| AU-01/02 | Auditor workspace / station observation view | Electronic auditor scaffold and station review surfaces | Partial — no complete auditor queue/scope model |
| AU-03 | Missing-data register | Not present | Missing — needs approved missing-data rules/API |
| AU-04 | Review history | Registration review now links to station/system registration audit API and read-only audit screen | Partial — full observation event history remains separate |
| AU-05 | Monthly audit report | Manual archive confirmation screen and summary API | Partial — reconcile archive confirmations, missing data and outstanding items |
| AD-01 | User directory | Station-scoped user list in assignment screen | Partial — global directory not available |
| AD-02 | User details | Own-account profile + read-only station assignment detail sheet | Partial — authorized personal account detail/history API is missing |
| AD-03 | Role/permission administration | `AuthorityAccessScreen`: authority membership/grant queues, self-request, approve/reject/revoke and audit | Partial — effective caller access-context, delegated target user and validity-end controls remain |
| AD-04 | Station assignment | Station assignment screen: server roles, reasoned request/decision/revoke, optional UTC valid-to, assignment detail sheet | Partial — eligible-user search and cross-station/lifecycle tests remain |
| AD-05 | Operational settings | No approved settings UI/API inventory | Missing/TBD |
| AD-06 | Management files | No file management UI/API | Missing/TBD |
| RP-01 | Hourly reports/export | Review/status queue only | Missing — report list and export contract |
| RP-02 | Daily reports/export | Reports hub only | Missing — report list, summary and export parity |
| RP-03 | Monthly reports | Monthly archive summary only | Partial — no approved climate aggregation |
| RP-04 | Annual reports | Specialist shell / no aggregate API | Blocked |
| RP-05 | Climate reports | Specialist shell | Blocked — definitions and aggregate API |
| RP-06 | Rainfall reports | Specialist shell | Blocked — accumulation/units/source contract |
| RP-07 | Agricultural reports | Specialist shell | Blocked — field catalogue and API |
| RP-08 | Soil temperature | Specialist shell | Blocked — depth/units/sensor/time contract |
| RP-09 | Weather phenomena | Capture/validation/submission screen | Partial — catalogue, history and reports not complete |
| RP-10 | Station/operational dashboard | Operations summary and home station readiness | Partial — approved metric definitions/freshness needed |
| ID-06 | Access denied/session expired | Local 401/403 messages only | Missing — global access/session state |
| OFF-01 | Offline drafts/sync/conflicts | No accepted complete Flutter equivalent | Unverified/blocked pending approved offline design |

**Completion rule:** every row above must be verified with an API-backed workflow and tests, or explicitly blocked by a named contract/domain decision. A shell or menu link is not completion.


## Account-access screen follow-up — 2026-11-11T16:37:19.043Z

- `AuthorityAccessScreen` is now integrated in the canonical More menu and uses existing authority membership/permission APIs.
- It supports authority selection, self-membership requests, current-member permission requests, pending queues with reasoned approve/reject, active/scheduled queues with reasoned revocation, and read-only authority audit.
- `RegistrationReviewScreen` now links to station/system registration audit.
- No client-side permission grant or role inference; 401/403/409/503 states remain explicit.
- CI and runtime verification remain pending.


## Account-state gate implementation — 2026-11-11T16:41:41.703Z

- Authenticated session now requires a server account-status read before opening operational screens.
- Active accounts proceed to the home workspace; pending or unregistered accounts see the registration/status flow; suspended/disabled/rejected/unknown states are blocked.
- A failed status lookup does not fall back to the operational home.
- Pending registration requests cannot be resubmitted from the registration form.
- Source tests added; Flutter CI remains pending.


## Account/assignment workflow extension — 2026-11-11T16:46:02.479Z

- Added authority membership/permission management UI and registration audit history.
- Added server-state gate before operational home; non-active or unverified account states do not enter the operational shell.
- Added station assignment validity-end UTC field and read-only detail sheet.
- New source tests cover account gate states, registration duplicate guard, authority access reads/self-request and assignment validity/detail. All await Flutter CI execution.
