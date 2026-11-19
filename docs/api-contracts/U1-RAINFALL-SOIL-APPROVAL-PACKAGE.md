# حزمة موافقة U1 — Rainfall و Soil

**الحالة:** للتدقيق والموافقة فقط — **غير منفَّذة** على الإنتاج.  
**الفرع:** `feat/phenomenon-observation-submit-2026-11-16`  
**HEAD المرجعي عند الإعداد:** `a0c2a65ee4e136521cb50b84c80f610d04a1f27a`  
**مرجع الاعتماد السابق:** `SEVEN-FORMS-APPROVAL-RECORD.md` (D1–D7)

> أي توصية أدناه **ليست** موافقة تلقائية. التنفيذ الخادمي/DB يتطلب قراراً مستقلاً صريحاً من مالك المشروع.

---

## 0. فصل: الموجود فعلياً vs المقترح

| الطبقة | الموجود الآن | مقترح U1 (بعد الموافقة) |
|---|---|---|
| أنواع الحفظ الخادمي | `hourly` \| `daily` \| `phenomenon` فقط | + `rainfall` \| `soil` |
| `ObservationSubmissionRequestGuard` | يرفض غير الأنواع الثلاثة | توسيع النوعين بعد جاهزية الحفظ |
| `ObservationSubmissionDomainValidator` | نفس الأنواع الثلاثة | فروع تحقق rainfall/soil |
| مسار HTTP الإرسال | `POST /api/v1/stations/{stationId}/observations` + `observation.create` | **نفس المسار** (لا endpoint جديد مخترع) |
| validate API | hourly / daily / phenomena | اختياري لاحقاً لنفس النمط — **غير موجود** لـ rainfall/soil |
| Flutter | كتالوج + تحقق محلي + `awaitingApiContract` | ربط submit بعد الخادم |
| صلاحيات إنتاج في DB | مصفوفة الأدوار الحالية | **لا منح جديدة** في U1؛ الاعتماد على `observation.create` الحالي لـ observer |

---

## 1. النطاق المقترح

**داخل U1:**
- نموذجا `rainfall` و `soil` فقط.
- دورة رصد (مسودة محلية → إرسال → مراجعة وفق الآلية الحالية إن انطبقت).
- عزل محطة + هوية من JWT.

**خارج U1:**
- agricultural, hourlyclimate, fault*
- migrations/RLS/RPC دون بند موافقة صريح
- صلاحيات إنتاج جديدة أو رموز `fault.*`
- E2E / Staging

---

## 2. حقول الكتالوج المعتمد (Flutter `ObservationFieldCatalogs`)

### 2.1 Rainfall (7 حقول)

| id | label | kind | unit | مطلوب | حدود في الكتالوج |
|---|---|---|---|---|---|
| currentDate | تاريخ إرسال | text | — | لا | لا |
| localTime | وقت محلي | time | hour | لا | لا |
| utcTime | UTC | text | hour | لا | لا |
| rainAmount | هطول مم | decimal | mm | لا | **لا min/max** (D5) |
| snowDepth | ثلج سم | decimal | cm | لا | **لا min/max** |
| observationDate | تاريخ رصد | date | — | **نعم** | لا |
| responsibilityAgreement | إقرار | boolean | — | **نعم** | يجب true عند الإرسال |

### 2.2 Soil (7 حقول)

| id | label | kind | unit | مطلوب | حدود في الكتالوج |
|---|---|---|---|---|---|
| observationDate | تاريخ | date | — | **نعم** | لا |
| depth5 | عمق5 | decimal | °C | لا | لا min/max |
| depth10 | عمق10 | decimal | °C | لا | لا min/max |
| depth20 | عمق20 | decimal | °C | لا | لا min/max |
| depth50 | عمق50 | decimal | °C | لا | لا min/max |
| observerNotes | ملاحظات | multiline | — | لا | لا |
| responsibilityAgreement | إقرار | boolean | — | **نعم** | true عند الإرسال |

### 2.3 قواعد تحقق يمكن إثباتها من الكتالوج / المستودع

- الحقول `required: true` أعلاه إلزامية.
- عند وجود قيمة لـ decimal: رقم منتهٍ (`isFinite`) — مُطبَّق محلياً في `LocalCatalogObservationRepository`.
- لا حدود أرصادية رقمية معتمدة خادماً (D5).
- الإقرار boolean يجب أن يكون `true` للإرسال النهائي (نفس روح hourly/daily).

### 2.4 ما يحتاج اعتماد مالك البيانات (ليس في الكتالوج كعقد رسمي)

- هل `currentDate` / `utcTime` لـ rainfall تُخزَّن أم تُشتق من الخادم؟
- دقة الكسور للهطول والثلج وحرارة التربة.
- هل يُرفض تقرير بلا أي من `rainAmount`/`snowDepth` (كلاهما اختياري الآن)؟
- معنى الأعماق الأربعة (حرارة فقط أم رطوبة لاحقاً) — حالياً وحدة °C في الكتالوج.

---

## 3. الهوية والمحطة والأمان

