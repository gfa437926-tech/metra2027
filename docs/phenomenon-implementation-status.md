# حالة تنفيذ بلاغ الظاهرة الجوية

تاريخ التحديث: 2026-11-16  
الفرع: `feat/phenomenon-observation-submit-2026-11-16`  
PR: https://github.com/gfa437926-tech/metra2027/pull/55

## ما هو معتمد ومنفَّذ

| الطبقة | الحالة |
|---|---|
| `WeatherPhenomenonValidator` | موجود مسبقاً ومُختبَر |
| `POST /api/v1/observations/phenomena/validate` | موجود |
| `ObservationSubmissionRequestGuard` يسمح بـ `phenomenon` | موجود |
| `ObservationSubmissionDomainValidator` لـ phenomenon | مربوط عبر `WeatherPhenomenonValidator` |
| مسار الحفظ العام `POST /api/v1/stations/{id}/observations` | موجود (RPC `metra_submit_observation`) |
| Flutter validate + submit + idempotency | مربوط |
| كتالوج الحقول وشاشة وتبويب مساحة العمل | مربوط |

## الحقول المعتمدة للإدخال (لا أكثر)

- `phenomenonType` / `phenomenon_type` — مطلوب، ≤ 64
- `phenomenonDate` / `phenomenon_date` — مطلوب، `yyyy-MM-dd`
- `startTime` / `start_time` — مطلوب، `HH:mm:ss` (يُعامل كنص وقت UTC في العقد)
- `endTime` / `end_time` — اختياري؛ الفراغ = ظاهرة نشطة
- `generalNotes` / `general_notes` — اختياري، ≤ 2000
- `responsibilityAgreement` — مطلوب على مسار الإرسال فقط

## ما تبقى مقترحاً وغير منفَّذ (لا migrations)

وثيقة `docs/weather-phenomena-api-and-schema-proposal.md` ما زالت **مقترحاً** لما يلي:

- جدول `weather_phenomena` المخصص وأعمدته (`phenomenon_status`, `phenomenon_duration`, ...)
- سياسات RLS منفصلة للظواهر
- تحويل المنطقة الزمنية المحلي↔UTC على الخادم حسب منطقة المحطة
- واجهة «إنهاء ظاهرة نشطة» كعملية مستقلة

لا يُعدّ أي من ذلك جزءاً من هذا التنفيذ، ولم تُجرَ migrations.

## التوقيت

- حقول `startTime`/`endTime` تُرسل كما أدخلها المستخدم بعد تطبيع الواجهة من `HH:mm` إلى `HH:mm:ss` عند الحاجة.
- `observedAt` في طلب الحفظ = `DateTime.now().toUtc()` (طابع إرسال)، وليس إعادة تفسير لوقت بدء الظاهرة.
- لا يوجد تحويل +03:00 تلقائي في المسار الحالي؛ وثائق المصدر القديم تذكر فرقاً يدوياً للمعاينة فقط.

## حدود الصدق حول الحفظ الفعلي

- التحقق الخادمي والعميل يعملان على الحمولة.
- الإرسال يمر عبر نفس RPC العام المستخدم للرصد الساعي/اليومي مع `observation_type=phenomenon`.
- **لم يُثبت هنا** ضد قاعدة بيانات حية أن RPC يقبل ويخزّن ظاهرة ويعيد تكرار idempotency بنجاح؛ ذلك يتطلب بيئة Supabase مضبوطة واختبار تكامل مشغَّل فعلياً.
- الصلاحية `observation.create` وعزل المحطة يُفرضان على مستوى الـ endpoint كما لباقي أنواع الرصد.

## النماذج التالية ذات العقد المعتمد فقط

`ObservationSubmissionRequestGuard` يقبل حالياً:

1. `hourly`
2. `daily`
3. `phenomenon`

لا يوجد مدقق مجال معتمد ولا مسار validate لنماذج: زراعي، مناخي ساعي، أمطار، تربة، أعطال أجهزة/اتصالات/IT.  
**لا يُوسَّع API لهذه النماذج دون اعتماد عقد صريح.**
