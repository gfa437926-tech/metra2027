# المرحلة E — حزمة اعتماد قاعدة البيانات الجديدة

**الفرع:** `work/legacy-ui-migration-audit`  
**الحالة:** مراجعة فقط — **لم يُطبَّق أي شيء على Supabase المستضاف في هذه المرحلة.**  
**محظور:** قاعدة METRA القديمة · استيراد محطات قديمة · تطبيق دون موافقة صريحة من المالك.

---

## 1. الهدف

تجهيز قرار اعتماد واحد يمكن للمالك الموافقة عليه أو رفضه بنداً بنداً قبل أي `psql` / Supabase migration apply.

---

## 2. مجموعات الـ migrations في المستودع

### 2.1 `supabase/migrations` (ترتيب زمني مقترح للتطبيق على المشروع الجديد فقط)

| # | الملف | الغرض | ملاحظات أمنية |
|---|---|---|---|
| 1 | `20261103164003_create_operational_observation_submission.sql` | جداول النشرات + التدقيق | revoke لـ anon/authenticated |
| 2 | `20261103164045_deny_client_access_to_operational_observations.sql` | منع وصول العميل | دفاع إضافي |
| 3 | `20261103164638_index_operational_observation_foreign_keys.sql` | فهارس | أداء |
| 4 | `20261103215400_observation_review_decision.sql` | RPC قرار المراجعة | service_role |
| 5 | `20261103220500_harden_observation_decision_null_validation.sql` | تحقق NULL | |
| 6 | `20261107020000_harden_observation_decision_sod_and_audit.sql` | فصل الواجبات + تدقيق | |
| 7 | `20261107021500_observation_resubmit_after_return.sql` | إعادة التقديم | |
| 8 | `20261107030000_equipment_faults_station_scoped.sql` | أعطال المعدات | نطاق محطة |
| 9 | `20261107031000_support_incidents_station_scoped.sql` | حوادث الدعم | نطاق محطة |
| 10 | `20261107032000_harden_ops_rls_and_assignee_checks.sql` | RLS + المُسند إليه | |
| 11 | `20261108010000_metra_ops_runtime_role_and_fault_read.sql` | أدوار ops | NOLOGIN |
| 12 | `20261108020000_npgsql_ops_session_context_rls.sql` | RLS سياق الجلسة | Npgsql |
| 13 | `20261110180000_manual_archive_ledger_review_only.sql` | دفتر أرشفة Excel | **معلّق بالكامل — يحتاج موافقة منفصلة** |

### 2.2 `database/migrations` (صلاحيات / تسجيل / تعيين / سلطات)

سكربتات دورة المستخدمين والصلاحيات وRPCs. تُراجع وتُطبَّق على **نفس المشروع الجديد فقط** بعد موافقة مستقلة، وليست على القاعدة القديمة.

### 2.3 اختبارات disposable

- `database/tests/*_pg_test.sql` وخطوات CI على PostgreSQL مؤقتة = إثبات منطق وليست نشراً.

---

## 3. ما هو مفعّل في الكود دون إثبات تطبيق على المستضاف

| القدرة | الخادم / الواجهة | اعتماد DB |
|---|---|---|
| نشرات + قرار + إعادة تقديم | نعم | migrations 1–7 في المستودع |
| أعطال / دعم | نعم | migrations 8–12 |
| دفتر أرشفة Excel | API ذاكرة مؤقتة + UI | migration 13 **غير مطبّق** |
| مجاميع مناخية/سنوية | غير مربوطة | لا مخطط معتمد |

**نجاح CI لا يعني** أن migrations طُبّقت على مشروع Supabase المستضاف.

---

## 4. مقترح اعتماد دفتر الأرشفة اليدوية (بند موافقة)

**الجدول المقترح:** `public.metra_manual_archive_confirmations`

| العمود | النوع | قيد |
|---|---|---|
| id | uuid PK | gen_random_uuid() |
| station_id | uuid | FK → station_catalogue(id) |
| actor_user_id | uuid | من JWT فقط عبر API |
| report_kind | text | hourly\|daily\|monthly\|rainfall\|climate\|other |
| period_start_utc / period_end_utc | date | end ≥ start |
| excel_file_name | text | ≤ 260 |
| note | text nullable | ≤ 2000 |
| confirmed_at_utc | timestamptz | default now() UTC |

**فريد:** (station_id, lower(report_kind), period_start_utc, period_end_utc, lower(excel_file_name))

**صلاحيات DB:** revoke من anon/authenticated؛ الكتابة عبر مسار خادمي فقط بعد `archive.confirm`.

**ليس ضمن النطاق:** تخزين ملفات Excel · ترحيل أرصاد · الاتصال بقاعدة أرشيف خارجية.

---

## 5. صلاحيات يجب منحها في كتالوج الصلاحيات (بعد الموافقة)

| permission_code | الاستخدام |
|---|---|
| `archive.read` | قراءة دفتر التأكيد والملخص الشهري الإداري |
| `archive.confirm` | تسجيل تأكيد أرشفة يدوية |

بدون هذه المنح يبقى المسار **فشل مغلق** (403) — وهذا مطلوب.

---

## 6. قائمة تحقق قبل أي تطبيق

1. [ ] تأكيد أن الهدف هو مشروع Supabase **الجديد** فقط (`tbdnklyxjvbrilvnwgmq` أو بديله المعتمد).
2. [ ] نسخة احتياطية / نقطة استعادة للمشروع الجديد إن وُجدت بيانات.
3. [ ] مراجعة نص كل ملف في الجدول 2.1 بالترتيب.
4. [ ] قرار صريح: تطبيق 1–12؟ نعم/لا.
5. [ ] قرار صريح: تفعيل دفتر الأرشفة الدائم (13 بعد إلغاء التعليق)؟ نعم/لا.
6. [ ] قرار صريح: منح `archive.*` للأدوار؟ أي أدوار؟
7. [ ] عدم تضمين أي اتصال أو بيانات من القاعدة القديمة.
8. [ ] بعد التطبيق (إن وافقت): تشغيل اختبارات العزل على بيئة staging وليس الإنتاج أولاً إن أمكن.

---

## 7. نموذج قرار المالك (يُملأ بالموافقة)

```
أوافق على تطبيق migrations supabase 1–12 على المشروع الجديد فقط:   [ ] نعم  [ ] لا
أوافق على تفعيل جدول دفتر الأرشفة اليدوية (البند 4):              [ ] نعم  [ ] لا
أوافق على منح archive.read / archive.confirm للأدوار: _______________
أمنع منعاً باتاً أي مساس بالقاعدة القديمة:                         [x] مؤكد
التاريخ / التوقيع: _______________________________________________
```

---

## 8. مخرجات المرحلة E (هذا المستند)

- جرد مرتب للـ migrations.
- فصل ما هو «في المستودع» عما هو «مطبّق مستضافاً» (غير مثبت هنا).
- مقترح دفتر الأرشفة للموافقة.
- بوابات موافقة صريحة قبل أي تنفيذ.

**لا يُنفَّذ تطبيق SQL ضمن المرحلة E دون الرسالة النصية الصريحة من المالك.**
