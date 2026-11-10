# METRA 2027 — تقرير تدقيق هندسة قواعد البيانات

- تاريخ الفحص: 2026-11-11
- الفرع المرجعي: `main`
- فرع التدقيق: `work/database-engineering-audit`
- النطاق: ملفات المستودع فقط؛ لم يتم الاتصال بمشروع Supabase أو تنفيذ SQL.
- حالة الوثيقة: تدقيق أولي موثق، وليس اعتماداً نهائياً للمخطط.

## 1. حدود السلامة

لم تُنفذ أي أوامر SQL على أي قاعدة بيانات، ولم تُشغّل migrations، ولم تُقرأ أو تُنقل بيانات من قاعدة قديمة. مشروع Supabase الجديد `tbdnklyxjvbrilvnwgmq` خارج نطاق أي تعديل. لم يُعتمد كتالوج محطات قديم أو تُستنتج بيانات لمحطات جديدة. كل المقترحات في هذا التقرير تحتاج مراجعة وموافقة صريحة قبل التنفيذ.

## 2. منهجية الجرد

تم فحص شجرة Git الكاملة للفرع `main` ثم قراءة ملفات التوثيق والمigrations والاختبارات ذات الصلة. شجرة المستودع احتوت 316 مساراً ولم تكن مقتطعة.

### الموجود فعلياً

| المسار | ما وجد |
|---|---|
| `supabase/migrations` | خمسة ملفات SQL مؤرخة في 2026-11-03 |
| `database/migrations` | 27 ملفاً مرقماً من 003 إلى 029 |
| `database/seeds` | ملف seed واحد لدليل الأدوار |
| `database/tests` | اختبارات shell لعقود الصلاحيات والتسجيل والتعيينات والتدقيق |
| `docs/api` | عقود API للتسجيل والتفويض وإرسال الرصد |
| `docs/security` | مصفوفة صلاحيات وتوثيق نطاق التفويض |
| `docs/architecture` | حدود التطبيقات وسجل تدقيق مبدئي وسجل سير العمل |

لا توجد في شجرة الفرع الملفات `واجهات/مهما.md` أو `واجهات/تغيير.md` أو `واجهات/README.md` التي طلبت تعليمات المهمة قراءتها. كما أن ملفات التأسيس `database/migrations/001` و`002` غير موجودة ضمن الشجرة. لا يثبت ذلك أن الجداول غير موجودة في قاعدة البيانات؛ بل يعني أن تعريفاتها التأسيسية لا يمكن إثباتها من هذه الملفات.

## 3. مجموعات البيانات والعلاقات الظاهرة

الأسماء التالية مستخرجة من SQL والتوثيق، وليست ادعاءً بأن جميع تعريفات CREATE TABLE التأسيسية متاحة في المستودع:

