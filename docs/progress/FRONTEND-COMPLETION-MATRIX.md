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
| FLT-STN-02 | تفاصيل المحطة / Detail | جيد | كتالوج | مربوط | — | جزئي | معلق | قيد العمل |
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
| FLT-FC-01 | مركز التنبؤ / Forecasting | جيد | دليل+مقارنة | مربوط كتالوج | قراءة | موجود | معلق | جزئي |
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
