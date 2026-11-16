# مراجعة ما قبل الاختبار الحي + مصفوفة الاتصال

تاريخ: 2026-11-16  
الفرع: `feat/phenomenon-observation-submit-2026-11-16`  
HEAD المُراجع: `dbefaa4b65bb2ff4f6fa0b4c6ca6340a3b0ae89d`  
PR: #55 (Draft — غير مدمج)

## 1) تثبيت CI على HEAD

| الوظيفة | النتيجة | الدليل |
|---|---|---|
| Angular build | success | https://github.com/gfa437926-tech/metra2027/actions/runs/43969211805/job/133656760677 |
| .NET API build and tests | success | https://github.com/gfa437926-tech/metra2027/actions/runs/43969211805/job/133656760246 |
| Flutter analyze | success (No issues) | نفس تشغيل Flutter |
| Flutter test | **success — 68 tests passed** | https://github.com/gfa437926-tech/metra2027/actions/runs/43969211805/job/133656760625 |
| Flutter Web release | **success — Built build/web** | نفس وظيفة Flutter |
| Backend build workflow | success | https://github.com/gfa437926-tech/metra2027/actions/runs/43969211807 |

لم يُحذف أي اختبار. سلوك زر الإرسال الثابت (خارج ListView) لم يُغيَّر بعد الإصلاح.

---

## 2) مراجعة تقنية لحالات L1–L7

المرجع: `docs/hourly-daily-live-test-plan.md`

### تغطية آلية متاحة الآن (بدون Staging)

| الحالة | ماذا تغطي الاختبارات الآلية | المستوى | دليل |
|---|---|---|---|
| **L1** إرسال ساعي صالح | مسار HTTP: مصادقة + صلاحية + DomainValidator + وصول الخدمة | تكامل API بـ stubs | `HourlyDailySubmissionEndpointTests` — CI .NET success |
| **L1** (عميل) | تنسيق hourly validate، UTC لـ observedAt | وحدة Flutter | `observation_validation_api_test`، `hourly_daily_observation_screen_test` |
| **L2** إعادة المفتاح | API يمرّر نفس `idempotencyKey` في كل طلب؛ لا dedupe في الذاكرة | تكامل API | نفس ملف التكامل — يثبت التمرير فقط |
| **L3** حمولة متعارضة بنفس المفتاح | غير مثبت على RPC حي | — | يتطلب Staging |
| **L4** يومي | مثل L1 للمسار والعميل | API + Flutter | نفس ملفات hourly/daily |
| **L5** عزل المحطة | الصلاحية على `stationId` من المسار؛ رفض محطة غير مسموحة | تكامل API | `Permission_check_uses_route_station_id...` |
| **L6** بلا صلاحية | 403 وعدم استدعاء الخدمة | تكامل API | `Authenticated_user_without_station_permission_is_forbidden` |
| **L7** إعادة محاولة عميل | العميل يثبت المفتاح لنفس بصمة الحمولة | وحدة Flutter | اختبارات idempotency السابقة + شاشات hourly/daily |
| رفض حمولة غير صالحة | 422 قبل الخدمة لـ hourly/daily | تكامل API | `Domain_validation_rejects_invalid_*` |
| أخطاء خادم عربية | displayMessage لـ 401/403/409/شبكة دون تسريب تقني | وحدة Flutter | `observation_submit_display_message_test`، hourly/daily tests |

### ما لم يُختبر حياً (Staging غير متوفر لهذه الجلسة)

لا توجد في بيئة التنفيذ الحالية:

- `METRA_API_BASE_URL` لـ Staging معتمد
- حسابات مستخدمين A/B مع JWT
- محطات S1/S2 مع تكليف وصلاحية `observation.create`
- اتصال فعلي بـ RPC `metra_submit_observation` وبيانات حقيقية

**لذلك لا يُدّعى تنفيذ L1–L7 على Staging.**  
أي نتيجة RPC حقيقية لـ idempotency (200 مكرر مقابل 409) تبقى غير مؤكدة حتى توفر البيئة.

