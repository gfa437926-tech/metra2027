# حزمة مراجعة قاعدة البيانات — للموافقة فقط (لا تطبيق)

**المستودع:** `gfa437926-tech/metra2027`  
**الفرع المرجعي:** `work/legacy-ui-migration-audit`  
**الغرض:** عرض مخطط مقترح + مخاطر + خطة تطبيق على **مشروع Supabase الجديد فقط**.  
**محظور دون موافقة صريحة:** أي `psql` / migration apply / RLS / Grants / Seeds على المستضاف.  
**محظور دائماً:** القاعدة القديمة وبياناتها ومحطاتها.

---

## 1) ملخص تنفيذي

| البند | الحالة |
|---|---|
| ملفات SQL في المستودع | موجودة ومرتبة زمنياً تحت `supabase/migrations/` |
| تطبيق على مستضاف | **غير مثبت** من هذا المستند |
| مسار Npgsql Ops | يعتمد على migrations 11–12 + سلسلة `MetraOps` |
| دفتر أرشفة Excel | migration 13 معلّم review_only |
| اختبارات disposable PG | ملفات تحت `database/tests/` — ليست نشراً |

**نجاح CI ≠ تطبيق المخطط على Supabase.**

---

## 2) قائمة Migrations المقترحة (ترتيب التطبيق على الجديد فقط)

| # | الملف | الجداول / الكائنات الرئيسية | RLS / صلاحيات | مخاطرة |
|---|---|---|---|---|
| 1 | `20261103164003_create_operational_observation_submission.sql` | نشرات تشغيلية + تدقيق | revoke عميل | عالية إن طُبقت جزئياً |
| 2 | `20261103164045_deny_client_access_to_operational_observations.sql` | — | منع anon/authenticated | متوسطة |
| 3 | `20261103164638_index_operational_observation_foreign_keys.sql` | فهارس | — | منخفضة |
| 4 | `20261103215400_observation_review_decision.sql` | RPC قرار مراجعة | service_role | عالية |
| 5 | `20261103220500_harden_observation_decision_null_validation.sql` | تحقق NULL | — | متوسطة |
| 6 | `20261107020000_harden_observation_decision_sod_and_audit.sql` | SoD + أحداث تدقيق | حماية سجلات | عالية |
| 7 | `20261107021500_observation_resubmit_after_return.sql` | إعادة تقديم | — | متوسطة |
| 8 | `20261107030000_equipment_faults_station_scoped.sql` | أعطال معدات | نطاق محطة | عالية |
| 9 | `20261107031000_support_incidents_station_scoped.sql` | حوادث دعم | نطاق محطة | عالية |
| 10 | `20261107032000_harden_ops_rls_and_assignee_checks.sql` | RLS + مُسند | سياسات | عالية |
| 11 | `20261108010000_metra_ops_runtime_role_and_fault_read.sql` | أدوار ops | NOLOGIN | عالية |
| 12 | `20261108020000_npgsql_ops_session_context_rls.sql` | `app.station_id` / `app.user_id` | RLS جلسة | عالية |
| 13 | `20261110180000_manual_archive_ledger_review_only.sql` | دفتر أرشفة يدوية | معلّق | **موافقة منفصلة** |

**سكربتات إضافية:** `database/migrations/` (تسجيل، تعيينات، سلطات، RPCs) — تُراجع كحزمة مستقلة على نفس المشروع الجديد.

---

## 3) نموذج العلاقات المنطقي (مستوى التطبيق)

```
station_catalogue (معتمد مسبقاً في الهوية)
    ├── operational observations (ساعي/يومي/ظاهرة)
    │       ├── review decisions
    │       └── audit events (append-only مقصود)
    ├── equipment_faults + audit
    ├── support_incidents + transitions
    ├── registration / assignment queues (عبر RPC)
    └── manual_archive_confirmations (اختياري — بند 13)
```

كل مسار بيانات تشغيلية يجب أن يحمل **station_id** ويُقيَّد بصلاحية المحطة على API + RLS حيث وُجد.

---

## 4) سياسات RLS والأدوار (مقترح من الملفات — غير مفعّل هنا)

| الدور / الممثل | المقصود |
|---|---|
| `anon` / `authenticated` | **لا** وصول مباشر لجداول التشغيل الحساسة |
| `service_role` (PostgREST من الخادم فقط) | استدعاء RPC بعد تحقق JWT وصلاحية المحطة في API |
| أدوار `metra_ops` / Npgsql | اتصال محدود + `SET LOCAL` لهوية المحطة/المستخدم داخل المعاملة |

**قاعدة:** فشل خدمة الصلاحيات = رفض (fail-closed)، وليس سماح.

---

## 5) الفهارس والقيود (من migrations)

- فهارس مفاتيح أجنبية للنشرات (ملف 3).
- قيود انتقال حالة الأعطال/الدعم داخل SQL حيث وُجدت.
- منع تعديل/حذف أحداث تدقيق القرارات حيث وُجد trigger/سياسة (ملف 6 وما يليه).

مراجعة تفصيلية سطراً بسطر: افتح كل ملف تحت `supabase/migrations/` قبل الموافقة.

---

## 6) النسخ الاحتياطي والاستعادة (خطة تشغيل — لا تنفيذ)

1. قبل أي apply: لقطة/نسخ احتياطي لمشروع **Supabase الجديد** فقط.  
2. تطبيق على **Staging** أولاً.  
3. التحقق من: RPC، RLS، رفض anon، مسارات API.  
4. خطة تراجع: استعادة اللقطة؛ عدم «إصلاح يدوي» على القديم.  
5. الإنتاج فقط بعد قبول Staging وموافقة مالك منفصلة.

---

## 7) خطة تطبيق آمنة (بعد الموافقة فقط)

1. موافقة بندية على الملفات 1–12 (و13 منفصلاً).  
2. Staging + أسرار في مخزن أسرار (ليست في Git).  
3. تطبيق مرتب + تسجيل أرقام الإصدارات.  
4. تشغيل اختبارات عزل API + (اختياري) سكربتات `database/tests` على PG مؤقت.  
5. قبول تشغيلي متعدد المحطات.  
6. قرار دمج `main` / إنتاج — موافقة مستقلة.

---

## 8) بنود موافقة المالك (نعم / لا)

- [ ] تطبيق migrations 1–7 (رصد وقرار) على **الجديد**  
- [ ] تطبيق migrations 8–12 (أعطال/دعم/ops RLS)  
- [ ] تطبيق migration 13 (دفتر أرشفة)  
- [ ] تطبيق حزمة `database/migrations` (هوية/تعيينات)  
- [ ] تفعيل سلسلة `MetraOps` في Staging  

**عدم الرد ≠ موافقة.**

---

## 9) مراجع مرتبطة

- `docs/security/phase-e-database-approval-package.md`
- `docs/security/sql-migration-review-package-v1.md`
- `docs/security/postgres-isolation-test-plan.md`
- `docs/security/station-isolation-test-coverage.md`
- `supabase/migrations/*`