### الهوية والصلاحيات
- `auth.users` مرجع هوية خارجي.
- `metra_user_profiles`
- `metra_account_states`
- `metra_role_catalogue`
- `metra_role_permissions`
- `meteorological_authorities`
- `countries`
- `authority_memberships`
- `permission_grants`
- `station_assignments)

### المحطات
- `station_catalogue`، ويرتبط بالسلطة المالكة والدولة، وتستخدمه سجلات الرصد والتعيينات.
- لا يوجد ضمن الملفات التي تمت مراجعتها تعريف تأسيسي كامل يثبت جميع أعمدة المحطة أو أنواعها أو القيود الجغرافية.

### التسجيل والتدقيق
- `registration_requests`
- `registration_audit_events)
- `station_audit_log)

### الرصد التشغيلي
- `metra_observations`
- `metra_observation_audit_events`
- `metra_observation_records` مذكور كغلاف استيراد قديم منفصل، ولم يتم تغييره أو إعادة استخدامه.

## 4. تفاصيل نموذج الرصد التشغيلي الظاهر في migration

جدول `public.metra_observations` في ملف الإنشاء يحتوي على:
- `id uuid` مفتاح أساسي مع `gen_random_uuid()`.
- `station_id uuid` مفتاح خارجي إلى `station_catalogue(id)`.
- `created_by uuid` و`reviewed_by uuid` مراجع إلى `auth.users(id)`.
- `observation_type text` محصور في daily/hourly/phenomenon.
- `observed_at timestamptz`.
- `payload jsonb` يشترط أن يكون object وألا يتجاوز 65536 بايت وفق `pg_column_size`.
- `status` و`initial_status` بقيود قيم محددة.
- `idempotency_key` بطول 1–128، مع uniqueness على station/user/key.
- حقول أوقات الإرسال والمراجعة والإنشاء والتحديث وملاحظة المراجعة.

جدول `metra_observation_audit_events` يستخدم مفتاحاً رقمياً identity، ومراجع إلى الرصد والمحطة والمستخدم، ونوع حدث وحالتي ما قبل/ما بعد وملاحظة ووقت UTC. توجد فهارس لمحطة/حالة/وقت الرصد، المنشئ/وقت الإنشاء، الرصد/وقت الحدث، وحقول المفاتيح الخارجية التي أضيفت في migration منفصل.

## 5. نتائج التدقيق والأولوية

### DB-001 — تعارض مؤكد بين قيد نوع الحدث ودالة قرار الرصد — حرج
قيد `event_type` في `metra_observation_audit_events` يسمح بالقيم:
`created_draft`, `submitted`, `returned`, `approved`, `resubmitted`.
لكن دالة `metra_decide_observation` تُدخل قيمة `p_decision` مباشرة، وهي `approve` أو `return_for_correction`. القيمتان لا تطابقان القيد؛ لذلك يتوقع أن يفشل INSERT في سجل التدقيق عند قرار الموافقة أو الإرجاع، مما يؤدي إلى rollback لمعاملة القرار. يلزم توحيد قاموس الأحداث مع اختبار تكاملي يثبت نجاح القرارين قبل أي نشر.

### DB-002 — غياب migrations التأسيسية من المستودع — حرج
سلسلة `database/migrations` تبدأ بالملف 003، بينما تعتمد على جداول كثيرة مثل المحطات والسلطات والأدوار والحسابات والتعيينات. لا يمكن إعادة بناء قاعدة البيانات من هذه السلسلة وحدها بصورة موثوقة. يجب استعادة ملفات 001 و002 أو توفير baseline schema موثق ومراجع؛ لا يجوز اختراع تعريفات بديلة.

### DB-003 — مجموعتا migrations منفصلتان — مرتفع
هناك 27 ملفاً في `database/migrations` وخمسة في `supabase/migrations`. الأولى تحتوي دورة الهوية والتسجيل والتعيينات والتفويض، والثانية تضيف الرصد التشغيلي وقراراته. يلزم سجل موحد يحدد الترتيب والاعتماديات ومصدر الحقيقة، مع التحقق من عدم وجود نسخ متعارضة للدوال. لا تُدمج المجلدات تلقائياً ولا يعاد ترقيم الملفات دون قرار معماري.

### DB-004 — مخطط الرصد مرن لكنه غير موصوف على مستوى الحقول — مرتفع
استخدام JSONB موحد مناسب لاستقبال الأنواع المختلفة وتطور الحقول، لكنه لا يثبت أنواع وحدات القياس أو قواعد requiredness أو المفاتيح المسموحة لكل نوع. يجب إضافة عقود payload ذات إصدار، ومخططات تحقق لكل نوع رصد، وربطها باختبارات API. يمكن لاحقاً اعتماد أعمدة/جداول تحليلية typed projections عند الحاجة إلى استعلامات عالية الكثافة.

### DB-005 — سير حالات الرصد غير مكتمل في العقد — مرتفع
الحالات الظاهرة تشمل draft/submitted/returned/approved، بينما عقد API يذكر حالياً إنشاء المسودة والإرسال فقط. يلزم تعريف انتقالات الحالة المسموحة، إعادة الإرسال بعد التصحيح، التحرير، المراجعة، الاعتماد، وإعادة الفتح إن كان مطلوباً. يجب أن تكون كل انتقالات الحالة معاملة ذرية مع سجل تدقيق.

### DB-006 — هوية المستخدم والمحطة — متوسط
النموذج يربط الرصد بـ `created_by` و`station_id`، ودوال الصلاحيات تتحقق من التكليف والعضوية والمنحة الفردية. يجب الحفاظ على قاعدة أن actor يأتي من JWT موثوق في API، وأن station scope يأتي من المسار/السجل الموثوق، لا من ادعاءات العميل. دوال SECURITY DEFINER تستلزم مراجعة دقيقة للمالك وsearch_path وEXECUTE grants.

### DB-007 — تخزين الصور والمرفقات — فجوة تصميم
لم يظهر في الملفات التي تمت مراجعتها نموذج مكتمل لمرفقات الرصد أو صور السجلات الورقية. المقترح: metadata table مستقلة تربط الملف بسجل الرصد/المحطة، مع object key عشوائي، MIME/size/hash، uploader، وقت الإنشاء، تصنيف الملف، حالة الفحص، وسياسة retention. تخزن الملفات في private bucket وتصدر روابط قصيرة العمر بعد تفويض API. لا تخزن الصور كـ base64 داخل JSONB ولا تجعل bucket عاماً.

### DB-008 — الاحتفاظ والتدقيق — فجوة سياسة
سجل التدقيق مصمم كإلحاق فقط مع منع UPDATE/DELETE على مستوى trigger وسياسات وصول مقيدة. لكن لم يظهر جدول احتفاظ موحد يحدد فترات الاحتفاظ للبيانات التشغيلية والصور وسجلات التدقيق، أو legal hold، أو آلية الأرشفة. لا ينبغي حذف السجلات المناخية الأصلية؛ يلزم اعتماد سياسة مستقلة لكل فئة بيانات.

### DB-009 — الأداء والتوسع — يحتاج قياساً
الفهارس الأساسية للرصد موجودة في migrations. لا توجد بيانات حجم أو حمل فعلية تسمح بتقدير partitioning أو أحجام التخزين. اجمع أحجاماً متوقعة حسب عدد المحطات، تقارير الساعة/اليوم، الصور، ومدة الاحتفاظ. اختبر استعلامات المحطة والفترة والحالة، وراجع EXPLAIN ANALYZE على نسخة اختبارية فقط قبل اعتماد فهارس إضافية أو تقسيم زمني.

### DB-010 — منع تكرار الرصد — قرار أعمال مطلوب
مفتاح idempotency يمنع تكرار إعادة إرسال الطلب نفسه للمستخدم والمحطة، لكنه لا يمنع تلقائياً سجلين مختلفين لنفس المحطة والنوع ووقت الرصد. يجب تحديد هل يسمح بالتصحيح/الإصدارات المتعددة، أم يلزم unique business key أو سجل revision مستقل.

## 6. تصور موحد مقترح

التقسيم المنطقي المقترح، دون اعتماد DDL:
1. Reference: countries, meteorological_authorities, station_catalogue, measurement/phenomenon code catalogues.
2. Identity & Access: profiles, account_states, role_catalogue, role_permissions, authority_memberships, permission_grants, station_assignments.
3. Observations: observation_headers, typed/versioned payload contracts, observation_revisions, observation_status_history.
4. Attachments: observation_attachments metadata + private object storage.
5. Review & Audit: observation_review_decisions, append-only audit events, registration/station/authority audit.
6. Reporting: read models/materialized aggregates منفصلة عن سجل الرصد الأصلي.
7. Climate QA: quality flags, homogenization runs, algorithm/version metadata, station series lineage، مع عزل مخرجات Climatol عن القيم الأصلية.

يجب أن يظل كل وقت مخزن بصيغة UTC/timestamptz، مع تعريف صريح لمعنى وقت الرصد والفترة المرجعية. لا يُخزن التوقيت المحلي كحقيقة موازية إلا إذا كان متطلباً أرشيفياً موثقاً.

## 7. بوابات ما قبل أي migration

- استعادة baseline schema ونسخة مرجعية من جميع migrations.
- اعتماد قاموس المحطات الجديد ومصدره وإصداره؛ لا تستخدم الكتالوج القديم.
- توحيد ترتيب migrations في مسار نشر واحد قابل لإعادة الإنتاج.
- معالجة DB-001 واختبار قرار الموافقة والإرجاع.
- توثيق payload schema version لكل نوع رصد ووحداته ومؤشرات القيم المفقودة.
- اعتماد نموذج المرفقات والاحتفاظ والتدقيق.
- مراجعة RLS وgrants وSECURITY DEFINER وStorage policies.
- مراجعة API/Angular/Flutter contracts مع مالكي هذه المسارات.
- موافقة المستخدم الصريحة على المخطط وخطة migrations قبل لمس المشروع `tbdnklyxjvbrilvnwgmq`.

## 8. ما لم يتم فعله

لم يتم الاتصال بـ Supabase، ولم يتم تنفيذ SELECT أو DDL أو migration على أي مشروع، ولم يتم تشغيل seed، ولم يتم تعديل قاعدة بيانات قديمة أو جديدة، ولم يتم استيراد بيانات أو كتالوج محطات.


## 10. الجولة الثانية — مراجعة تفصيلية لمسارات migrations (2026-11-11)

**توقيت الفحص:** 2026-11-10T23:31:27.570Z UTC.
**النطاق:** قراءة ملفات SQL الـ32 الموجودة في `database/migrations` و`supabase/migrations`، وقراءة اختبارات shell وعقود API المتاحة ذات الصلة. لم يتم تشغيل SQL أو الاختبارات.

### 10.1 سجل مجموعات migrations

| المجموعة | الملفات | الوظيفة الظاهرة | ملاحظة الاعتماد |
|---|---:|---|---|
| صلاحيات المحطة والتسجيل | database 003–011 | دوال تفويض المحطة، صلاحيات مراجعة المحطات والتسجيل، قوائم المراجعة ودليل مستخدمي المحطة | تعتمد على جداول تأسيسية غير موجودة في الشجرة الحالية |
| تعيينات المحطة والتدقيق | database 012–014 | طلب/اعتماد/رفض/إلغاء تعيينات المحطة وقراءة سجل التدقيق | تعتمد على station_assignments وstation_audit_log وقيود تداخل الفترات من baseline |
| تفويض نطاق السلطة | database 015–019 | تفويض authority-scope وربط قرارات التسجيل والمحطة بالسلطة والمحطة المطلوبة والتحقق من NULL | تعيد تعريف دوال سابقة؛ يجب تثبيت ترتيبها وعدم تطبيقها منفردة |
| دورة العضوية والمنح | database 020–025 | authority_id للمنح، سجل تدقيق، إنشاء/مراجعة/إلغاء العضويات والمنح، ربط المسار، منع اعتماد subject غير نشط | migration 020 يتطلب backfill سابقاً لقيم authority_id لكنه لا يتضمنه |
| نماذج قراءة دليل السلطة | database 026–029 | خيارات الأدوار والصلاحيات، دليل السلطات، قوائم الانتظار والسجلات المجدولة للإلغاء | 029 يوسع نطاق دليل الإلغاء ليشمل السجلات المعتمدة مستقبلاً |
| الرصد التشغيلي | supabase 5 ملفات | إنشاء الرصد، رفض وصول العملاء، فهارس FK، دالة قرار المراجعة، تشديد NULL | يوجد تعارض مثبت في event_type بين القيد ودالة القرار |

### 10.2 نتائج إضافية مسجلة

#### DB-011 — migration 020 يفتقر إلى خطوة backfill لـ authority_id — مرتفع / حاجب للنشر
الملف يضيف `permission_grants.authority_id` كعمود nullable، ثم يوقف التنفيذ إذا بقي أي صف بقيمة NULL، وبعدها يجعله NOT NULL ويضيف FK. لا توجد في الملف عملية UPDATE/backfill ولا توجد وثيقة تشغيل تحدد خريطة إسناد grants القديمة إلى authority. لذلك قد يفشل تطبيقه على قاعدة تحتوي منحاً موجودة. المطلوب خطة backfill مراجعة ومتحققة، أو تأكيد أن الجدول فارغ في baseline، قبل أي تشغيل. لا تنفذ الآن.

#### DB-012 — payload الرصد لا يملك عقداً بنيوياً لكل نوع — مرتفع
التحقق الحالي يضمن JSON object وحجم 64 KiB فقط. لا توجد قيود SQL أو JSON Schema versioned تثبت الحقول المطلوبة والوحدات ومجالات القيم لكل من daily/hourly/phenomenon. عقد API يصف مثالاً فقط، ووثيقة الظواهر نفسها تقر بأن المخطط غير معتمد. يلزم contract version ومصفوفة قياسات/وحدات ومؤشرات missing/trace قبل اعتماد البيانات.

#### DB-013 — سجل تدقيق الرصد أقل تحصيناً من سجل تدقيق السلطة — متوسط
`authority_access_audit_events` يملك trigger statement-level يمنع UPDATE/DELETE/TRUNCATE، بينما `metra_observation_audit_events` يملك trigger row-level يمنع UPDATE/DELETE فقط. صلاحيات service_role الظاهرة هي SELECT/INSERT ولا تمنحه TRUNCATE، لذلك لا يوجد دليل على ثغرة استغلال مباشرة عبر الدور الحالي؛ لكن الاتساق الدفاعي ضعيف ويستحسن حماية TRUNCATE أيضاً ضمن مراجعة baseline/ownership.

#### DB-014 — idempotency لا يحسم تكرار العمل المناخي — متوسط / قرار أعمال
القيد الفريد هو (station_id, created_by, idempotency_key)، وهو مناسب لإعادة إرسال نفس الطلب، لكنه لا يمنع إدخال رصدين بمفتاحين مختلفين للمحطة والنوع والوقت نفسيهما. يجب تحديد قواعد uniqueness حسب daily/hourly/phenomenon وما إذا كان التصحيح يمثل revision مستقلاً.

#### DB-015 — دوال القراءة تعتمد على تفويض API لا تفويض SQL مستقل — متوسط
عدة read-model functions تقبل station_id أو authority_id وتُنفذ بصلاحية service_role ولا تتحقق داخلياً من actor permission (مثل قوائم تسجيل المحطة وسجل المحطة). العقود الحالية تعتمد على حواجز API. يجب إثبات أن كل endpoint يتحقق من النطاق قبل استدعاء RPC، ومراجعة عدم وجود مسار داخلي آخر يستدعيها دون تفويض. هذا ليس إثبات تجاوز حالياً، بل حد ثقة معماري يحتاج اختبار تكامل.

### 10.3 ما تدعمه الاختبارات الموجودة وما لا تدعمه

وجدت اختبارات shell تعتمد على grep للتحقق من وجود نصوص وعقود SQL/API في الملفات، منها:
- `verify_station_permission_rpc.sh`
- `verify_authority_permission_rpc.sh`
- `verify_registration_review_contract.sh`
- `verify_station_assignment_workflow_contract.sh`
- `verify_station_audit_contract.sh`
- `verify_authority_access_lifecycle_contract.sh`

هذه اختبارات static contract وليست اختبارات PostgreSQL فعلية؛ لا تثبت نجاح تطبيق migrations أو صحة القيود وقت التشغيل أو سلوك المعاملات والتزامن. لم أشغلها في هذه الجولة لعدم وجود checkout محلي متاح عبر أدوات هذه الجولة، ولم أطلب CI. لا يوجد ادعاء نجاح.

### 10.4 فجوات لا تزال محجوبة

- لا توجد migrations تأسيسية 001/002 في الشجرة، ولذلك لا يمكن إثبات تعريفات CREATE TABLE الأصلية لكل الجداول أو جميع أنواع الأعمدة والقيود والفهارس.
- لا يوجد كتالوج محطات جديد معتمد في هذه الملفات؛ لا يجوز تعبئة أو استنتاج station rows.
- لا يوجد تصميم مرفقات مكتمل أو bucket policy ضمن الملفات التي تمت مراجعتها.
- لا توجد بيانات حمل فعلية أو قياسات حجم تسمح بحكم partitioning أو retention thresholds.
- لا توجد سياسة احتفاظ معتمدة للبيانات المناخية الأصلية والمرفقات وسجلات التدقيق.

### 10.5 ملفات إضافية فُحصت

- ملفات migrations: جميع 27 ملفاً من `database/migrations/003` حتى `029`، وجميع 5 ملفات في `supabase/migrations`.
- اختبارات: `verify_authority_access_lifecycle_contract.sh`, `verify_authority_permission_rpc.sh`, `verify_registration_review_contract.sh`, `verify_station_assignment_workflow_contract.sh`, `verify_station_audit_contract.sh`, `verify_station_permission_rpc.sh`.
- عقود: `docs/api/operational-observation-submission.md`, `docs/weather-phenomena-api-and-schema-proposal.md`.

### 10.6 حالة التنفيذ

تمت قراءة الملفات وتوثيق النتائج فقط. لم تُشغّل الاختبارات، ولم تُنفذ migrations أو SQL، ولم يتم الاتصال بأي مشروع Supabase أو تغيير أي قاعدة بيانات.
