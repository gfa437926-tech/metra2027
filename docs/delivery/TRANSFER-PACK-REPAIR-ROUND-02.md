# METRA 2027 — تقرير إصلاح حزمة النقل والتحقق من البيانات (الجولة 02)

- التاريخ: 2026-11-14
- الفرع: `work/execution-master-2026-11-14`
- آخر commit اجتاز حزمة CI كاملة: `f3101cac1a3940edd1be4692f47b51048b2b2c08`
- مشروع المصدر المسموح: `tbdnklyxjvbrilvnwgmq`
- مشروع الهدف: لم يحدده المالك بعد.
- لا يوجد ادعاء بتصدير حي أو استعادة إلى هدف جديد.

## 1. ما أُنجز فعلياً في المستودع

1. حصر المصدر في مشروع Supabase التجريبي المعتمد، والتحقق من تطابق مرجع المشروع مع مضيف Postgres المباشر أو اسم مستخدم Supavisor.
2. إضافة تصدير مخططي `public` و`private` مع إزالة أوامر إنشاء المخططات الموجودة مسبقاً من pg_dump قبل الاستعادة.
3. إضافة تشفير GPG AES-256، وبصمات SHA-256، وتضمين `MANIFEST.txt` ضمن ملف البصمات، والتحقق من المصدر وسياسة البيانات قبل الاستيراد.
4. إضافة استيراد المخطط والبيانات إلى هدف جديد فارغ فقط، مع تحقق من الامتدادات المطلوبة قبل أي كتابة.
5. إضافة إنشاء دور `metra_api_runtime` غير القابل لتسجيل الدخول، واستعادة ACLs لأدوار Supabase وصلاحيات الجداول والتسلسلات والدوال ومخطط `private` وامتيازات `PUBLIC` والـ default privileges.
6. إضافة مقارنة دقيقة لأعداد الصفوف وبصمات محتوى SHA-256 لكل جدول منقول.
7. إضافة بصمات بنية الأعمدة والدوال والقيود والفهارس والمحفزات وسياسات RLS.
8. إضافة مقارنة ACLs والامتدادات المطلوبة وإصداراتها ومخططها، وفحص جودة كتالوج المحطات.
9. استبعاد بيانات `public.metra_observation_records` من التصدير عمداً؛ يحتفظ التصدير بالبنية فقط، ولا ينقل السجلات غير التجريبية.
10. إضافة اختبارات pg_dump حقيقية، وGPG، وmanifest، وACLs، وبصمات البيانات، ومنع الاستيراد إلى هدف غير فارغ.

### الملفات الرئيسية المضافة أو المعدلة

- `.github/workflows/transfer-pack.yml`
- `database/transfer/scripts/00_preflight.sh`
- `database/transfer/scripts/01_export_source.sh`
- `database/transfer/scripts/02_bootstrap_target.sh`
- `database/transfer/scripts/03_import_schema.sh`
- `database/transfer/scripts/04_import_data.sh`
- `database/transfer/scripts/05_compare.sh`
- `database/transfer/scripts/06_apply_runtime_grants.sh`
- `database/transfer/scripts/lib/project_url_guard.sh`
- `database/transfer/sql/bootstrap_target_roles.sql`
- `database/transfer/sql/apply_runtime_grants.sql`
- `database/transfer/sql/compare_rowcounts.sql`
- `database/transfer/sql/compare_data_hashes.sql`
- `database/transfer/sql/compare_objects.sql`
- `database/transfer/sql/compare_acl_inventory.sql`
- `database/transfer/sql/compare_extensions.sql`
- `database/transfer/sql/station_catalogue_provenance.sql`
- `database/transfer/sql/compare_excluded_data.sql`
- `database/transfer/sql/assert_empty_application_tables.sql`
- `database/transfer/tests/` — اختبارات URL وmanifest وpg_dump وACLs وPostgreSQL المعزول.
- `database/transfer/README.md` وملفات `RESTORE-GUIDE.md` و`CUTOVER-CHECKLIST.md`.

## 2. نتائج الفحص للقراءة فقط على مصدر Supabase

### بنية التطبيق والصلاحيات

- 23 جدولاً في مخطط `public`.
- 46 دالة/إجراء في `public/private`.
- 99 فهرساً، 198 قيداً، 18 محفزاً، 29 سياسة RLS، 264 عموداً، و6 تسلسلات في جرد البنية.
- جرد ACL يحتوي 291 بنداً بين خصائص الأدوار وصلاحيات المخططات والجداول والتسلسلات والدوال وPUBLIC والـ default ACLs.
- جميع كائنات التطبيق المفحوصة في `public/private` مملوكة للدور `postgres`؛ لذا فإن الاستعادة إلى `postgres` تتوافق مع ملكية المصدر التي تم فحصها.

### الامتدادات المطلوبة

تم رصد 7 امتدادات:

- `btree_gist 1.7` — `extensions`
- `pg_stat_statements 1.11` — `extensions`
- `pg_trgm 1.6` — `extensions`
- `pgcrypto 1.3` — `extensions`
- `plpgsql 1.0` — `pg_catalog`
- `supabase_vault 0.3.1` — `vault`
- `uuid-ossp 1.1` — `extensions`

