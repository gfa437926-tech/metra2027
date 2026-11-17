# سجل مراجعة ملفات migrations — METRA 2027

- آخر تحديث: 2026-11-10T23:31:27.570Z (UTC)
- المهمة: METRA-DB-08
- الحالة: قيد التنفيذ
- النطاق: مراجعة ساكنة لمحتوى الملفات، دون تشغيلها.

## جرد الملفات

### database/migrations — 27 ملفاً

| النطاق | الملفات | موضوع التغيير |
|---|---|---|
| صلاحيات المحطة والتسجيل | 003–007 | تفويض station-scope، صلاحيات مراجعة الكتالوج والتسجيل |
| نماذج القراءة والتسجيل | 008–011 | قوائم التسجيل، حالة الحساب، دليل مستخدمي المحطة |
| تكليفات المحطة والتدقيق | 012–014 | طلب/قرار/إلغاء التكليف وسجل التدقيق |
| تفويض السلطة | 015–019 | authority-scope، مراجعة المحطة والتسجيل، ربط الطلب بمحطته، تحقق NULL |
| دورة العضوية والمنح | 020–025 | authority_id، عضويات السلطة، منح الصلاحيات، التدقيق، الإلغاء، منع اعتماد subject غير نشط |
| نماذج القراءة | 026–029 | كتالوج السلطة وخيارات الصلاحيات وقوائم انتظار/إلغاء الوصول المجدول |

### supabase/migrations — 5 ملفات

| الملف | الوظيفة |
|---|---|
| 20261103164003_create_operational_observation_submission.sql | إنشاء جداول الرصد التشغيلي ودالة الإرسال |
| 20261103164045_deny_client_access_to_operational_observations.sql | سياسات رفض وصول anon/authenticated |
| 20261103164638_index_operational_observation_foreign_keys.sql | فهارس مفاتيح أجنبية إضافية |
| 20261103215400_observation_review_decision.sql | قرار اعتماد/إرجاع الرصد |
| 20261103220500_harden_observation_decision_null_validation.sql | تشديد تحقق NULL في القرار |

## سجل المخاطر

| ID | الأولوية | النتيجة | الدليل |
|---|---|---|---|
| DB-001 | حرج | قرار الرصد يكتب approve/return_for_correction في event_type بينما القيد يقبل approved/returned | migration الإنشاء + migration القرار |
| DB-002 | حرج | baseline migrations 001/002 غير موجودة في شجرة الفرع | شجرة Git |
| DB-011 | مرتفع | migration 020 يتطلب authority_id backfill سابقاً لكنه لا ينفذه | 020: ADD COLUMN ثم abort عند وجود NULL ثم SET NOT NULL |
| DB-012 | مرتفع | payload لا يحقق schema خاصاً بكل نوع؛ فقط object وحجم 64KiB | 20261103164003 + عقد API |
| DB-013 | متوسط | trigger تدقيق الرصد لا يمنع TRUNCATE مثل سجل تدقيق السلطة | migration الرصد مقابل migration 020 |
| DB-014 | متوسط | idempotency key لا يحسم تكرار المحطة/النوع/وقت الرصد بمفاتيح مختلفة | قيد unique في جدول الرصد |
| DB-015 | متوسط | read models تعتمد على API لتفويض actor/narrow scope؛ بعض RPCs لا تتحقق من صلاحية الفاعل داخلياً | migrations 008/010/014 و026–029 |

## اختبارات المصدر

تمت قراءة 6 اختبارات shell ذات صلة. هي static grep contract tests تتحقق من وجود fragments في ملفات SQL وAPI. لا تمثل اختبارات PostgreSQL فعلية ولا تثبت نجاح migrations أو سلامة المعاملات. لم يتم تشغيلها في هذه الجولة.

## بوابات الاعتماد

1. استعادة baseline 001/002 أو تقديم schema snapshot موثوق.
2. خطة backfill موقعة ومختبرة لـ permission_grants.authority_id.
3. إصلاح DB-001 في proposal منفصل، مع اختبار PostgreSQL للقرارين.
4. إصدار JSON Schema/typed contracts لكل observation_type.
5. اختبارات تكامل PostgreSQL للـ RLS/grants/SECURITY DEFINER والتزامن.
6. قرار قواعد تكرار الرصد والتصحيح والإصدارات.
7. اعتماد نموذج المرفقات والاحتفاظ.

## الحدود

لا يحتوي هذا السجل على DDL جديد قابل للتطبيق. لم يتم تشغيل SQL أو migration أو seed، ولم يتم الاتصال بـ Supabase. جميع النتائج مستخرجة من Git فقط.
