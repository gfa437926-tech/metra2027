# مصفوفة صلاحيات ودورات عمل — النماذج السبعة (مقترح)

**حالة:** مقترح للموافقة — **لا منح أدوار ولا تعديل RPC/RLS في هذا الالتزام.**

مرجع الأدوار الحالية: `docs/security/role-permission-matrix.md`.

---

## 1. رموز العمليات

### 1.1 تقارير رصد (`rainfall`, `soil`, `hourlyclimate`, `agricultural`)

| رمز | المعنى |
|---|---|
| create | إنشاء سجل (مسودة أو مباشر) |
| edit_own_draft | تعديل مسودة المالك |
| submit | تحويل إلى مُرسل للمراجعة |
| review | عرض الطابور |
| approve | اعتماد |
| return_for_correction | إرجاع |

### 1.2 بلاغات أعطال (`faultequipment`, `faulttelecom`, `faultit`)

| رمز مقترح | المعنى |
|---|---|
| fault.report | إنشاء بلاغ |
| fault.edit_own | تعديل قبل الإسناد |
| fault.assign | إسناد لمعالج |
| fault.resolve | تسجيل الحل |
| fault.close | إغلاق |
| fault.review | مراجعة إدارية |

---

## 2. أثر مقترح على الأدوار الحالية (لا تنفيذ تلقائي)

| الدور | رصد (create/submit) | رصد (review/return/approve) | أعطال (report) | أعطال (assign/resolve/close) |
|---|---|---|---|---|
| `observer` | مرشّح لـ create/edit/submit للأنواع الرصدية الأربعة | لا | مرشّح لـ fault.report على محطته | لا |
| `station_head` | لا | review + return (كما اليوم) | قراءة بلاغات محطته | assign / close على محطته (مقترح) |
| `station_auditor` | لا | review + return | review فقط (مقترح) | لا |
| `chief_auditor` | لا | approve + return | لا | لا |
| `aftn_operator` | لا | لا | مرشّح faulttelecom report/resolve | resolve محدود (مقترح) |
| `system_admin` | لا | لا | لا bypass رصد | إغلاق IT على مستوى نظام (مقترح حذر) |
| `network_director` / `statistics_director` | لا | لا | لا | لا |

**قاعدة:** لا يُضاف أي رمز إلى `metra_role_permissions` إلا بـ migration معتمدة بعد موافقة هذا المستند.

---

## 3. دورات العمل

### 3.1 رصد (الأربعة)

```
local_draft (جهاز) → server_draft? → submitted → approved
                                      ↓
                              returned_for_correction → resubmit
```

- عزل محطة في كل خطوة.
- Idempotency على الإرسال.
- المراجع لا يعدّل الحمولة؛ يعتمد أو يُرجع بملاحظة.

### 3.2 أعطال (الثلاثة) — مستقلة عن الرصد

```
reported → assigned → in_progress → resolved → closed
              ↘ returned_for_info
```

| عملية | من | إلى | صلاحية مقترحة |
|---|---|---|---|
| إنشاء | — | reported | fault.report |
| إسناد | reported | assigned | fault.assign |
| بدء معالجة | assigned | in_progress | fault.resolve (أو assign) |
| حل | in_progress | resolved | fault.resolve |
| إغلاق | resolved | closed | fault.close |
| طلب استكمال | * | returned_for_info | fault.review / assign |
| استكمال من المبلّغ | returned_for_info | reported/assigned | fault.edit_own |

---

## 4. فصل صريح بين النطاقات

| لا تخلط | السبب |
|---|---|
| `hourly` التشغيلي ↔ `hourlyclimate` | عقود/validators/أوقات مرجعية مختلفة |
| تقارير مناخية ↔ أعطال أجهزة | غرض تشغيلي مختلف |
| `faulttelecom` ↔ `faultit` | اتصالات محطة مقابل بلاغات برمجيات/نشرات |
| رصد ↔ صيانة | صلاحيات ومسارات تدقيق مختلفة |

---

## 5. قرارات تنتظر الموافقة (ملخص)

1. اعتماد رموز `fault.*` أم إعادة استخدام `observation.*` مؤقتاً.  
2. منح `observer` لإنشاء الأنواع الرصدية الأربعة الجديدة.  
3. منح `station_head` إدارة بلاغات الأعطال على محطته.  
4. فرض `submit` مع `Submit=true` على المسار الموحّد (قرار سابق منفصل).  
5. حدود رقمية رسمية لحرارات التربة والهطول خارج ما في الكتالوج المحلي.