### خلاصة مراجعة الأمان للمسار

1. **الصلاحيات:** `RequireStationPermission("observation.create")` قبل الحفظ.
2. **عزل المحطة:** من المسار وليس من جسم الطلب.
3. **Idempotency:** مسؤولية RPC؛ العميل والـ API يمرّران المفتاح فقط.
4. **التحقق:** Domain validator إجباري قبل الخدمة؛ لا مسار submit يتجاوزه.
5. **الأخطاء:** لا تُعرض تفاصيل تقنية للمستخدم عبر `displayMessage`.
6. **إعادة المحاولة:** مثبتة على مستوى العميل (نفس المفتاح لنفس البصمة).

---

## 3) مصفوفة الواجهة مقابل الاتصال الفعلي بالخادم

مصدر التبويبات: `observation_workspace_screen.dart`.

| التبويب / الشاشة | واجهة | تحقق محلي | validate API | submit API | ملاحظات |
|---|---|---|---|---|---|
| رصد ساعي | نعم | نعم (النموذج) | نعم `/hourly/validate` | نعم `POST .../observations` type=hourly | متصل |
| رصد يومي | نعم | نعم | نعم `/daily/validate` | نعم type=daily | متصل |
| ظاهرة جوية | نعم | نعم | نعم `/phenomena/validate` | نعم type=phenomenon | متصل |
| زراعي | نعم | نعم فقط | لا | لا | `CatalogObservationScreen` — رسالة «لا API معتمد» |
| مناخي ساعي | نعم | نعم فقط | لا | لا | نفس |
| أمطار | نعم | نعم فقط | لا | لا | نفس |
| تربة | نعم | نعم فقط | لا | لا | نفس |
| أعطال أجهزة | نعم | نعم فقط | لا | لا | نفس |
| اتصالات | نعم | نعم فقط | لا | لا | نفس |
| تقنية معلومات | نعم | نعم فقط | لا | لا | نفس |
| مراجعة | نعم | — | قائمة/قرار عبر API | قرارات review | متصل بمسار المراجعة |
| دليل المحطات | نعم | — | قراءة عبر API | — | متصل للقراءة |
| إدارة المحطة | نعم | — | جزئي عبر API | — | يعتمد على endpoints المعتمدة |
| CLIMATOL workspace | واجهة | — | غير مثبت كحفظ رصد | — | إشعار خدمة / حسابات محلية |

**عقود الحفظ المعتمدة حالياً في Guard:** `hourly` | `daily` | `phenomenon` فقط.

---

## 4) Staging — متطلبات ناقصة

| المتطلب | الحالة |
|---|---|
| URL Staging API | غير متوفر في هذه الجلسة |
| مستخدمو اختبار A/B + JWT | غير متوفر |
| محطات S1/S2 معزولة | غير متوفر |
| موافقة استخدام بيانات حقيقية | غير ممنوحة هنا |

عند توفرها: تنفيذ L1–L7 كما في الخطة وتسجيل HTTP codes والمعرفات دون تعديل RPC.

---

## 5) عيوب وإصلاحات منجزة سابقاً (لا إعادة عمل)

| عيب | إصلاح | حالة |
|---|---|---|
| زر الإرسال غير مبني في ListView الطويل | تثبيت الزر خارج ListView | مُصلح + 68 اختباراً ناجحاً |
| رسائل أخطاء تقنية | `MetraApiException.displayMessage` | مُصلح |
| ظاهرة مرفوضة على الخادم | ربط `WeatherPhenomenonValidator` | مُصلح |
| Client CI لا يعمل على `feat/**` | توسيع فروع workflow | مُصلح |

لا عيوب جديدة مكتشفة في هذه المراجعة تتطلب كوداً دون Staging.

---

## 6) قيود مستمرة

- لا تعديل schema / migrations / RPCs
- لا لمس قاعدة قديمة
- لا دمج/إغلاق PR #54 أو #55
- لا اختراع عقود حفظ للنماذج السبعة غير المعتمدة
