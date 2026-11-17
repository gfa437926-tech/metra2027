# تقرير تقدم المساعد رقم 8 — هندسة قواعد البيانات

- **آخر تحديث (UTC):** 2026-11-10T23:29:15.869Z
- **المهمة:** METRA-DB-08 — جرد وتدقيق مخطط البيانات وتوثيق المقترح الموحد.
- **الحالة:** قيد التنفيذ.
- **الفرع:** [work/database-engineering-audit](https://github.com/gfa437926-tech/metra2027/tree/work/database-engineering-audit)
- **Pull Request:** [#26 — Draft](https://github.com/gfa437926-tech/metra2027/pull/26) — مفتوح، Draft، غير مدمج.
- **Commit سابق للتحديث:** [469f8cd8982cb953321bea176f23758c474231ba](https://github.com/gfa437926-tech/metra2027/commit/469f8cd8982cb953321bea176f23758c474231ba)
- **Commit سجل التغييرات:** [d5e6f5db621485fffd0f6cda79ce6fe3e14b608c](https://github.com/gfa437926-tech/metra2027/commit/d5e6f5db621485fffd0f6cda79ce6fe3e14b608c)
- **Commit تحديث المهام:** [75928461216e3ba0a2b8219b80f5c3da04d5c032](https://github.com/gfa437926-tech/metra2027/commit/75928461216e3ba0a2b8219b80f5c3da04d5c032)

## 1. ملخص الجولة الحالية

تمت مراجعة تقرير التدقيق ومقترح نموذج البيانات وسجل التغييرات والمهام على فرع المساعد. تحققت من حالة PR عبر GitHub API، ومن فحوصات GitHub Actions المرتبطة بآخر commit.

## 2. الملفات التي فُحصت

- `docs/database/DATABASE-ENGINEERING-AUDIT.md`
- `docs/database/PROPOSED-UNIFIED-DATA-MODEL.md`
- `واجهات/تغيير.md`
- `واجهات/مهما.md`
- حالة PR #26 وبيانات commit الخاص به.
- Check Runs وPull Request workflow runs للـ commit `469f8cd8982cb953321bea176f23758c474231ba`.

## 3. الملفات التي عُدّلت في هذه الجولة

- `docs/progress/assistant-08.md` — إنشاء هذا التقرير.
- `واجهات/تغيير.md` — إضافة سجل الجولة الحالية مع توقيت UTC وروابط الدليل.
- `واجهات/مهما.md` — تحديث حالة المهمة والمهام المتبقية والخطوة التالية.

## 3.1 روابط commits التوثيق
- [Commit إنشاء تقرير التقدم](https://github.com/gfa437926-tech/metra2027/commit/998cefb63b0ee7b18cce5dabe8ec95c11aca44b1)
- [Commit سجل التغييرات](https://github.com/gfa437926-tech/metra2027/commit/d5e6f5db621485fffd0f6cda79ce6fe3e14b608c)
- [Commit تحديث المهام](https://github.com/gfa437926-tech/metra2027/commit/75928461216e3ba0a2b8219b80f5c3da04d5c032)

## 4. ما نُفذ فعلياً

- التحقق من أن PR #26 ما زال مفتوحاً وبحالة Draft وغير مدمج.
- التحقق من أن آخر commit قبل هذا التحديث هو `469f8cd8982cb953321bea176f23758c474231ba`.
- الاستعلام عن GitHub Actions للـ commit: لم تُرجع واجهة workflow runs أي تشغيل مرتبط به، كما أعادت Check Runs العدد 0.
- توثيق هذه النتائج دون الادعاء بنجاح اختبارات لم تُشغّل.

## 5. ما لم يُنفذ

- لم أشغّل اختبارات محلية أو CI.
- لم أعدّل أي مخطط SQL نشط ولم أنفذ SQL أو migrations أو seeds.
- لم أتصل بمشروع Supabase الجديد أو القديم.
- لم أراجع بعد جميع ملفات migrations والجداول والقيود والفهارس مراجعة شاملة.
- لم أعتمد كتالوج المحطات الجديد؛ لم يتم توفيره ضمن الجولة.
- لم أدمج PR إلى main ولم أنشر إلى الإنتاج.

## 6. نتائج الاختبارات وGitHub Actions

- **الاختبارات المحلية:** لم تُشغّل — لا توجد نتيجة نجاح/فشل للإبلاغ عنها.
- **GitHub Actions المرتبطة بالـ commit أعلاه:** لا توجد runs معادة من واجهة GitHub وقت الفحص.
- **Check Runs:** 0.
- روابط التحقق:
  - [Actions في المستودع](https://github.com/gfa437926-tech/metra2027/actions)
  - [حالة Checks للـ commit](https://github.com/gfa437926-tech/metra2027/commit/469f8cd8982cb953321bea176f23758c474231ba/checks)

## 7. النسبة وطريقة الحساب

**إنجاز المهمة الكلي: 10%.**

طريقة الحساب: قُسّمت المهمة إلى 10 محاور رئيسية وفق قائمة التكليف الأصلية. أُنجز محور واحد بالكامل حتى الآن وهو جرد ملفات المخطط والمigrations وتوثيق الموجود/المفقود. المحاور التسعة الأخرى ما زالت مفتوحة أو في مرحلة التدقيق الأولي، ولا تُحتسب الأعمال الجزئية إنجازاً كاملاً.

## 8. المتبقي والخطوة التالية

- **المهام المتبقية:** 9 محاور من أصل 10.
- **الخطوة التالية:** استكمال مراجعة جميع ملفات migrations ذات الصلة وربط كل جدول بمصدر تعريفه، ثم تدقيق المفاتيح والعلاقات والقيود والفهارس وتوثيق الأدلة لكل نتيجة.

## 9. حدود السلامة

لا تعديل أو حذف لقواعد البيانات القديمة. لا اتصال تنفيذي أو SQL أو migrations أو seeds على Supabase ref `tbdnklyxjvbrilvnwgmq` قبل مراجعة المخطط وموافقة صريحة. لا نقل بيانات قديمة ولا إعادة استخدام كتالوج المحطات القديم. لا دمج إلى `main`.


## 10. الجولة الثانية — مراجعة تفصيلية لملفات migrations

- **توقيت الجولة (UTC):** 2026-11-10T23:31:59.421Z
- **الحالة:** قيد التنفيذ.

### الملفات التي فُحصت
- جميع 27 ملفاً في `database/migrations/003–029`.
- جميع 5 ملفات في `supabase/migrations`.
- اختبارات shell: `verify_authority_access_lifecycle_contract.sh`, `verify_authority_permission_rpc.sh`, `verify_registration_review_contract.sh`, `verify_station_assignment_workflow_contract.sh`, `verify_station_audit_contract.sh`, `verify_station_permission_rpc.sh`.
- عقود: `docs/api/operational-observation-submission.md`, `docs/weather-phenomena-api-and-schema-proposal.md`.

### الملفات التي عُدّلت
- `docs/database/DATABASE-ENGINEERING-AUDIT.md` — إضافة الجولة الثانية والنتائج DB-011 إلى DB-015.
- `docs/database/MIGRATION-REVIEW-REGISTER.md` — إنشاء سجل مراجعة تفصيلي للمجموعتين.
- `docs/progress/assistant-08.md` — تحديث هذا التقرير.
- `واجهات/تغيير.md` — سيضاف سجل الجولة دون حذف الإدخالات السابقة.
- `واجهات/مهما.md` — سيحدث وضع المهام والخطوة التالية.

### ما نُفذ فعلياً
- مراجعة ساكنة لمحتوى 32 migration.
- توثيق DB-011: migration 020 يتطلب backfill لـ `permission_grants.authority_id` قبل NOT NULL، ولا يتضمن backfill.
- توثيق DB-012: payload JSONB لا يملك عقداً بنيوياً versioned لكل نوع رصد.
- توثيق DB-013: trigger سجل الرصد يمنع UPDATE/DELETE ولا يمنع TRUNCATE، خلافاً لسجل تدقيق السلطة.
- توثيق DB-014: idempotency key لا يحسم التكرار التجاري لنفس المحطة/النوع/الوقت بمفاتيح مختلفة.
- توثيق DB-015: بعض read-model RPCs تعتمد على تفويض API ولا تتحقق من actor داخل SQL.
- إضافة سجل migrations مستقل.

### ما لم يُنفذ
- لم يتم تشغيل اختبارات shell أو PostgreSQL.
- لم يتم تشغيل GitHub Actions يدوياً أو تنفيذ CI جديد.
- لم يتم تنفيذ SQL أو migration أو seed أو تعديل مخطط نشط.
- لم يتم الاتصال بأي مشروع Supabase.
- لم يتم فحص baseline schema لأن migrations 001 و002 غير موجودة في شجرة المستودع.
- لم يتم اعتماد كتالوج المحطات أو سياسة retention أو نموذج المرفقات.

### الاختبارات وGitHub Actions
- اختبارات shell: **قُرئت فقط، لم تُشغّل**.
- PostgreSQL integration tests: **لم تُشغّل**.
- GitHub Actions لهذه الجولة: **لم تُشغّل**.
- لا توجد نتيجة نجاح أو فشل مزعومة. [Actions](https://github.com/gfa437926-tech/metra2027/actions)

### نسبة الإنجاز وطريقة الحساب
**10%** — ما زال محور جرد الملفات هو المحور الوحيد المكتمل بالكامل من 10 محاور في التكليف. قراءة migrations بعمق وتسجيل المخاطر تدعم محاور العلاقات والقيود والتوافق، لكنها لا تُحسب مكتملة لأن baseline schema غير متاح ولا توجد اختبارات تشغيلية.

### المتبقي والخطوة التالية
- **المتبقي:** 9 محاور لم تكتمل بالكامل.
- **الخطوة التالية:** استعادة baseline schema 001/002 أو snapshot معتمد، ثم إنشاء قاموس للجداول والأعمدة والعلاقات والقيود والفهارس من مصدر موثوق. بعد ذلك تُراجع عقود API والـ payloads اليومية والساعية.

### أدلة GitHub لهذه الجولة
- [Commit تقرير التدقيق التفصيلي](https://github.com/gfa437926-tech/metra2027/commit/13de4ec9f2baba6563c83e3b9e5209e0d8ebccdc)
- [Commit سجل مراجعة migrations](https://github.com/gfa437926-tech/metra2027/commit/8f1a7f57b9b9115a89485a784af437604a3b32ef)
- [PR #26 — Draft](https://github.com/gfa437926-tech/metra2027/pull/26)


## 11. توثيق روابط الجولة والتحقق من GitHub — 2026-11-10T23:32:28.837Z UTC
- [Commit تقرير التدقيق](https://github.com/gfa437926-tech/metra2027/commit/13de4ec9f2baba6563c83e3b9e5209e0d8ebccdc)
- [Commit سجل مراجعة migrations](https://github.com/gfa437926-tech/metra2027/commit/8f1a7f57b9b9115a89485a784af437604a3b32ef)
- [Commit سجل التغييرات](https://github.com/gfa437926-tech/metra2027/commit/83e36b6940fcb6953d7ab7ab4be3690a502b4a5f)
- [Commit تحديث قائمة المهام](https://github.com/gfa437926-tech/metra2027/commit/26647b563c353ebbb0ec6acfa52bdd69ab393f4a)
- [PR #26](https://github.com/gfa437926-tech/metra2027/pull/26): مفتوح، Draft، غير مدمج وقت التحقق.
- فحص commit `26647b563c353ebbb0ec6acfa52bdd69ab393f4a`: GitHub Actions workflow runs = 0، Check Runs = 0. [Checks](https://github.com/gfa437926-tech/metra2027/commit/26647b563c353ebbb0ec6acfa52bdd69ab393f4a/checks).
- الاختبارات لم تُشغّل؛ عدم وجود Checks لا يعني نجاح الاختبارات.
- أحدث commit قبل تحديث هذا السطر: [26647b563c353ebbb0ec6acfa52bdd69ab393f4a](https://github.com/gfa437926-tech/metra2027/commit/26647b563c353ebbb0ec6acfa52bdd69ab393f4a).


## 12. البحث عن baseline في فروع أخرى
- **توقيت UTC:** 2026-11-10T23:33:06.593Z.
- **الحالة:** قيد التنفيذ، مع عائق baseline.
- فُحصت أشجار الفروع: `main`, `work/identity-migration-audit`, `work/backend-api-audit-assistant-2`, `integration/repository-consolidation-audit`, `audit/assistant-13-independent-final-review`؛ لم يظهر في أي منها migration 001/002 أو schema snapshot مطابق.
- أضيف DB-016 إلى تقرير التدقيق: غياب baseline في الفروع الخمسة المفحوصة، ما يمنع إثبات العلاقات وأنواع الأعمدة التأسيسية.
- فُحص main الحالي: [43c72da](https://github.com/gfa437926-tech/metra2027/commit/43c72da0604e49a74d2128cc9d3d881e2c912f26). بيانات PR #26 ما زالت تشير إلى base SHA أقدم 87f7135؛ لا rebase تلقائي قبل تنسيق المساعد رقم 1.
- **Commit تقرير التدقيق:** [070d51fc](https://github.com/gfa437926-tech/metra2027/commit/070d51fcf2519358d1a28d43fa2d50f6ca99344b).
- لم يتم تشغيل اختبارات أو SQL أو الاتصال بـ Supabase. لم يحدث دمج أو نشر.
- نسبة المهمة ما زالت 10% (محور واحد من عشرة مكتمل بالكامل). المتبقي 9 محاور.
- الخطوة التالية: الحصول على baseline schema معتمد من مالك المشروع، ثم متابعة قاموس الجداول والعلاقات والقيود.


## 13. تسليم نهائي للجولة — 2026-11-10T23:33:39.027Z UTC
- [Commit تحديث سجل التغييرات](https://github.com/gfa437926-tech/metra2027/commit/cbef0e5c0bc01c6654a48d9f7c09e9939af890e2)
- [Commit تحديث المهام](https://github.com/gfa437926-tech/metra2027/commit/129538bf21eb1eaf2103f51db0a68d46c859a7cb)
- [Commit تقرير التدقيق الأخير](https://github.com/gfa437926-tech/metra2027/commit/070d51fcf2519358d1a28d43fa2d50f6ca99344b)
- [Commit تقرير التقدم الأخير قبل هذا التحديث](https://github.com/gfa437926-tech/metra2027/commit/16d90111d12668493f77a28513357121be68540b)
- آخر HEAD للفرع قبل هذا التحديث: [129538bf](https://github.com/gfa437926-tech/metra2027/commit/129538bf21eb1eaf2103f51db0a68d46c859a7cb).
- GitHub Actions runs على HEAD: 0؛ Check Runs: 0. لم تُشغّل الاختبارات.
- PR #26: مفتوح، Draft، غير مدمج؛ base SHA المعروض 87f7135 بينما main الحالي 43c72da. تحديث base/rebase مؤجل للتنسيق مع المساعد رقم 1.


## 14. مطابقة Backend validators مع مسار الحفظ
- **توقيت UTC:** 2026-11-10T23:34:26.137Z.
- **الحالة:** قيد التنفيذ.
- فُحصت 13 ملفاً بين validators وworkflow وendpoints واختبارات الوحدة/request guards.
- اكتشاف DB-017: مسار حفظ الرصد لا يستدعي validators اليومية/الساعية/الظواهر؛ SQL يتحقق من شكل JSON والحجم فقط. يمكن نظرياً حفظ بيانات لا تجتاز validator المنفصل.
- اكتشاف DB-018: validators تتجاهل مفاتيح الحقول غير المعروفة بدلاً من رفضها.
- اكتشاف DB-019: نموذج الظواهر يقارن أوقات TimeOnly ضمن يوم واحد ولا يمثل ظاهرة تعبر منتصف الليل.
- توثيق ملاحظات إيجابية: actor مشتق من JWT في endpoints، وفحص الصلاحية في API وRPC، وworkflow له انتقالات محددة؛ لا يعني ذلك اكتمال تغطية الحفظ.
- **الملف المعدل:** `docs/database/DATABASE-ENGINEERING-AUDIT.md` فقط في هذه الخطوة.
- **الاختبارات:** تمت قراءة ملفات الاختبار فقط؛ لم تُشغّل.
- **Commit:** [dc73b6d](https://github.com/gfa437926-tech/metra2027/commit/dc73b6d16c9c2dbf6c93be230fc8be65ae5b2466).
- لم يتم تعديل كود Backend أو SQL أو الاتصال بـ Supabase.


## 15. روابط الجولة الثالثة والتحقق
- **توقيت UTC:** 2026-11-10T23:34:58.345Z.
- [Commit تقرير التدقيق DB-017 إلى DB-019](https://github.com/gfa437926-tech/metra2027/commit/dc73b6d16c9c2dbf6c93be230fc8be65ae5b2466)
- [Commit تقرير التقدم](https://github.com/gfa437926-tech/metra2027/commit/a2259464595418104f83cb647eb8ec858d5ee208)
- [Commit سجل التغييرات](https://github.com/gfa437926-tech/metra2027/commit/28be1eac8676f7c82c155855eb7f23b063402e45)
- [Commit تحديث المهام](https://github.com/gfa437926-tech/metra2027/commit/3e7bb0544d65818d7c6235f75b11841023a66a6a)
- آخر HEAD قبل هذا التحديث: [3e7bb054](https://github.com/gfa437926-tech/metra2027/commit/3e7bb0544d65818d7c6235f75b11841023a66a6a).
- GitHub Actions runs = 0 وCheck Runs = 0 على هذا HEAD؛ لم يتم تشغيل الاختبارات.
- PR #26 ما زال مفتوحاً Draft وغير مدمج. base SHA في بيانات PR ما زال أقدم من main الحالي؛ لا rebase تلقائي.


## 16. إعادة التحقق من main وإضافة DB-020
- **توقيت UTC:** 2026-11-10T23:37:06.581Z.
- **الحالة:** قيد التنفيذ.
- تم التحقق من main HEAD `43c72da0604e49a74d2128cc9d3d881e2c912f26` ومقارنة blob SHA لسبعة ملفات Backend مع فرع التدقيق؛ الملفات متطابقة، ولم تظهر معالجة جديدة للمشكلات DB-017/018/019.
- إضافة DB-020: endpoints التحقق اليومي والساعي لا تمرر requiredFields إلى validators، في حين أن هذه المعاملات اختيارية؛ لذلك لا يتم فرض اكتمال الحقول المطلوبة من endpoint نفسه.
- مراجعة واجهة الظواهر في Angular: component يعلن صراحة أنها معاينة محلية غير محفوظة، وليس مسار كتابة فعلياً.
- الملفات المفحوصة: `ObservationSubmissionEndpoints.cs`, `ObservationValidationEndpoints.cs`, `ObservationValidationRequestGuard.cs`, daily/hourly/phenomenon validators, `ObservationWorkflow.cs`, Angular observation API + workflow + phenomena component، اختبارات WeatherPhenomenonValidator، وملفا migration الخاصان بالإرسال والقرار.
- **ملف التدقيق المعدل:** `docs/database/DATABASE-ENGINEERING-AUDIT.md`.
- **Commit:** [912a451](https://github.com/gfa437926-tech/metra2027/commit/912a45182f50e1bd8357ba641063c172986341cd).
- **الاختبارات:** لم تُشغّل؛ لم يُنفذ build أو CI في هذه الخطوة.
- لم يتم تعديل كود التطبيقات أو SQL، ولم يتم الاتصال بـ Supabase.
- نسبة الإنجاز تبقى **10%** وفق معيار المحاور المكتملة بالكامل (1 من 10)، والمتبقي 9 محاور.
- الخطوة التالية: بناء مصفوفة required-fields مع المساعدين 2 و11 انطلاقاً من مواصفات الرصد المعتمدة، ثم مراجعة ربط validators بمسار الحفظ.


## 17. إغلاق توثيق الجولة الرابعة والتحقق من GitHub — 2026-11-10T23:37:48.115Z UTC
- [Commit إضافة DB-020 إلى تقرير التدقيق](https://github.com/gfa437926-tech/metra2027/commit/912a45182f50e1bd8357ba641063c172986341cd)
- [Commit سجل التقدم](https://github.com/gfa437926-tech/metra2027/commit/3f6a1e968162496895157894404b39bbe9945f77)
- [Commit سجل التغييرات](https://github.com/gfa437926-tech/metra2027/commit/12ba9dde103320621cb65f434c751aabfc1ec655)
- [Commit تحديث المهام](https://github.com/gfa437926-tech/metra2027/commit/64c5c9fbbf9546a6ec1228b6641dbeff725f6bb8)
- [PR #26](https://github.com/gfa437926-tech/metra2027/pull/26) تم تحديث وصفه ليتضمن DB-020 ونتيجة إعادة التحقق؛ ما زال مفتوحاً Draft وغير مدمج.
- فحص HEAD `64c5c9fbbf9546a6ec1228b6641dbeff725f6bb8`: GitHub Actions workflow runs = 0؛ Check Runs = 0. [Checks](https://github.com/gfa437926-tech/metra2027/commit/64c5c9fbbf9546a6ec1228b6641dbeff725f6bb8/checks).
- الاختبارات وbuild لم تُشغّل؛ لا توجد نتيجة نجاح مزعومة.
- PR base SHA ما زال أقدم من main HEAD؛ لم يُجر rebase أو merge. التنسيق مع المساعد 1 مطلوب.
- النسبة: 10% وفق معيار 1 محور مكتمل بالكامل من 10؛ 9 محاور متبقية. DB-020 نتيجة تدقيق جزئية ولا ترفع نسبة المحاور المكتملة.
- الخطوة التالية: مصفوفة required-fields مستندة إلى مواصفات الرصد المعتمدة، ثم التنسيق مع المساعد 2 لربط validation بمسار الحفظ ومع المساعد 11 لمراجعة المتطلبات العلمية.


## 18. مصفوفة required-fields اليومية والساعية — 2026-11-10T23:40:49.398Z UTC
- **المهمة:** METRA-DB-08 — إعداد مصفوفة أولية من مصادر المستودع.
- **الحالة:** منجزة كمسودة توثيقية؛ اعتماد المتطلبات العلمية وربطها بالحفظ ما زال محجوباً/مفتوحاً.
- **الملفات المفحوصة:** `daily_validation.js`, `daily_fields_control.js`, `daily_reports.html`, `hourly_reports.html`, `hourly-send.js`, `DailyObservationValidator.cs`, `HourlyObservationValidator.cs`, `ObservationValidationEndpoints.cs`, `daily-reports.component.ts`, وعقد `docs/api/operational-observation-submission.md`.
- **الملفات الجديدة/المعدلة:** [مصفوفة الحقول](../database/REQUIRED-FIELDS-MATRIX.md)؛ تحديث `DATABASE-ENGINEERING-AUDIT.md` بإضافة DB-021؛ تحديث هذا التقرير وسجل التغيير وقائمة المهام.
- **النتائج:** اليومي 24h يفرض 14 حقلاً في المصدر، و06/18 UTC يفرضان أربعة؛ الساعي يفرض 12 حقلاً دائماً إضافة إلى utcTime، والهطول في 00/06/12/18، وميل/شكل الضغط والطقس السابق في الساعات السينوبتية. هذه قوائم سلوك كود وليست اعتماداً علمياً.
- **مخاطر مرتبطة:** DB-017 وDB-020 ما زالت قائمة؛ endpoint اليومي لا يمرر requiredFields ومسار الحفظ لا يثبت أنه يفرض validators. كما أن `#` مقبول كرمز missing ولا بد من قرار علمي لدلالته.
- **ما لم يُنفذ:** لم تُشغّل الاختبارات أو build أو CI؛ لم يُعدّل كود أو SQL أو migration؛ لم يتم الاتصال بـ Supabase أو تنفيذ SQL/seed؛ لا دمج ولا نشر.
- **التنسيق المطلوب:** المساعد 11 لاعتماد profiles ودلالة missing marker؛ المساعد 2 لتصميم ربط profile/version بالتحقق والحفظ.
- **الإنجاز:** 10% (محور واحد من عشرة مكتمل بالكامل؛ إعداد المصفوفة وحده لا يغلق محوراً كاملاً).
- **المتبقي:** 9 محاور.
- **الخطوة التالية:** الحصول على اعتماد علمي للحقول/الوحدات/رمز #، ثم تسليم عقد profile-version للمساعد 2 لربط validator بمسار الحفظ.
- **Commit المصفوفة:** [eaa6262ac9ab2c6c61bb164e1e8a7bd6f3e15431](https://github.com/gfa437926-tech/metra2027/commit/eaa6262ac9ab2c6c61bb164e1e8a7bd6f3e15431).
- **Commit التدقيق DB-021:** [37e65558b4144baddc3ad3182d678db6bb01efa9](https://github.com/gfa437926-tech/metra2027/commit/37e65558b4144baddc3ad3182d678db6bb01efa9).
