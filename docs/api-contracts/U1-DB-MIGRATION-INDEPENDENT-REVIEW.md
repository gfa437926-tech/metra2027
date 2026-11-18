# مراجعة مستقلة — Migration قاعدة البيانات لدعم Rainfall و Soil (U1)

**الحالة:** مراجعة فقط — **لم يُنفَّذ** SQL ولا migration ولا تعديل Supabase.  
**تاريخ المراجعة:** 2026-11-18  
**HEAD عند المراجعة:** `d23adddf86e9d23fb92f75c52ae3db775a5cb417`  
**مصادر:**  
- `supabase/migrations/20261103164003_create_operational_observation_submission.sql`  
- `supabase/migrations/20261103215400_observation_review_decision.sql`  
- `supabase/migrations/20261103220500_harden_observation_decision_null_validation.sql`  
- `docs/api-contracts/U1-DB-CHANGE-REQUIRED.md`

---

## 1. مراجعة الوضع الحالي

### 1.1 قيد CHECK على `observation_type`

```sql
-- من إنشاء الجدول
observation_type text not null
  check (observation_type in ('daily','hourly','phenomenon'))
```

- الاسم المتوقع للقيد في PostgreSQL عند الإنشاء المضمّن:  
  `metra_observations_observation_type_check`  
  (يُفضَّل عند التنفيذ الفعلي: `SELECT conname FROM pg_constraint …` قبل `DROP`).
- **النتيجة:** أي INSERT بـ `rainfall` أو `soil` يفشل على مستوى الجدول حتى لو تغيّرت RPC وحدها.

### 1.2 شروط RPC `metra_submit_observation` (كاملة)

| # | الشرط الحالي | السلوك عند الفشل |
|---|---|---|
| 1 | `p_user_id` و `p_station_id` غير null | `user_id_and_station_id_required` (22023) |
| 2 | `idempotency_key` بعد trim بطول 1–128 | `invalid_idempotency_key` (22023) |
| 3 | `p_observation_type ∈ {daily,hourly,phenomenon}` | `invalid_observation_type` (22023) |
| 4 | `observed_at` غير null؛ `payload` object؛ حجم ≤ 65536 | `invalid_observation_payload` (22023) |
| 5 | `metra_user_has_station_permission(…, 'observation.create')` | `station_observation_create_forbidden` (42501) |
| 6 | إن `p_submit` true: نفس RPC مع `'observation.submit'` | `station_observation_submit_forbidden` (42501) |
| 7 | إدراج مع `ON CONFLICT (station_id, created_by, idempotency_key) DO NOTHING` | عند التعارض: قراءة للقفل والتحقق من تطابق type/observed_at/payload/initial_status |
| 8 | إعادة استخدام مفتاح بقيم مختلفة | `idempotency_key_reused_with_different_request` (23505) |
| 9 | كتابة حدث تدقيق `created_draft` أو `submitted` | append-only عبر trigger منع UPDATE/DELETE |

**الهوية والمحطة:**  
- الهوية تُمرَّر كـ `p_user_id` من طبقة API (مشتقة من JWT `sub` في .NET — خارج هذا الملف).  
- المحطة `p_station_id`؛ الصلاحية **على المحطة** عبر `metra_user_has_station_permission` — لا ثقة بدور من العميل داخل RPC.

**Idempotency:** فريدة لكل `(station_id, created_by, idempotency_key)` مع مقارنة الحمولة عند الإعادة.

**حالات السجل:** `draft` | `submitted` عند الإنشاء حسب `p_submit`؛ لاحقاً `returned` | `approved` عبر قرار المراجعة.

### 1.3 دورة المراجعة `metra_decide_observation`

- لا تفلتر حسب `observation_type`.
- تربط الصف بـ `id` + `station_id`.
- تتطلب الحالة `submitted`.
- صلاحيات: `observation.approve` أو `observation.return_for_correction`.
- **متوافقة بنيوياً** مع أنواع جديدة بعد قبولها في الجدول.

**ملاحظة مخاطر موجودة مسبقاً (ليست من U1):**  
إدراج التدقيق يستخدم `event_type = p_decision` حيث `p_decision ∈ {'approve','return_for_correction'}` بينما CHECK على `metra_observation_audit_events.event_type` يسمح بـ  
`('created_draft','submitted','returned','approved','resubmitted')` فقط.  
إن كان هذا التعارض فعّالاً في البيئة الحية، فهو يؤثر على **كل** الأنواع وليس خاصاً بـ rainfall/soil. **لا يُصلح ضمن U1 دون موافقة منفصلة.**

