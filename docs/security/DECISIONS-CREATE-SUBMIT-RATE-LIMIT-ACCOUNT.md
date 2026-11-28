# قرارات تقنية معلّقة — Create/Submit، Rate limiting، accountState

**الفرع:** `feat/phenomenon-observation-submit-2026-11-16`  
**مرجع HEAD عند الكتابة:** يُحدَّث مع كل commit؛ لا تنفيذ لفرض صلاحيات أو rate-limit أو مصدر accountState دون موافقة صريحة.

---

## 1. فصل `observation.create` و `observation.submit`

### مصفوفة الأدوار (من `docs/security/role-permission-matrix.md`)

| الدور | create | edit_own_draft | submit | review | return | approve |
|---|---|---|---|---|---|---|
| `observer` | نعم | نعم | نعم | لا | لا | لا |
| `station_head` | لا | لا | لا | نعم | نعم | لا* |
| `station_auditor` | لا | لا | لا | نعم | نعم | لا |
| `chief_auditor` | لا | لا | لا | لا | نعم | نعم |
| `network_director` / `statistics_director` / `aftn_operator` | لا | لا | لا | لا | لا | لا |
| `system_admin` | لا | لا | لا | لا | لا | لا |

\* اعتماد النشرات (`observation.approve`) للـ `chief_auditor` حسب المصفوفة؛ رئيس المحطة يراجع ويُرجع فقط.

### ما يمكن لكل دور تنفيذه اليوم (HTTP الفعلي)

| الدور | إرسال رصدة (`POST .../observations`) | مراجعة الطابور | اعتماد | إرجاع |
|---|---|---|---|---|
| `observer` | نعم إن مُنح `create` (يملكه افتراضياً) | لا | لا | لا |
| `station_head` | لا (لا `create`) | نعم | لا | نعم |
| `station_auditor` | لا | نعم | لا | نعم |
| `chief_auditor` | لا | إن مُنح review أو عبر return/approve | نعم | نعم |

مسار الإرسال الحالي يفرض **فقط** `observation.create` (مع JWT + عزل المحطة).  
علم `submit: true|false` يُمرَّر إلى RPC دون فحص HTTP إضافي لـ `observation.submit`.

### أثر فرض `observation.submit` عند `Submit=true`

| السيناريو | الأثر |
|---|---|
| `observer` الافتراضي (create+submit) | **لا منع** — يملك الرمزين |
| مستخدم بمنح فردي `create` فقط دون `submit` | **يُمنع** الإرسال النهائي؛ قد يبقى قادراً على استدعاء المسار بـ `submit:false` إن بقي مسموحاً بـ create فقط |
| مراجع/رئيس محطة | لا تغيير (لا يملكون create أصلاً) |

**هل يمنع مخوّلين حالياً؟**  
حسب **مصفوفة الأدوار الافتراضية: لا**. الخطر الوحيد هو منح فردية شاذة (`create` بلا `submit`).  
**التوصية:** لا تُنفَّذ حتى تُراجع منح `metra` الفردية وتُعتمد سياسة:  
- إما فرض `(create AND submit)` عند `Submit=true`،  
- أو الإبقاء على create كبوابة HTTP والاعتماد على RPC/RLS لتمييز المسودة/الإرسال.

**لا تنفيذ في هذا الالتزام.**

---

## 2. Rate limiting (ASP.NET Core بدون DB)

### الممكن تقنياً دون Schema

- `System.Threading.RateLimiting` + `Microsoft.AspNetCore.RateLimiting` (وسيط طلبات في الذاكرة لكل عملية).
- مفتاح مقترح: `sub` من JWT إن وُجد، وإلا IP.
- استجابة: `429` + `Retry-After`؛ رسالة عربية عبر طبقة الأخطاء الحالية حيث ينطبق.

### مسارات ذات أولوية

| مجموعة | مسارات | حد مقترح (للنقاش) | مبرر |
|---|---|---|---|
| A — validate | hourly/daily/phenomena validate | 60 طلب/دقيقة لكل مستخدم | بعد المصادقة؛ حد الحقول موجود |
| B — إرسال | `POST .../stations/{id}/observations` | 20 طلب/دقيقة لكل مستخدم+محطة | idempotency يخفف التكرار |
| C — مراجعة | GET طابور + POST decision | 30 قراءة / 15 قرار /دقيقة | حماية من المسح العشوائي |
| D — access-context | `GET /me/access-context` | 30/دقيقة | تكلفة RPC متوازية |

### اتصالات ضعيفة

- الحدود **لكل دقيقة** لا لكل ثانية؛ إعادة المحاولة بعد انقطاع قصير لا تُعاقب بقسوة.
- الإبقاء على idempotency عند إعادة الإرسال بنفس المفتاح.
- عدم تخفيض مهلة عميل Flutter تلقائياً بسبب 429؛ عرض رسالة «تم تجاوز حد الطلبات…».

### قرار

**مقترح معتمد كتصميم فقط — غير منفَّذ.** يحتاج موافقة تشغيلية (قيم الحدود، هل يُطبَّق في كل البيئات، هل يُستثنى health/ready).

---

## 3. accountState

| مصدر محتمل | هل يخدم Access Context اليوم؟ |
|---|---|
| JWT `sub` | هوية فقط — لا حالة تفعيل |
| `station_assignments` / `authority_memberships` | تعيينات لا حالة حساب عامة |
| RPC صلاحيات | boolean صلاحية |
| دليل مستخدمي المحطة (RPC service-role) | يعيد حالة للمديرين على محطة — **ليس** مسار «أنا» |
| وثائق التسجيل | تذكر تحديث حالة الحساب عند اعتماد النظام — **لا endpoint قراءة ذاتي موثّق في API الحالي** |

**القرار الحالي (ساري):** الإبقاء على `"unknown"` في `GET /api/v1/me/access-context`.  
العميل لا يعامل unknown كـ active.  
**المطلوب لاحقاً بموافقة:** مسار قراءة ذاتي معتمد أو حقل/RPC موجود يُكشف عقده دون migration مرتجل.

انظر أيضاً: `SECURITY-VALIDATE-SUBMIT-ACCOUNT-STATE.md`.
