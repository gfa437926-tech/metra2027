# عقود API مقترحة — نماذج بلا حفظ معتمد

حالة: **مقترح للمراجعة فقط** — لا تنفيذ حفظ ولا migration ولا RPC.

العقود المعتمدة حالياً للحفظ: `hourly` | `daily` | `phenomenon`.

## قالب مشترك مقترح

```
POST /api/v1/stations/{stationId}/observations
Authorization: Bearer <access_token>
Permission: observation.create على stationId

{
  "idempotencyKey": "string (مطلوب، بدون حشو)",
  "observationType": "<type>",
  "observedAt": "ISO-8601 UTC",
  "payload": { /* حقول الكتالوج */ },
  "submit": true
}
```

استجابات متوقعة:

| رمز | المعنى |
|---|---|
| 200/201 | قبول |
| 400 | Guard (نوع/مفتاح/حمولة) |
| 401 | غير مصادق |
| 403 | بلا صلاحية / محطة |
| 409 | تعارض idempotency |
| 422 | فشل التحقق المجالي |
| 503 | خدمة الحفظ غير مهيأة |

التحقق المقترح: `POST /api/v1/observations/{type}/validate` بنفس قواعد الحقول.

## النماذج

| type | الواجهة الحالية | ملاحظات عقد |
|---|---|---|
| `agricultural` | Catalog — تحقق محلي | حقول كتالوج `ObservationFieldCatalogs.agricultural`؛ يتطلب جدول/RPC معتمد |
| `hourlyclimate` | محلي | غير `hourly` التشغيلي؛ فصل صريح عن الرصد الساعي المعتمد |
| `rainfall` | محلي | وحدات الهطول وحدود المجال من الكتالوج |
| `soil` | محلي | درجات حرارة/رطوبة تربة |
| `faultequipment` | محلي | بلاغ عطل جهاز — قد يرتبط لاحقاً بوحدة الأجهزة |
| `faulttelecom` | محلي | بلاغ اتصالات |
| `faultit` | محلي | بلاغ تقنية معلومات |

## صلاحيات مقترحة (لا تُنفَّذ قبل الموافقة)

- `observation.create` لكل نوع أو أذونات أدق مثل `observation.agricultural.create`.
- عزل محطة إلزامي عبر `stationId` المسار + RLS.

## ما لن يُنفَّذ هنا

- لا توسيع `ObservationSubmissionRequestGuard` لهذه الأنواع قبل الموافقة.
- لا جداول جديدة.
- لا بيانات تجريبية تُعرض كإنتاج.