### 1.4 أثر توسيع الأنواع على hourly / daily / phenomenon

| الجانب | الأثر إن اقتصر التغيير على توسيع القائمة |
|---|---|
| قبول الأنواع الثلاثة | يبقى صريحاً في القائمة الموسّعة |
| الصلاحيات | دون تغيير `metra_role_permissions` |
| RLS / grants | دون تغيير (execute لـ service_role فقط) |
| Flutter Service Role | غير معني — لا يُكشف في العميل |
| عقود API للثلاثة | لا تُكسر إذا لم يُغيَّر الحارس إلا بإضافة نوعين جديدين |

**تعديل CHECK وحده لا يكفي** — يجب توسيع قائمة RPC أيضاً.

---

## 2. SQL المقترح الكامل (للمراجعة — لا تنفيذ)

```sql
-- =============================================================================
-- METRA U1 — extend operational observation_type for rainfall + soil
-- REVIEW ONLY. Do not apply without explicit owner approval.
-- Does NOT: drop tables, weaken RLS, grant to anon/authenticated,
--           add role-permission rows, or modify metra_decide_observation.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- A) Table CHECK: keep existing three types; add rainfall, soil only.
--    Resolve actual constraint name in target DB if different:
--    select conname from pg_constraint
--     where conrelid = 'public.metra_observations'::regclass
--       and contype = 'c' and pg_get_constraintdef(oid) ilike '%observation_type%';
-- ---------------------------------------------------------------------------
alter table public.metra_observations
  drop constraint if exists metra_observations_observation_type_check;

alter table public.metra_observations
  add constraint metra_observations_observation_type_check
  check (
    observation_type in (
      'daily',
      'hourly',
      'phenomenon',
      'rainfall',
      'soil'
    )
  );

-- ---------------------------------------------------------------------------
-- B) RPC: full body preserved; ONLY type allow-list expanded.
--    Signature, grants, security definer, search_path unchanged.
-- ---------------------------------------------------------------------------
create or replace function public.metra_submit_observation(
  p_user_id uuid,
  p_station_id uuid,
  p_idempotency_key text,
  p_observation_type text,
  p_observed_at timestamptz,
  p_payload jsonb,
  p_submit boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_observation public.metra_observations%rowtype;
  v_initial_status text;
begin
  if p_user_id is null or p_station_id is null then
    raise exception 'user_id_and_station_id_required' using errcode = '22023';
  end if;

  if p_idempotency_key is null
     or length(btrim(p_idempotency_key)) not between 1 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;

  -- U1 change: allow rainfall and soil in addition to existing types.
  if p_observation_type not in (
    'daily', 'hourly', 'phenomenon', 'rainfall', 'soil'
  ) then
    raise exception 'invalid_observation_type' using errcode = '22023';
  end if;

  if p_observed_at is null
     or p_payload is null
     or jsonb_typeof(p_payload) <> 'object'
     or pg_column_size(p_payload) > 65536 then
    raise exception 'invalid_observation_payload' using errcode = '22023';
  end if;

  if not public.metra_user_has_station_permission(
    p_user_id, p_station_id, 'observation.create'
  ) then
    raise exception 'station_observation_create_forbidden' using errcode = '42501';
  end if;

  if coalesce(p_submit, false)
     and not public.metra_user_has_station_permission(
       p_user_id, p_station_id, 'observation.submit'
     ) then
    raise exception 'station_observation_submit_forbidden' using errcode = '42501';
  end if;

  v_initial_status :=
    case when coalesce(p_submit, false) then 'submitted' else 'draft' end;

  insert into public.metra_observations (
    station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) values (
    p_station_id, p_user_id, p_observation_type, p_observed_at, p_payload,
    v_initial_status, v_initial_status, p_idempotency_key,
    case when v_initial_status = 'submitted' then now() else null end
  )
  on conflict (station_id, created_by, idempotency_key) do nothing
  returning * into v_observation;

  if v_observation.id is null then
    select * into v_observation
      from public.metra_observations
     where station_id = p_station_id
       and created_by = p_user_id
       and idempotency_key = p_idempotency_key
     for update;

    if v_observation.observation_type <> p_observation_type
       or v_observation.observed_at <> p_observed_at
       or v_observation.payload <> p_payload
       or v_observation.initial_status <> v_initial_status then
      raise exception 'idempotency_key_reused_with_different_request'
        using errcode = '23505';
    end if;

    return jsonb_build_object(
      'id', v_observation.id,
      'status', v_observation.status,
      'replayed', true
    );
  end if;

  insert into public.metra_observation_audit_events (
    observation_id, station_id, actor_user_id,
    event_type, from_status, to_status
  ) values (
    v_observation.id, p_station_id, p_user_id,
    case when v_initial_status = 'submitted' then 'submitted' else 'created_draft' end,
    null, v_initial_status
  );

  return jsonb_build_object(
    'id', v_observation.id,
    'status', v_observation.status,
    'replayed', false
  );
end;
$$;

revoke all on function public.metra_submit_observation(
  uuid, uuid, text, text, timestamptz, jsonb, boolean
) from public, anon, authenticated, metra_api_runtime;

grant execute on function public.metra_submit_observation(
  uuid, uuid, text, text, timestamptz, jsonb, boolean
) to service_role;

commit;
```

