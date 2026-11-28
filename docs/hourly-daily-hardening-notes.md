# تدقيق مسار hourly / daily

تاريخ: 2026-11-16  
الفرع: `feat/phenomenon-observation-submit-2026-11-16`  
PR المرتبط: #55 (مسار مشترك مع الظاهرة)

## مسار الحفظ الفعلي

`POST /api/v1/stations/{stationId}/observations`

الترتيب في `ObservationSubmissionEndpoints`:

1. مصادقة JWT (`sub`)
2. `RequireStationPermission("observation.create")` على **stationId من المسار**
3. `ObservationSubmissionRequestGuard` (نوع، idempotency، payload كائن، observedAt)
4. **`ObservationSubmissionDomainValidator.Validate`** — إجباري قبل أي استدعاء خدمة
5. `IObservationSubmissionService.SubmitAsync` → RPC `metra_submit_observation`

لا يوجد مسار submit بديل يتجاوز الخطوة 4.  
مسارات `/hourly/validate` و`/daily/validate` منفصلة للتحقق المسبق فقط؛ الحفظ لا يعتمد عليها وحدها.

## UTC

| الحقل | المعنى |
|---|---|
| `observedAt` (جسم الطلب) | طابع زمني للإرسال/الرصد يُرسل من Flutter عبر `toUtc().toIso8601String()` |
| `payload.utcTime` (ساعي) | ساعة الرصد العالمية كنص `00`–`23` داخل الحمولة |
| `payload.currentDate` (يومي) | تاريخ الرصد `yyyy-MM-dd` |

لا يُعاد تفسير `utcTime` من المنطقة المحلية في الخادم ضمن هذا المسار.  
اختبارات العميل تثبت تحويل `+03:00` → `Z` لـ `observedAt`.

## Idempotency

- العميل يثبت المفتاح لنفس بصمة الحمولة أثناء إعادة المحاولة.
- طبقة API **تمرّر** المفتاح إلى RPC في كل طلب؛ لا تخزّن dedupe في الذاكرة.
- إثبات dedupe الحقيقي على مستوى قاعدة البيانات **يتطلب بيئة Supabase حية** (غير مشغّل هنا).
- عند تعارض RPC يُعاد HTTP 409 من الـ endpoint.

## ما يُختبر هنا وما لا يُختبر

| البند | مستوى الاختبار |
|---|---|
| Guard + Domain قبل الخدمة | HTTP integration مع stubs |
| رفض بلا صلاحية / بلا مصادقة | HTTP integration |
| تمرير مفتاح idempotency | HTTP integration |
| 409 من الخدمة | HTTP integration |
| dedupe داخل RPC | **غير مثبت — يحتاج DB حية** |
| عزل محطات على RLS | **غير مثبت — يحتاج DB حية** |
