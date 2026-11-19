# U1 — ضرورة تعديل قاعدة البيانات لدعم Rainfall و Soil

**الحالة:** تقرير توقف — **لم يُنفَّذ** أي SQL / migration.  
**الفرع:** `feat/phenomenon-observation-submit-2026-11-16`  
**مصدر الحقيقة:** `supabase/migrations/20261103164003_create_operational_observation_submission.sql`

---

## 1. الخلاصة

**لا يمكن** دعم حفظ `rainfall` أو `soil` على المسار الحالي دون تعديل DB.

| الموقع | القيد الحالي |
|---|---|
| جدول `public.metra_observations` | `check (observation_type in ('daily','hourly','phenomenon'))` |
| الدالة `public.metra_submit_observation` | `if p_observation_type not in ('daily','hourly','phenomenon') then raise … invalid_observation_type` |
| صلاحية الإنشاء داخل RPC | `metra_user_has_station_permission(…, 'observation.create')` — **كافٍ**؛ لا يتطلب رمزاً جديداً |
| دورة المراجعة | نفس جدول الحالات `draft/submitted/returned/approved` + `metra_decide_observation` — **متوافقة بنيوياً** مع صفوف من نوع جديد **بعد** توسيع قيد النوع |

لذلك: توسيع API وحدها دون هذا التعديل يمرّر طلباً يصل إلى RPC فيُرفض، أو يُرفض مبكراً من الحارس — **بلا حفظ**.

---

## 2. سبب الحاجة

1. قيد CHECK على العمود يمنع INSERT لأي نوع خارج الثلاثة.  
2. RPC تكرر نفس القائمة قبل الإدراج.  
3. لا يوجد جدول/مسار بديل معتمد لـ rainfall/soil في المستودع.

---

## 3. الملفات / الجداول / القيود المتأثرة

| كائن | التأثير |
|---|---|
| `public.metra_observations.observation_type` CHECK | يجب تضمين `rainfall`, `soil` |
| `public.metra_submit_observation` | نفس توسيع القائمة |
| فهارس / RLS / grants | **لا تغيير هيكلي مطلوب** للدعم الأدنى (الجدول والـ RLS موجودان؛ الكتابة عبر service_role + RPC) |
| `metra_observation_audit_events` | بلا تغيير قائمة الأنواع (لا تخزّن observation_type في event_type) |
| نماذج hourly/daily/phenomenon | يجب أن تبقى مقبولة دون انقطاع |

---

## 4. SQL المقترح (للمراجعة فقط — لا تنفيذ)

```sql
-- U1 proposal only. DO NOT APPLY without explicit owner approval.
-- Extends operational observation types for rainfall and soil.
-- Does not alter permissions catalogue or review decision RPC signatures.

begin;

-- 1) Drop and recreate observation_type check on metra_observations
alter table public.metra_observations
  drop constraint if exists metra_observations_observation_type_check;

alter table public.metra_observations
  add constraint metra_observations_observation_type_check
  check (observation_type in (
    'daily', 'hourly', 'phenomenon', 'rainfall', 'soil'
  ));

-- 2) Replace metra_submit_observation body constraint on type.
--    Full function body must be re-applied from the approved migration source
--    with ONLY this change in the type allow-list:
--      if p_observation_type not in (
--        'daily','hourly','phenomenon','rainfall','soil'
--      ) then
--        raise exception 'invalid_observation_type' using errcode = '22023';
--      end if;
--
--    Permission check remains:
--      metra_user_has_station_permission(p_user_id, p_station_id, 'observation.create')
--
--    Status machine and idempotency unique (station_id, created_by, idempotency_key)
--    remain unchanged.

commit;
```

> عند التنفيذ الفعلي: إعادة نشر **كامل** تعريف `metra_submit_observation` من نسخة المستودع بعد تعديل سطر القائمة فقط، لتجنب فقدان منطق التعارض/إعادة الإرسال.

---

## 5. أثر التغيير على النماذج الموجودة

| النموذج | الأثر المتوقع |
|---|---|
| hourly / daily / phenomenon | تبقى ضمن القائمة؛ لا تغيير مسار أو صلاحية |
| طابور المراجعة | قد تظهر صفوف `rainfall`/`soil` لنفس المحطة إن أُرسلت — واجهة المراجعة تعرض `observationType` كنص |
| صلاحيات الأدوار | لا صفوف جديدة في `metra_role_permissions` |

---

## 6. خطة التراجع

```sql
-- Only if no rainfall/soil rows exist (or after deleting/archiving them).
-- 1) Delete or migrate rows where observation_type in ('rainfall','soil')
-- 2) Restore CHECK to ('daily','hourly','phenomenon')
-- 3) Restore RPC allow-list to the three types
```

التراجع **متعذر بأمان** إذا وُجدت صفوف rainfall/soil دون أرشفتها أولاً.

---

## 7. قرار كمية المطر (فجوة كتالوج — ليست جزءاً من SQL)

الكتالوج الحالي: `rainAmount` **اختياري** decimal.

| إدخال العميل | التفسير المعتمد محلياً |
|---|---|
| قيمة غير مرسلة / سلسلة فارغة | **غير متوفر** — ليس صفراً |
| `0` أو `0.0` | **قياس مسجّل صفر** |
| رقم > 0 | **قياس موجب** |

لا حقل «حالة القياس» في الكتالوج. أي إلزام بوجود كمية أو حقل availability يحتاج **اعتماد مالك بيانات** — خارج SQL أعلاه.

---

## 8. ما ينتظر الموافقة المستقلة

- [ ] تطبيق migration لتوسيع CHECK + RPC كما فوق  
- [ ] بعد ذلك فقط: توسيع `ObservationSubmissionRequestGuard` و`ObservationSubmissionDomainValidator`  
- [ ] ثم ربط Flutter بـ `submitObservation`

**الموافقة المبدئية على نطاق U1 ≠ موافقة على تنفيذ هذا SQL.**