### ضمانات التصميم

| متطلب | كيف يُحقَّق |
|---|---|
| عدم حذف بيانات / إعادة إنشاء جداول | `ALTER … CHECK` + `CREATE OR REPLACE FUNCTION` فقط |
| عدم إضعاف الأمان | لا منح لـ anon/authenticated؛ service_role فقط |
| الأنواع الثلاثة باقية | صريحة في القائمة |
| لا صلاحيات إنتاج جديدة | لا مس لجداول الأدوار |
| idempotency + عزل محطة | نفس الشروط 5–8 |
| قابلية التراجع | انظر القسم 5 |

---

## 3. مقارنة RPC — قبل / بعد

| مقطع | قبل | بعد |
|---|---|---|
| التوقيع | `(uuid,uuid,text,text,timestamptz,jsonb,boolean)` | **بدون تغيير** |
| security / search_path | definer, `pg_catalog, public` | **بدون تغيير** |
| null user/station | كما هو | كما هو |
| idempotency_key | 1–128 trim | كما هو |
| **قائمة الأنواع** | `daily, hourly, phenomenon` | `daily, hourly, phenomenon, rainfall, soil` |
| payload size/type | object ≤ 65536 | كما هو |
| observation.create | مطلوب | كما هو |
| observation.submit عند submit=true | مطلوب | كما هو |
| insert + on conflict | كما هو | كما هو |
| مقارنة إعادة التشغيل | type/at/payload/initial_status | كما هو |
| audit insert | created_draft / submitted | كما هو |
| grants | service_role execute only | كما هو |
| metra_decide_observation | غير معدّلة | غير معدّلة |

**الفرق الوظيفي الوحيد المقصود:** قبول السلسلتين `rainfall` و `soil` في فرع التحقق من النوع.

---

## 4. تحليل المخاطر

| الخطر | الشدة | التخفيف |
|---|---|---|
| توسيع CHECK دون RPC (أو العكس) | عالية | تطبيق الاثنين في معاملة واحدة كما أعلاه |
| اسم قيد CHECK مختلف في بيئة حية | متوسطة | الاستعلام عن `conname` قبل الإسقاط |
| قبول صفوف بلا تحقق مجالي خادمي لـ rainfall/soil | متوسطة | طبقة .NET domain validator **بعد** هذه الـ migration وبموافقة API منفصلة إن لزم |
| ظهور rainfall/soil في طابور المراجعة دون تسميات عربية كاملة | منخفضة | تحسين UI لاحق؛ النوع يُعرض كنص |
| تعارض event_type في قرار المراجعة (موجود مسبقاً) | متوسطة–عالية إن مؤكد في الإنتاج | تحقيق منفصل؛ **خارج نطاق U1** |
| تطبيق API يقبل النوعين قبل الـ migration | عالية | ترتيب: DB أولاً ثم API |
| التراجع مع وجود صفوف جديدة | متوسطة | سياسة أرشفة قبل تضييق CHECK (القسم 5) |

---

## 5. خطة التراجع (دون حذف قسري لبيانات rainfall/soil)

**لا** يُعاد القيد القديم إلى الثلاثة أنواع بينما توجد صفوف `rainfall`/`soil` — سيفشل `ADD CONSTRAINT`.

