# METRA 2027 — حالة التشغيل الفعلية

المشروع المعتمد: `gfa437926-tech/metra2027`  
الفرع: `work/execution-master-2026-11-14`  
قاعدة التجربة الوحيدة: `tbdnklyxjvbrilvnwgmq`  
التطبيق: `mobile/metra_mobile/`  
الخادم: `backend/Metra.Api/`

## ما يعمل عند تشغيل الـ API مع مفاتيح الخادم

مسارات مربوطة بواجهات حقيقية (ليست بيانات وهمية):

- تسجيل الدخول عبر Supabase Auth ثم Bearer إلى .NET
- دليل المحطات
- مستخدمو المحطة والتسجيل وقراءة صلاحيات الجهة
- طابور الرصد (قراءة)
- سجل تدقيق المحطة وشاشة التدقيق الإلكتروني (نفس سجل المحطة التشغيلي)

## ما هو موجود على القاعدة ومقفول في التطبيق عمداً

جداول ودوال الرصد موجودة على المشروع المستضاف:

- جداول: `metra_observations`, `metra_observation_records`, `metra_observation_audit_events`
- دوال: `metra_submit_observation`, `metra_decide_observation`

الإرسال والاعتماد يبقيان **fail-closed** إلى أن يُضبط على الخادم فقط (ليس داخل تطبيق Flutter):

- `ObservationSubmission:ScientificContractApproved=true`
- `ObservationDecision:AtomicAuthorizationApproved=true`

هذان مفتاحان لقرار علمي/تشغيلي، وليسا عيباً في الواجهة. النماذج الساعية واليومية تستدعي الـ API بالفعل؛ الخادم يرفض الكتابة حتى الموافقة.

## ما ليس جاهزاً ولا يُفتح بالقوة

- أرشيف الرصد: لا توجد دالة `archive` على القاعدة. الواجهة والخادم يبقيان 503.
- AI و Climatol ومراكز التنبؤ: وضع Mock معلن، بلا خدمة خارجية معتمدة.
- لا يُستخدم مفتاح `service_role` داخل Flutter.
- قاعدة METRA القديمة محظورة.

## تشغيل محلي

```bash
# الخادم — الأسرار من البيئة فقط
export Supabase__Url=https://tbdnklyxjvbrilvnwgmq.supabase.co
export Supabase__ServiceRoleKey='<server-only>'
export Supabase__JwtSecret='<server-only>'
dotnet run --project backend/Metra.Api

# التطبيق
cd mobile/metra_mobile
flutter run \
  --dart-define=METRA_API_BASE_URL=http://127.0.0.1:PORT \
  --dart-define=SUPABASE_URL=https://tbdnklyxjvbrilvnwgmq.supabase.co \
  --dart-define=SUPABASE_ANON_KEY='<publishable-or-anon>'
```

لا تضع أسرار الخادم في المستودع. دوّر أي مفتاح ظهر سابقاً في محادثة.

## قرار الجاهزية

| الطبقة | الحكم |
| --- | --- |
| تطبيق Flutter الأصلي | جاهز للتشغيل للمسارات غير العلمية |
| Backend .NET | جاهز للبناء؛ الكتابة العلمية خلف بوابة إعداد |
| PostgreSQL التجربة | مخطط تشغيلي موجود (23 جدولاً عاماً) |
| أرشيف / AI / Climatol / تنبؤ حي | غير مكتمل |
| إنتاج عام | غير جاهز |

البرنامج القابل للتسليم هو هذا الفرع، وليس تطبيقاً بديلاً.
