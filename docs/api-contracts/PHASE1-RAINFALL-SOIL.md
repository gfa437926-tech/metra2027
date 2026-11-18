# المرحلة 1 — rainfall و soil (بعد اعتماد D1–D7)

## نطاق مفعّل الآن (بدون DB)

1. كتالوج Flutter: أنواع `decimal` لحقول الكميات/الحرارات ذات الوحدة، **بدون** `minimum`/`maximum` غير الموثّقة.
2. التحقق المحلي عبر `LocalCatalogObservationRepository` (مطلوب + شكل رقمي عند kind=decimal).
3. الإبقاء على `CatalogSubmissionPhase.awaitingApiContract` — لا ادّعاء حفظ خادمي.
4. الأعطال خارج النطاق (D2 مؤجّل).

## مواصفات خادمية — مسودة مهام (تتطلب موافقة مستقلة)

### A. API (بعد الموافقة)

| عنصر | اقتراح |
|---|---|
| نوع | `observationType`: `rainfall` \| `soil` فقط ضمن مسار الرصد |
| مسار | نفس `POST /api/v1/stations/{stationId}/observations` **بعد** توسيع معتمد للـ guard والـ RPC |
| صلاحية HTTP | `observation.create` (الموجودة) — **لا منح أدوار جديدة**؛ الاعتماد على منح observer الحالية عند تفعيل النوع في RPC |
| validate | اختياري لاحقاً: `/api/v1/observations/rainfall|soil/validate` بنفس سياسة المصادقة الحالية |
| هوية | JWT `sub` فقط |
| Idempotency | كما hourly/daily/phenomenon |

### B. حمولة rainfall (payload)

| id | نوع منطقي | مطلوب عند submit |
|---|---|---|
| observationDate | date | نعم |
| responsibilityAgreement | boolean true | نعم |
| rainAmount | number (mm) إن وُجد | لا — إن وُجد يجب أن يكون رقماً منتهياً |
| snowDepth | number (cm) إن وُجد | لا |
| currentDate, localTime, utcTime | كما الكتالوج | لا |

**لا حدود min/max خادمية** في هذه المرحلة (D5) سوى رفض غير الرقمي وغير المنتهي.

### C. حمولة soil

| id | نوع منطقي | مطلوب عند submit |
|---|---|---|
| observationDate | date | نعم |
| responsibilityAgreement | boolean true | نعم |
| depth5/10/20/50 | number (°C) إن وُجد | لا — رقمي منتهٍ فقط |
| observerNotes | string | لا |

### D. قاعدة البيانات / RPC

يتطلب **موافقة مستقلة صريحة** قبل أي migration:

- قبول النوعين في دالة الحفظ المعتمدة أو آلية مكافئة.
- عدم خلط جداول الأعطال (D1).
- عدم تعديل RLS إلا بموافقة منفصلة.

### E. ترتيب بعد إغلاق مرحلة rainfall/soil محلياً

1. طلب موافقة DB/API لـ rainfall+soil فقط.
2. بعد الموافقة: guard + validator + اختبارات .NET + ربط Flutter.
3. ثم agricultural (مرحلة 2).
4. ثم hourlyclimate منفصل عن hourly (مرحلة 3).

## اختبارات مطلوبة لهذه المرحلة (Flutter)

- رفض rainfall بلا observationDate / بلا إقرار.
- رفض rainAmount غير الرقمي بعد تحويل kind إلى decimal.
- قبول قيم صالحة → `awaitingApiContract` + مسودة حسب المحطة.
- نفس النمط لـ soil.
