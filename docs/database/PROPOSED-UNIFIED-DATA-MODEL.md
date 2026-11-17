# METRA 2027 — التصور الموحد لمخطط البيانات (مقترح للمراجعة)

الحالة: تصور منطقي فقط، غير معتمد، ولا يحتوي على DDL قابل للتنفيذ.

## مبادئ التصميم
- PostgreSQL هو مصدر الحقيقة للقيود والعلاقات والمعاملات.
- ASP.NET Core API هو مسار الكتابة والقراءة المصرح به؛ Angular وFlutter لا يتصلان مباشرة بقاعدة البيانات.
- هوية الحساب منفصلة عن العضوية في السلطة وتكليف المحطة والمنح الفردية للصلاحيات.
- لا تمنح قيمة role وحدها حق الوصول إلى محطة.
- سجلات الرصد الأصلية غير قابلة للاستبدال الصامت؛ التصحيح ينشئ revision أو حدثاً موثقاً.
- كل التواريخ/الأوقات التشغيلية UTC باستخدام timestamptz.
- المرفقات في private object storage والبيانات الوصفية في PostgreSQL.
- كل payload له schema_version ووحدة قياس وقواعد null/missing محددة.

## المجالات والعلاقات

### 1. المرجع الجغرافي والتشغيلي
- countries 1—N meteorological_authorities
- meteorological_authorities 1—N station_catalogue
- station_catalogue يحتفظ بمعرف ثابت، رمز رسمي فريد ضمن النطاق المعتمد، اسم متعدد اللغات، إحداثيات، ارتفاع ومرجع رأسي، حالة الاعتماد والتشغيل، وفترة صلاحية/نسخة كتالوج.
- لا تُنشأ سجلات محطات من كتالوج قديم. لا تُملأ هذه المجموعة حتى وصول كتالوج المحطات الجديد واعتماده.

### 2. الهوية والصلاحيات
- auth.users 1—1 metra_user_profiles
- auth.users 1—N metra_account_states (أو سجل حالة حالي مع history إذا تقرر ذلك)
- metra_role_catalogue 1—N metra_role_permissions
- users N—N meteorological_authorities عبر authority_memberships
- users N—N stations عبر station_assignments
- permission_grants مستقلة عن assignment وتخضع للموافقة والصلاحية الزمنية والإلغاء.
- جميع قرارات التعيين والمنح مرتبطة بممثل منفذ وسبب ووقت ومراجعة ثانية عند الحاجة.

### 3. الرصد
- station_catalogue 1—N observations
- observations يحتوي على معرف، محطة، منشئ، نوع، observed_at UTC، حالة workflow، مفتاح idempotency، schema_version، ومعلومات الإنشاء/الإرسال.
- payload versioned ومقيد بمخطط خاص بـ daily/hourly/phenomenon وبقية أنواع الرصد بعد حصرها.
- revisions تحفظ النسخ السابقة وسبب التصحيح ومنشئه ووقته.
- status history يسجل كل انتقال حالة قبل/بعد، الفاعل، السبب والوقت.
- business uniqueness يحدد لكل نوع رصد بعد قرار قواعد التكرار؛ لا يفرض قيداً عاماً قبل معرفة قواعد التقارير.

### 4. المرفقات
- observation_attachments يرتبط بسجل الرصد وبالمحطة وبالمستخدم الرافع.
- الحقول المقترحة: id, observation_id, station_id, object_key, original_filename, detected_mime_type, byte_size, sha256, category, uploaded_by, uploaded_at, scan_status, retention_class.
- الملفات private؛ التنزيل عبر تفويض API ورابط قصير العمر.
- لا تحفظ بايتات الملفات أو base64 داخل JSONB.

### 5. التدقيق والمراجعة
- audit_events append-only، مع actor, action, entity_type, entity_id, occurred_at, reason, before/after أو diff محدود.
- لا تحفظ أسرار المصادقة أو tokens أو بيانات شخصية غير لازمة في before/after.
- لا تمنح العملاء صلاحية تعديل أو حذف سجل التدقيق.
- قرارات المراجعة منفصلة أو ممثلة بأحداث صريحة مع state transition ذري.

### 6. التقارير والتحليل المناخي
- جداول/Views للقراءة فقط أو materialized aggregates، مع تحديد refresh strategy.
- لا تُخلط المجاميع المشتقة مع السجلات الأصلية.
- climate quality flags وhomogenization runs تحفظ نسخة الخوارزمية والمعلمات والمدخلات ومصدر السلسلة ومخرجات Climatol.
- أي تصحيح أو تجانس يجب أن يحافظ على lineage وإمكانية إعادة الإنتاج.

## استراتيجية الفهارس والأداء
- فهارس مركبة تبدأ بمفتاح نطاق الاستخدام مثل station_id ثم observed_at، وتضاف status/type حسب استعلامات فعلية.
- فهارس لكل FK على الجداول الكبيرة إذا لم تغطها فهارس مركبة مناسبة.
- keyset pagination للتقارير الكبيرة؛ تجنب OFFSET العميق.
- partitioning زمني للرصد/التدقيق فقط بعد قياس الحجم ومعدل الإدخال وخطط الاحتفاظ.
- materialized views للتقارير الثقيلة بعد تحديد freshness SLA.
- اختبارات EXPLAIN ANALYZE على بيانات اصطناعية ممثلة، لا على قاعدة الإنتاج.

## سياسة الاحتفاظ المقترحة
تعتمد سياسة مستقلة حسب الفئة: السجلات المناخية الأصلية، revisions، audit، صور السجلات، الملفات المؤقتة، سجلات التطبيق. لا تحذف بيانات الرصد الأصلية تلقائياً. الصور والملفات المؤقتة تحتاج دورة lifecycle وفحص سلامة وحفظ قانوني عند الحاجة. مدد الاحتفاظ النهائية قرار مؤسسي وليست مفترضة في هذا المقترح.

## قرارات مطلوبة قبل DDL
1. اعتماد كتالوج المحطات الجديد ومفاتيحه وإصداره.
2. تحديد جميع أنواع الرصد والحقول والوحدات ومؤشرات القيم المفقودة.
3. تحديد قواعد التكرار والتصحيح والإصدارات.
4. تحديد فئات المرفقات وحدود الحجم والصيغ المسموحة.
5. تحديد مدد الاحتفاظ والتدقيق والأرشفة.
6. اعتماد صلاحيات كل دور ونطاقه.
7. استعادة baseline schema وترتيب migration history.
