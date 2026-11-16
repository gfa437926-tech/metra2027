# METRA-REPOSITORY-RECONCILIATION.md
**تاريخ الإعداد:** 2026-11-16  
**الحالة:** مسودة تنفيذية — مبنية على فحص فعلي للمستودعات وPRs  
**الالتزام:** لا حذف ملفات عاملة · لا دمج PR · لا تعديل قاعدة بيانات · لا أسرار

---

## 1. وظيفة كل مستودع

| المستودع | الوظيفة الأساسية | الحالة الحالية | توصية الاستخدام |
|----------|------------------|----------------|-----------------|
| **gfa437926-tech/metra2027** | المستودع الأساسي: Backend ASP.NET Core 10 + Angular Web + Flutter مدمج (`mobile/metra_mobile`) + docs + migrations + CI | نشط، فيه 40+ PRs مفتوحة (معظمها Draft)، آخر تحديث رئيسي على main في 11 نوفمبر | **المصدر الرسمي** للـ Backend وAPI والعقود والوثائق والـ CI |
| **gfa437926-tech/metra-weather-intelligence2026** | تطبيق Flutter مستقل يركز على التسجيل + Edge Functions + دليل المحطات + خريطة + ملاحظات أولية | أكثر تقدماً في جانب التسجيل والموافقة وEdge Functions (station-directory, registration, observations, station-review) | **مصدر مرجعي** لـ Flutter في التسجيل والخريطة والـ Edge Functions؛ يُعاد استخدامه انتقائياً |
| **gfa437926-tech/metra2027-1** | مستودع شبه فارغ (README + AGENTS + COPYRIGHT فقط) | غير مستخدم | **تجاهل** — لا مصدر لأي مكون |

---

## 2. أحدث تنفيذ لكل مكون رئيسي

