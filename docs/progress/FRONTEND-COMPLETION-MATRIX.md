# METRA 2027 — FRONTEND Completion Matrix (Flutter)

**Updated (UTC):** 2026-11-11  
**Branch:** `work/legacy-ui-migration-audit`  
**Canonical source (CI):** `flutter-app/` only  
**Reference only:** `mobile/metra_mobile/` (do not develop in parallel)

Acceptance rule: design + functions + real API (when contract exists) + Arabic errors + station scope + tests. Shell ≠ complete. No fabricated weather values.

| ID | Arabic / English | Design | Functions | API | Permissions | Tests | CI | Result |
|---|---|---|---|---|---|---|---|---|
| FLT-AUTH-01 | تسجيل الدخول / Login | جيد | بوابة Supabase | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-AUTH-02 | التسجيل / Registration | جيد | طلب انضمام | مربوط | خادم | جزئي | معلق | قيد العمل |
| FLT-AUTH-03 | استعادة كلمة المرور / Password recovery | جيد | reset email | مربوط | — | موجود | معلق | قيد العمل |
| FLT-AUTH-04 | الملف الشخصي / Profile | جيد | بريد + خروج | مربوط | شرح صلاحيات | موجود | معلق | قيد العمل |
| FLT-AUTH-05 | الصلاحيات UI / Permissions view | ناقص | لا شاشة مستقلة | جزئي عبر الملف | — | لا | معلق | ناقص |
| FLT-STN-01 | دليل المحطات / Directory | جيد | قائمة+خريطة+بحث | مربوط | خادم | موجود | معلق | قيد العمل |
| FLT-STN-02 | تفاصيل المحطة / Detail | جيد | بيانات الدليل؛ تفاصيل المصدر/الدقة غير مثبتة في canonical | مربوط | — | جزئي | معلق | قيد العمل — FLT-004 provenance enhancement في المسار المرجعي فقط |
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
| FLT-FC-01 | مركز التنبؤ / Forecasting | جيد | خريطة+بحث+اختيار+مقارنة API في `flutter-app/`؛ إضافة Grok FLT-005 منفصلة في المسار المرجعي فقط | كتالوج ومقارنة خادمية | قراءة | موجود جزئياً؛ FLT-005 المرجعي غير مثبت في canonical | لا دليل أخضر | جزئي — مراجعة مسار مطلوبة |
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
