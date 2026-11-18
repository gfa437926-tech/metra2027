# تدقيق أمني — مسارات validate وصلاحيات الإرسال وaccountState

**الفرع:** `feat/phenomenon-observation-submit-2026-11-16`  
**مرجع الكود:** بعد commit تدقيق النماذج المتصلة (`401d484…`) + هذا التوثيق.  
**قاعدة:** لا Schema / RLS / RPC / endpoint مخترع.

---

## 1. مسارات validate

| المسار | مصادقة JWT | قراءة DB | كشف محطة/مستخدم | حدود حجم |
|---|---|---|---|---|
| `POST /api/v1/observations/hourly/validate` | **نعم** (FallbackPolicy) | لا | لا | `ObservationValidationRequestGuard`: ≤100 حقل، اسم ≤64، قيمة ≤256 |
| `POST /api/v1/observations/daily/validate` | **نعم** | لا | لا | نفس الحارس |
| `POST /api/v1/observations/phenomena/validate` | **نعم** | لا | لا | حدود المجال في `WeatherPhenomenonValidator` (نوع ≤64، ملاحظات ≤2000) |

**الاستنتاج:** المسارات **ليست مجهولة**. سياسة `FallbackPolicy = RequireAuthenticatedUser` في `Program.cs` تفرض JWT ما لم يُستدعَ `.AllowAnonymous()` (الصحة/الجاهزية فقط). اختبارات `ApiAuthenticationTests` تتوقع 401 بدون رمز.

**Rate limiting:** غير منفَّذ على مستوى التطبيق. الحماية الحالية = مصادقة + حدود حقول/قيم + مهلة عملاء Supabase (8 ثوانٍ). إضافة rate-limit عام قرار تشغيلي (لا يغيّر عقد JSON) ويحتاج موافقة بنية تحتية.

**رسائل التحقق:** عربية ومجالية؛ لا تتضمن stack traces ولا مفاتيح. الحارس يُرجع رموزاً عامة عند تجاوز الحجم.

**تقييم الإبقاء مع المصادقة الحالية:** مناسب — تحقق هيكلي فقط بعد هوية موثوقة، دون قراءة بيانات تشغيلية.

---

## 2. صلاحيات العمليات الفعلية

| العملية | فرض الخادم الحالي | ملاحظات |
|---|---|---|
| تحقق مجالي (validate) | JWT صالح | لا فحص صلاحية محطة |
| إرسال/حفظ رصدة (`POST .../observations`) | JWT + `observation.create` على `stationId` المسار + إعادة تحقق مجالي | `Submit=true/false` يُمرَّر لـ RPC؛ **لا يُفرض `observation.submit` منفصلاً على مسار HTTP** |
| مسودة محلية في Flutter | لا API | `ObservationDraftStore` فقط |
| تعديل مسودة خادمية | لا مسار HTTP منفصل لـ `edit_own_draft` في الطبقة الحالية | السياسة المجالّية `ObservationAuthorizationPolicy` تعرف الصلاحية لكن المسار التشغيلي موحّد |
| طابور المراجعة | أحد: `observation.review` \| `approve` \| `return_for_correction` على المحطة | عزل محطة من المسار + RPC |
| قرار اعتماد | `observation.approve` | |
| قرار إرجاع | `observation.return_for_correction` + ملاحظة إلزامية | |

### إجابات مباشرة

1. **إنشاء مسودة دون صلاحية إرسال؟**  
   - محلياً في التطبيق: نعم (مسودة جهاز).  
   - على الخادم: مسار الإرسال الحالي يتطلب `observation.create` سواء `submit=true` أو لا.

2. **إرسال دون صلاحية إنشاء؟**  
   - لا — الفلتر `RequireStationPermission("observation.create")` يمنع ذلك.

3. **تعديل تقرير سبق إرساله؟**  
   - لا مسار «تعديل بعد الإرسال» في API الحالي. دورة الإرجاع → إعادة إرسال عبر نفس مسار الإرسال بعد قرار `return_for_correction` (سلوك RPC).

4. **مراجعة خارج نطاق المحطة؟**  
   - لا — `stationId` من المسار + فحص صلاحية على نفس المحطة؛ اختبارات IDOR ترفض المحطة الأخرى.

5. **التحقق من الصلاحيات في كل عملية؟**  
   - نعم للمسارات الحساسة (إرسال، طابور، قرار، إدارة).  
   - **فجوة موثّقة:** سياسة المجال تفصل `Create` عن `Submit` و`EditOwnDraft`، لكن مسار HTTP للإرسال لا يفرض `observation.submit` عند `Submit=true`. توحيد ذلك **يتطلب موافقة** لأنه قد يمنع حسابات تملك `create` فقط.

---

## 3. accountState

| سؤال | الجواب من الكود/العقود |
|---|---|
| آلية معتمدة لحالة الحساب؟ | **لا** — `SupabaseAccessContextService` يضع `"unknown"` صراحة |
| قراءة تفعيل/حظر موثوقة؟ | غير موجودة في مسارات API الحالية |
| حقول/عقود قائمة؟ | JWT `sub` + تعيينات المحطة/السلطة؛ لا جدول profiles مقروء من API |
| دون تعديل Schema؟ | لا مصدر PostgREST/RPC موثّق لقراءة حالة تفعيل الحساب |
| مخاطر `unknown`؟ | منخفضة طالما الواجهة **لا** تعامل `unknown` كـ `active` (`hasKnownActiveAccount` يتطلب `"active"`). الحساب المعطّل في Supabase Auth يفشل JWT عند التجديد؛ التعيينات غير المعتمدة لا تُعاد في access-context |

### قرار تقني مطلوب (لا تنفيذ دون موافقة)

لإرجاع `accountState` حقيقي يلزم أحد:

1. مسار قراءة معتمد من مصدر موجود (إن وُجد لاحقاً في الكتالوج دون migration)، أو  
2. موافقة صريحة على RPC/حقل جديد — **خارج نطاق هذا الفرع**.

الإبقاء على `"unknown"` + fail-closed للصلاحيات هو السلوك الآمن الحالي.

---

## 4. إصلاحات ضمن العقد (هذا الالتزام)

- مواءمة `MaximumValueLength` مع حد الكتالوج 256 (ملاحظات الراصد) مع الإبقاء على سقف عدد الحقول.
- توسيع اختبارات السياسة المجالّية: create ≠ submit، ملكية submit، edit_own_draft للمالك.
- توسيع اختبارات حارس validate: اسم فارغ، ملاحظات بطول الكتالوج.

## 5. ما يحتاج موافقة قبل التنفيذ

1. فرض `observation.submit` إضافي عند `Submit=true` على مسار الإرسال.  
2. Rate limiting تطبيقي/بنيوي.  
3. مصدر وكتابة `accountState` غير `unknown`.  
4. مسار HTTP منفصل لمسودة خادمية / `edit_own_draft`.