### 2.1 Flutter / النماذج / الكتالوج
- **المصدر الأفضل حالياً:** فرع `implementation/phase-1-flutter-forms-and-api-contract` (PR #54 — Draft) داخل `metra2027`.
  - يحتوي على `observation_field_catalogs.dart` يربط **174 حقلاً** من كتالوج PR #53.
  - نماذج hourly + daily متصلة بـ validation + submit عبر `MetraApiClient` (مع idempotency).
  - النماذج الأخرى (agricultural, hourlyclimate, rainfall, soil, ...) معروضة كواجهات إدخال من الكتالوج + تحقق محلي فقط.
  - Workspaces مستقلة: CLIMATOL، أرشيف، AI/OCR، مقارنة، أجهزة، صيانة، شبكات، IT، تقارير.
  - اختبارات: 31+ اختبار على الفرع (analyze + test + web release build تمر).
- **المستودع المستقل (`metra-weather-intelligence2026`):**
  - تطبيق أكبر في ملف واحد تقريباً (main.dart ضخم).
  - تسجيل + اعتماد محطات + ملاحظات عبر Edge Functions.
  - خريطة + Open-Meteo للطقس الحالي (دمشق).
  - لا يحتوي على كتالوج 174 حقلاً ولا نماذج الرصد الكاملة.

**قرار:** اعتمد PR #54 كأساس للنماذج والكتالوج. استخدم المستودع المستقل كمصدر لأفكار التسجيل والخريطة وEdge Functions فقط.

### 2.2 Backend / API
- **المصدر الوحيد:** `metra2027/backend/Metra.Api` + Tests.
  - JWT + station-scoped authorization.
  - Observation submission / review / decision.
  - Station directory (read-only).
  - Validation endpoints لـ hourly/daily.
  - Health / Ready.
  - CI يمر (build + tests + container).

### 2.3 Authentication / Session / Permissions
- في PR #54: `metra_auth.dart` + secure storage + configuration gate.
- في المستودع المستقل: AuthGate + registration flow + Edge Functions محمية بـ JWT + service_role فقط للعمليات الحساسة.
- **لا يوجد نظام RBAC كامل موحد بعد** عبر كل الأدوار المطلوبة (مدير النظام، رئيس محطة، راصد، مدقق...).

### 2.4 دليل المحطات
- موجود في كلا المستودعين عبر API / Edge Function.
- PR #54 يستخدم `MetraApiClient.getStationDirectory` / `getAllStationDirectory`.
- المستودع المستقل يستخدم `station-directory` Edge Function مع RLS وفلترة demo.

### 2.5 قاعدة البيانات
- الهدف: `tbdnklyxjvbrilvnwgmq`.
- لا تغييرات تمت في هذه الدفعة.
- Edge Functions موجودة في المستودع المستقل.
- Migrations موجودة في `metra2027` لكن لا تُنفذ إلا بعد موافقة صريحة.

---

## 3. الملفات المتكررة أو المتعارضة

| المنطقة | metra2027 (main / PR#54) | metra-weather-intelligence2026 | قرار |
|---------|---------------------------|--------------------------------|------|
| main.dart | صغير + ConfigurationGate + AuthGate | ملف ضخم يحتوي كل الشاشات | الإبقاء على هيكل PR#54 + نقل أفكار الشاشات |
| Auth | metra_auth.dart + secure storage | AuthGate + registration_flow | دمج انتقائي (التسجيل من المستقل، الجلسة من PR#54) |
| API Client | MetraApiClient (HTTP + JWT إلى .NET) | يعتمد على Supabase client + Edge Functions | الإبقاء على مسار .NET كأساسي للعمليات الحساسة |
| Station Directory | عبر .NET API | عبر Edge Function | توحيد على .NET API + الحفاظ على Edge Function كخيار |
| Observation Forms | كتالوج 174 + نموذج موحد | غير موجود بنفس الشكل | اعتماد PR#54 |
| Tests | 31+ على PR#54 | موجودة لكن أقل تغطية للنماذج | الإبقاء على اختبارات PR#54 وتطويرها |
| Web / PWA | موجود على PR#54 | موجود | الإبقاء على إعداد PR#54 |

---

## 4. المكونات التي يجب نقلها أو إعادة استخدامها

**من المستودع المستقل → إلى metra2027 (انتقائي):**
- منطق التسجيل والموافقة ثنائية المرحلة (registration + registration-approvals Edge Functions) — كمرجع تصميم فقط حتى يتم نقل العقود إلى .NET أو توحيدها.
- تجربة الخريطة والـ clustering.
- رسائل الحالة العربية الواضحة للمستخدم (حساب قيد الموافقة / مرفوض / موقوف).

**من PR #54 → ليبقى الأساس:**
- كتالوج الحقول 174.
- `MetraObservationForm` + validation.
- `MetraApiClient` + idempotency.
- Workspaces shells.
- اختبارات النماذج.

**لا يُنقل:**
- أي بيانات محطات قديمة.
- أي مفاتيح أو service role.
- أي منطق يتجاوز الصلاحيات.

---

## 5. المكونات التي يجب أن تبقى مستقلة

- `metra-weather-intelligence2026` يبقى مستودع Flutter مستقل مؤقتاً حتى يكتمل التوحيد.
- Angular في `metra2027` يبقى منفصلاً (لا يُستبدل بـ Flutter Web).
- Backend .NET هو المالك الوحيد للعمليات الحساسة والصلاحيات.
- قاعدة البيانات الجديدة مستقلة عن أي قاعدة قديمة.

---

## 6. استراتيجية التكامل بين التطبيق المستقل وBackend

1. **القصير الأجل (الحالي):**  
   - Flutter في PR #54 يتصل بـ .NET API عبر JWT.  
   - المستودع المستقل يستمر باستخدام Edge Functions للتسجيل والملاحظات.

2. **المتوسط الأجل:**  
   - توحيد عقود الملاحظات والتسجيل على .NET API.  
   - نقل منطق الصلاحيات وStation Scope إلى Backend.  
   - جعل Edge Functions طبقة رقيقة أو إزالتها تدريجياً إن لم تعد ضرورية.

3. **المبدأ الثابت:**  
   - Flutter لا يتصل مباشرة بجداول محمية.  
   - كل عملية حساسة تمر عبر API موثق ومحمي.  
   - لا Service Role Key في أي عميل.

---

## 7. المخاطر الناتجة عن دمج أو نقل الملفات

| المخاطرة | الدرجة | التخفيف |
|----------|--------|---------|
| نسخ مشروع فوق آخر يفقد تاريخ أو اختبارات | عالية | لا نسخ كامل — نقل انتقائي فقط |
| تعارض في نماذج البيانات (payload) بين .NET وEdge Functions | متوسطة | توحيد العقود أولاً قبل النقل |
| إدخال معرفات حقول غير معتمدة | عالية | الالتزام بـ field_uid من PR #53 فقط |
| كسر عزل المحطات | عالية | اختبارات IDOR + Privilege Escalation إلزامية |
| كشف أسرار أثناء النقل | عالية | مراجعة كل ملف قبل الرفع |
| تعطيل اختبارات موجودة | عالية | لا حذف اختبارات فاشلة — إصلاحها |

---

## 8. حالة PR #54 وPR #53 (التزام)

- **PR #54** (`implementation/phase-1-flutter-forms-and-api-contract`): يبقى **Draft** ومفتوحاً. لا دمج ولا إغلاق.
- **PR #53** (الدليل المرجعي 174 حقلاً): مرجع رسمي للنماذج والحقول. لا تعديل على المعرفات الرسمية.

---

## 9. الفجوات الرئيسية المكتشفة (أولية)

1. النماذج السبعة غير hourly/daily: واجهات فقط + تحقق محلي — لا API حفظ معتمد.
2. نظام الأدوار والصلاحيات غير مكتمل على مستوى الخادم لكل الأدوار المطلوبة.
3. وحدات CLIMATOL / OCR / AI / مقارنة الصور / الأجهزة / الصيانة / الشبكات / IT / التقارير: shells فقط.
4. لا يوجد بعد مسار تعديل رصدة معتمدة موثق.
5. اختبارات عزل المحطات (IDOR) غير مكتملة.
6. إعدادات الإنتاج (أسرار، CORS، host) غير جاهزة.

---

## 10. الخطوة التالية الموصى بها

1. إكمال مقارنة ملفات auth + workspaces + tests بين PR #54 والمستودع المستقل.
2. توثيق حالة كل نموذج من التسعة (متصل / محلي فقط / غير موجود).
3. إصلاحات أساس داخل فرع PR #54 أو فرع عمل جديد (بدون دمج):  
   - تحسين رسائل الأخطاء العربية.  
   - توحيد معالجة الوقت (UTC).  
   - إضافة اختبارات للـ 174 حقلاً حيث أمكن.
4. إعداد `METRA-MASTER-IMPLEMENTATION-STATUS.md` بناءً على هذا التقرير.

---

**ملاحظة نهائية:** هذا التقرير مبني على فحص فعلي للكود والشجرة وPRs. أي قرار نقل أو تغيير هيكلي كبير سيتم توثيقه قبل التنفيذ ولن يتم دمجه دون موافقة صريحة.
