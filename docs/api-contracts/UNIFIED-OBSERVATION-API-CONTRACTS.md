# METRA 2027 — وثيقة عقود API الموحدة لنماذج الرصد

**الحالة:** توثيق من الكود الحالي فقط (HEAD `50b2fc24` + هذا الالتزام).
**قاعدة:** لا endpoint ولا RPC ولا جدول ولا حقل مخترع. ما ليس موجوداً في الكود مُعلَّم صراحةً بأنه «يحتاج موافقة».

---

## 1. النماذج المتصلة فعلياً (حفظ + تحقق خادمي)

### 1.1 hourly — الرصد الساعي

| بند | القيمة الحالية |
|---|---|
| نوع الملاحظة | `hourly` |
| مسار التحقق | `POST /api/v1/observations/hourly/validate` |
| مسار الإرسال | `POST /api/v1/stations/{stationId}/observations` مع `observationType=hourly` |
| مسار المراجعة | `GET /api/v1/stations/{stationId}/observations` + `POST .../observations/{id}/decision` |
| الصلاحيات | `observation.create` / `observation.submit` للإرسال؛ `observation.review` أو `observation.approve` / `observation.return_for_correction` للمراجعة |
| حالة الاتصال | **فعلي** (تحقق + إرسال + طابور مراجعة) |
| الوقت | `observedAt` بصيغة ISO-8601 UTC |
| منع التكرار | `idempotencyKey` مطلوب |

قواعد التحقق: تنفيذها في `HourlyObservationValidator` و`ObservationSubmissionDomainValidator` (درجات حرارة بإشارة صريحة، ضغط، رطوبة، رياح، سحب، طقس حالي/ماضي، هطول…). الحقول الناقصة أو خارج المدى تُرجع 422 مع قائمة `issues`.

### 1.2 daily — الرصد اليومي

| بند | القيمة الحالية |
|---|---|
| نوع الملاحظة | `daily` |
| مسار التحقق | `POST /api/v1/observations/daily/validate` |
| مسار الإرسال | نفس مسار المحطة مع `observationType=daily` |
| مسار المراجعة | نفس طابور الملاحظات |
| الصلاحيات | كما في hourly |
| حالة الاتصال | **فعلي** |

### 1.3 phenomenon — الظواهر الجوية

| بند | القيمة الحالية |
|---|---|
| نوع الملاحظة | `phenomenon` |
| مسار التحقق | `POST /api/v1/observations/phenomena/validate` |
| مسار الإرسال | `POST /api/v1/stations/{stationId}/observations` مع `observationType=phenomenon` |
| مسار المراجعة | نفس طابور الملاحظات |
| الصلاحيات | كما في hourly + `responsibilityAgreement` مطلوب عند الإرسال |
| حالة الاتصال | **فعلي** |

#### حقول الظاهرة (مطابقة `WeatherPhenomenonValidator` + كتالوج Flutter)

| id / JSON | إلزامي | النوع / القاعدة |
|---|---|---|
| `phenomenonType` / `phenomenon_type` | نعم | نص ≤ 64 |
| `phenomenonDate` / `phenomenon_date` | نعم | `yyyy-MM-dd` |
| `startTime` / `start_time` | نعم | `HH:mm:ss` UTC |
| `endTime` / `end_time` | لا | `HH:mm:ss` UTC أو فارغ (مستمرة)؛ لا يسبق وقت البدء |
| `generalNotes` / `general_notes` | لا | ≤ 2000 |
| `responsibilityAgreement` | نعم عند الإرسال | boolean true |

---

## 2. النماذج السبعة — محلية فقط (لا حفظ معتمد)

مصدر الكتالوج: `CatalogFormType` + `ObservationFieldCatalogs` (PR #53).  
التحقق: محلي في Flutter فقط.  
الإرسال الإنتاجي: **مرفوض** حتى وجود عقد معتمد وموافقة صريحة.

| code | العنوان العربي | مسار تحقق حالي | مسار إرسال حالي | مسار مراجعة | الصلاحيات الحالية | الحالة |
|---|---|---|---|---|---|---|
| `agricultural` | الرصد الزراعي | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |
| `hourlyclimate` | الرصد المناخي الساعي | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط (مفصول عن `hourly`) |
| `rainfall` | رصد الأمطار | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |
| `soil` | رصد التربة | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |
| `faultequipment` | أعطال الأجهزة | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |
| `faulttelecom` | أعطال الاتصالات | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |
| `faultit` | بلاغات تقنية المعلومات | لا يوجد | لا يوجد | لا يوجد | — | محلي فقط |

**عقود ناقصة تحتاج موافقتك قبل أي تنفيذ خادمي:**

1. تعريف جدول/RPC أو مسار حفظ لكل نوع.
2. قواعد التحقق المجالي والخادمي الرسمية.
3. رموز صلاحيات دقيقة (إن رُفضت إعادة استخدام `observation.create`).
4. سلوك المسودة / الإرسال / الإرجاع / الاعتماد.
5. سياسة idempotency وUTC وتمييز الحقول الناقصة.

المقترح السابق (غير منفَّذ): `docs/api-contracts/PROPOSED-FORMS-WITHOUT-PERSISTENCE.md`.

---

## 3. إدارة المستخدمين والمحطة (عقود موجودة)

| العملية | المسار | الصلاحية (من المصفوفة) | حالة الواجهة Flutter |
|---|---|---|---|
| مستخدمو المحطة | `GET /api/v1/stations/{stationId}/users` | `users.station.view` | شاشة إدارة المحطة — تبويب «مستخدمو المحطة» |
| طلبات التسجيل | `GET .../registration-requests` | مرحلة المحطة: `registrations.station.approve` | تبويب «طلبات التسجيل» + اعتماد/رفض |
| قرار التسجيل | `POST .../registration-requests/{id}/decision` | نفس السابق (+ مرحلة نظام منفصلة على الخادم) | حوار تأكيد + منع التكرار |
| سجل التدقيق | `GET .../audit-log` | `users.station.view` | تبويب «سجل التدقيق» |
| طابور الأرصاد | `GET .../observations` | `observation.review` / approve | تبويب + شاشة مراجعة منفصلة |
| قرار الرصد | `POST .../observations/{id}/decision` | review / approve / return | شاشة مراجعة الأرصاد |

**غير موجود في العقود الحالية (لا يُنفَّذ):**

- قائمة مستخدمين عالمية خارج نطاق المحطة.
- تعديل دور مستخدم أو منح/سحب صلاحية فردية من Flutter.
- تغيير عضوية سلطة من واجهة المحطة.
- بحث/تصفية متقدم عبر كل النظام.

إدارة السلطات والعضويات والمنح لها عقود في `docs/api/authority-access.md` لكنها غير مربوطة بواجهة Flutter إنتاجية بعد.

---

## 4. مبادئ فرض الصلاحيات

- الخادم هو المصدر الوحيد للقرار: JWT → هوية → تعيين محطة معتمد → منحة فردية سارية → RPC صلاحية لنفس `stationId`.
- لا يثق Flutter بادعاء دور أو محطة من العميل.
- عزل المحطات إلزامي على المسار + RPC.
- لا يوجد bypass لـ `system_admin` على عمليات الرصد؛ الأدوار الإدارية منفصلة عن عمليات الرصد اليومية.

انظر أيضاً: `docs/security/role-permission-matrix.md` و`docs/security/authority-scope-authorization.md`.