الاستيراد يرفض المتابعة إذا لم تكن الامتدادات المطلوبة متوفرة بالإصدار والمخطط نفسيهما. لا ينشئها تلقائياً.

### سياسة البيانات

- `metra_observation_records`: 58,059 سجلاً، كلها مصنفة `is_demo=false`.
- 1,251 من هذه السجلات بلا `station_id`.
- **لم تُصدّر هذه السجلات**؛ الجدول يبقى في المخطط ويجب أن يكون فارغاً في الهدف.
- `auth.users`: صفر مستخدمين في لقطة المصدر التي تم فحصها.
- كتالوج المحطات الجديد: 65 محطة، منها 62 غير تجريبية و3 تجريبية.
- الإحداثيات: 50 صفاً و50 محطة مرتبطة؛ 15 محطة بلا إحداثيات.
- لا توجد إحداثيات يتيمة أو معرفات محطات مكررة في جدول الإحداثيات.

كتالوج المحطات هو الكتالوج الجديد المعتمد في هذا البناء؛ لا يجري استيراد قائمة المحطات القديمة. فجوات الإحداثيات موثقة ولا تُخترع لها إحداثيات.

## 3. نتائج CI المثبتة

على commit `f3101cac1a3940edd1be4692f47b51048b2b2c08`:

- <badge color="success">نجح</badge> Database transfer pack checks — Run #285.
- <badge color="success">نجح</badge> METRA transfer safety and Auth remap tests — Run #4.
- فحص Bash وحارس هوية المشروع.
- اختبار تطبيع مخطط pg_dump الحقيقي، واستبعاد بيانات الجدول المحدد من pg_dump.
- اختبار manifest ومصدره وسياسة عدم نقل مستخدمي Auth والسجلات غير التجريبية.
- اختبار bootstrap للأدوار وصلاحيات الجداول والتسلسلات والدوال.
- اختبار جرد ACL والامتدادات.
- اختبار أعداد الصفوف وبصمات SHA-256 وتغير البصمة عند تعديل صف.
- اختبار قيود الهدف الفارغ وخلو جدول الرصد المستبعد.
- اختبار اكتشاف العبث ببصمات الملفات.
- اختبار تشفير GPG وفك التشفير.

روابط التحقق:
- https://github.com/gfa437926-tech/metra2027/actions/runs/43611275218
- https://github.com/gfa437926-tech/metra2027/actions/runs/43611275277

## 4. ما لم يُنفّذ

- **لم يُنفّذ** تشغيل `00_preflight.sh` باستخدام Database URL فعلي؛ فحص المصدر الحالي تم عبر اتصال Supabase للقراءة فقط، دون الحصول على كلمة مرور قاعدة البيانات.
- **لم يُنفّذ** تصدير حي من المصدر إلى ملفات مشفرة؛ لم تتوفر في هذه الجولة بيانات اتصال Postgres وكلمة مرور GPG ضمن بيئة تنفيذ آمنة.
- **لم يُنفّذ** إنشاء أو استيراد إلى مشروع Supabase هدف؛ مرجع الهدف لم يقدمه المالك بعد.
- **لم يُنفّذ** استعادة كاملة من نسخة المصدر إلى هدف فعلي.
- **لم يُنفّذ** اختبار تطابق المصدر والهدف الحي.
- **لم يُنفّذ** نقل مستخدمي Auth؛ المصدر يحتوي صفراً من المستخدمين في وقت الفحص.
- **لم يُنفّذ** ربط التطبيق بقاعدة هدف جديدة أو Cutover.
- **لم يُنفّذ** حذف أو تعديل أي قاعدة Supabase مستضافة.
- **لم يُنفّذ** دمج إلى `main`.

## 5. الخطوات المتبقية

1. تشغيل Preflight للقراءة فقط ثم التصدير المشفر من المصدر عبر بيئة آمنة تتوفر فيها بيانات الاتصال وكلمة مرور التشفير.
2. تحديد مشروع Supabase الهدف الجديد والتحقق من فراغه وامتداداته.
3. تشغيل Bootstrap واستعادة مخططي `public/private` على الهدف.
4. تطبيق ACLs ثم استيراد بيانات الكتالوج والمرجع فقط؛ عدم نقل سجل الرصد غير التجريبي.
5. تشغيل المقارنة الحية: SHA-256 للبيانات، بنية المخطط، ACLs، الامتدادات، جودة المحطات، وخلو جدول الرصد المستبعد.
6. اختبار Restore مستقل ثم اختبار تسجيل الدخول وواجهات .NET وFlutter على الهدف بمفاتيح جديدة.
7. إصدار تقرير قبول قبل أي Cutover؛ يبقى المصدر محفوظاً ولا يُحذف.

## 6. التقدم

- مرحلة تدقيق المصدر وتصميم حدود النقل: مكتملة.
- مرحلة تنفيذ الحزمة واختبارها في CI مع PostgreSQL معزول: مكتملة.
- مراحل التصدير الحي والاستيراد إلى الهدف والاستعادة والقبول: **لم تُنفّذ**.

**إنجاز حزمة النقل البرمجية والاختبارات: 2 من 5 مراحل (40%).**
**المتبقي: 7 خطوات** كما في القسم 5.

هذه النسبة تخص حزمة النقل فقط، ولا تمثل نسبة اكتمال METRA 2027 بالكامل.