### مسار تراجع آمن

1. **إيقاف** قبول النوعين في API/guard (رفض طلبات جديدة).  
2. **جرد:**  
   `select count(*), observation_type from metra_observations where observation_type in ('rainfall','soil') group by 2;`  
3. **خيار أ — إبقاء البيانات:**  
   - الإبقاء على CHECK الموسّع؛ التراجع يكون «إيقاف المنتج» فقط دون تضييق DB.  
4. **خيار ب — أرشفة ثم تضييق:**  
   - نسخ الصفوف ذات الصلة إلى جدول أرشيفي معتمد (موافقة منفصلة على DDL الأرشيف إن لزم).  
   - أو تحديث/نقل البيانات حسب سياسة المالك.  
   - بعد **صفر** صفوف من النوعين في الجدول الحي:  
     - إعادة CHECK إلى `('daily','hourly','phenomenon')`.  
     - إعادة قائمة RPC إلى الثلاثة أنواع (نفس جسم الدالة مع القائمة القديمة).  
5. **لا** `DROP TABLE` ولا حذف جماعي غير موافق عليه.

---

## 6. خطة الاختبارات (بعد موافقة التنفيذ — ليس الآن)

### قاعدة / RPC (service_role أو بيئة اختبار معزولة)

| # | السيناريو | النتيجة المتوقعة |
|---|---|---|
| T1 | submit `rainfall` بصلاحية create (+ submit إن لزم) | نجاح؛ status draft أو submitted |
| T2 | submit `soil` بنفس الشروط | نجاح |
| T3 | submit `hourly` / `daily` / `phenomenon` | نجاح كما قبل |
| T4 | نوع `climate` أو فارغ | `invalid_observation_type` |
| T5 | بلا user/station صالحين من API | 401/رفض قبل أو مع RPC |
| T6 | مستخدم بلا `observation.create` على المحطة | `station_observation_create_forbidden` |
| T7 | station_id لمحطة أخرى غير مصرّح بها | رفض صلاحية |
| T8 | نفس idempotency_key ونفس الحمولة | `replayed: true` |
| T9 | نفس المفتاح وحمولة مختلفة | `idempotency_key_reused_with_different_request` |
| T10 | صف submitted من rainfall + قرار بمراجع مخوّل | انتقال حالة (مع الانتباه لملاحظة event_type السابقة) |
| T11 | مراجع بلا صلاحية | `station_observation_decision_forbidden` |

### انحدار API/.NET (بعد توسيع الحارس بموافقة لاحقة)

- عدم كسر اختبارات hourly/daily/phenomenon الحالية.  
- رفض أنواع غير مدرجة.

### Flutter

- يبقى السلوك المحلي إلى حين ربط API؛ لا Service Role.

---

## 7. قائمة الموافقات المطلوبة قبل أي تنفيذ

| # | الموافقة | إلزامية؟ |
|---|---|---|
| M1 | تطبيق SQL أعلاه (CHECK + RPC) على البيئة المستهدفة | **نعم** — موافقة صريحة على DB |
| M2 | تأكيد اسم قيد CHECK في البيئة الحية | مُستحسن قبل التشغيل |
| M3 | توسيع `ObservationSubmissionRequestGuard` + domain validator | بعد M1؛ موافقة API إن اعتُبرت منفصلة |
| M4 | ربط Flutter submit لـ rainfall/soil | بعد M1+M3 |
| M5 | إصلاح محتمل لـ event_type في `metra_decide_observation` | **منفصل** عن U1 |
| M6 | حدود رقمية أرصادية لـ rainAmount/depths | غير مطلوبة لهذه الـ migration (D5) |

---

## 8. خلاصة المراجع

1. **CHECK وحده لا يكفي**؛ **RPC وحدها لا تكفي** — الاثنان معاً في معاملة واحدة.  
2. لا صلاحيات أدوار جديدة؛ لا كشف مفاتيح؛ لا تغيير لجداول المستخدمين.  
3. hourly/daily/phenomenon تبقى في القائمة صراحةً.  
4. التراجع الآمن لا يضيّق CHECK بوجود صفوف rainfall/soil.  
5. **التنفيذ متوقف** حتى موافقة المالك الصريحة على M1 (وما يلزم بعدها).

**لا SQL جرى تشغيله ضمن هذه المراجعة.**