| عنصر | المصدر الموثوق | ملاحظة |
|---|---|---|
| المستخدم | JWT claim `sub` | لا يُقبل من جسم الطلب |
| المحطة | `{stationId}` في المسار | تحقق تكليف + صلاحية على الخادم |
| الصلاحية عند الإرسال | `observation.create` (موجود) | كما hourly؛ لا رمز جديد في U1 |
| المراجعة | `observation.review` / `approve` / `return_for_correction` | إن دخل النوعان نفس طابور المراجعات |
| IDOR | رفض الوصول لمحطة بلا تكليف/صلاحية | نفس `RequireStationPermission` + RPC |
| التكرار | `idempotencyKey` (≤128، بدون حشو) | نفس الحارس الحالي |
| الأسرار | لا Service Role في Flutter | ساري |

**مخاطر:** توسيع النوع دون RPC يسبب فشل حفظ أو سلوك غير معرّف؛ حدود غير موثقة إن أُضيفت دون D5 تُعد مخالفة.

---

## 4. شكل الطلب/الاستجابة المقترح (نفس عقد الإرسال الحالي)

```http
POST /api/v1/stations/{stationId}/observations
Authorization: Bearer <access_token>
```

```json
{
  "idempotencyKey": "string",
  "observationType": "rainfall" | "soil",
  "observedAt": "ISO-8601 UTC",
  "payload": { },
  "submit": true
}
```

استجابات متوقعة (نفس نمط الأنواع الحالية): 200/201، 400، 401، 403، 409، 422، 503.

**Validate (اختياري، غير موجود اليوم):**  
`POST /api/v1/observations/rainfall/validate` و `.../soil/validate` — فقط إذا وُافق على إضافتهما بنفس سياسة المصادقة الحالية؛ **ليس شرطاً لبدء الحفظ** إن كُرر التحقق في مسار الإرسال.

---

## 5. تغييرات مطلوبة حسب الطبقة (بعد الموافقة فقط)

### 5.1 API (.NET)

| تغيير | ضرورة |
|---|---|
| قبول `rainfall`/`soil` في `ObservationSubmissionRequestGuard` | إلزامي للحفظ |
| فروع في `ObservationSubmissionDomainValidator` | إلزامي |
| endpoints جديدة لمسار الإرسال | **غير مطلوبة** إن بقي المسار الموحّد |
| validate endpoints | اختيارية |

### 5.2 DB / RPC / RLS

| تغيير | ضرورة |
|---|---|
| قبول النوعين في دالة الحفظ (مثل `metra_submit_observation` أو المكافئ) | **غالباً إلزامي** — يحتاج موافقة DB مستقلة |
| جداول جديدة | غير مثبتة؛ يُفضَّل إعادة استخدام نموذج observation إن وُجد عمود/تمييز النوع |
| RLS | فقط إن ظهر قصور؛ **لا تعديل استباقي** |
| منح صفوف في `metra_role_permissions` | **غير مطلوبة** إن بقي `observation.create` كافياً لـ observer |

### 5.3 Flutter (يمكن جزء منه الآن دون DB)

| تغيير | انتظار DB؟ |
|---|---|
| الإبقاء على تحقق محلي ومسودات | لا — موجود |
| عدم استدعاء submit للأنواع غير المعتمدة | لا — موجود |
| بعد الموافقة: استدعاء `submitObservation` + رسائل عربية | **نعم** |

---

## 6. خطة الاختبارات (بعد التنفيذ الموافق عليه)

### خادم
- 401 بدون JWT؛ 403 بلا `observation.create` / محطة أخرى (IDOR).
- 400 مفتاح idempotency غير صالح؛ 409 تكرار مفتاح.
- 422 ناقص `observationDate` أو إقرار false؛ decimal غير رقمي.
- قبول حمولة صالحة rainfall و soil.

### Flutter
- رفض محلي للحقول المطلوبة وغير الرقمي.
- بعد الربط: نجاح/فشل شبكة، منع تكرار الإرسال، عزل مسودة بالمحطة.
- عدم ادّعاء الحفظ للأنواع غير المربوطة.

---

## 7. قرارات مستقلة تنتظر موافقة المالك

| # | القرار | خيارات |
|---|---|---|
| **A** | السماح بتنفيذ U1 الخادمي لـ rainfall+soil | نعم / لا |
| **B** | نطاق DB: توسيع RPC الحفظ فقط vs migration إضافية | يُحدد بعد A=نعم |
| **C** | هل يُنشأ validate endpoint لكل نوع؟ | نعم / لا (لاحقاً) |
| **D** | هل تُراجع التقارير في نفس طابور hourly/daily؟ | نعم / لا |
| **E** | سياسة تقرير rainfall بلا كمية مطر/ثلج | مسموح / مرفوض |
| **F** | أي حدود رقمية رسمية لاحقاً | تأجيل (الافتراضي حسب D5) |

**التنفيذ الخادمي يتوقف حتى موافقة صريحة على A (وB إن لزم).**

---

## 8. جاهزية U1 (تقدير)

| محور | جاهزية |
|---|---|
| توثيق الحقول والقواعد من الكتالوج | عالية |
| أمان النموذج (JWT/محطة/create/idempotency) | معتمد على النمط الحالي — عالٍ تصميمياً |
| كود Flutter المحلي | متوسط–عالٍ |
| API/DB للتنفيذ | **0%** حتى الموافقة A/B |
| الاختبارات التشغيلية | غير مشغّلة في بيئة الإعداد |

**خلاصة:** حزمة الموافقة جاهزة للمراجعة البشرية؛ **ليست** إذناً بالتنفيذ الخادمي.
