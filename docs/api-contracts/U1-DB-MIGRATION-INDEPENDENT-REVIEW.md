# مراجعة مستقلة نهائية — بوابة موافقة DB لـ U1 (Rainfall / Soil)

**الحالة:** مراجعة وثائقية فقط — **لم يُنفَّذ SQL ولا migration ولا تعديل Supabase.**  
**HEAD المرجعي عند الإعداد:** يُحدَّث مع commit هذه الوثيقة.  
**مصادر:**  
`supabase/migrations/20261103164003_create_operational_observation_submission.sql`  
`supabase/migrations/20261103215400_observation_review_decision.sql`  
`supabase/migrations/20261103220500_harden_observation_decision_null_validation.sql`

---

## ملخص تنفيذي — ما يحتاج موافقتك

| القرار | الموضوع | هل يُنفَّذ الآن؟ |
|---|---|---|
| **M1** | توسيع CHECK على `observation_type` + قائمة أنواع داخل `metra_submit_observation` ليشملا `rainfall` و`soil` | **لا** — بانتظار موافقتك الصريحة |
| **M2** | إصلاح تعارض `event_type` في تدقيق قرارات المراجعة (`approve`/`return_for_correction` مقابل CHECK) | **لا** — قرار مستقل؛ يؤثر على الأنواع الحالية أيضاً |
| **M3** | توسيع .NET Guard + Domain Validator | بعد M1 (موافقة منفصلة) |
| **M4** | ربط Flutter بالحفظ الخادمي | بعد M1+M3 (موافقة منفصلة) |

**الموافقة على بند واحد لا تعني الموافقة على البقية.**

---

## 1. اسم قيد CHECK — لا افتراض أعمى

في سكربت الإنشاء القيد **مضمّن** بدون `CONSTRAINT name`:

```sql
observation_type text not null check (observation_type in ('daily','hourly','phenomenon'))
```

PostgreSQL يولّد اسماً تلقائياً؛ الشائع: `metra_observations_observation_type_check`.

**قبل أي تنفيذ حي يجب تشغيل:**

```sql
select c.conname,
       pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'metra_observations'
  and c.contype = 'c'
  and pg_get_constraintdef(c.oid) ilike '%observation_type%';
```

ثم استخدام `conname` الفعلي في `ALTER TABLE … DROP CONSTRAINT`.

لنفس أسلوب التحقق من قيد `event_type` (لتحليل M2):

```sql
select c.conname, pg_get_constraintdef(c.oid)
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'metra_observation_audit_events'
  and c.contype = 'c'
  and pg_get_constraintdef(c.oid) ilike '%event_type%';
```

---

## 2. CHECK من الهجرة المنشئة

```sql
-- metra_observations
observation_type text not null
  check (observation_type in ('daily','hourly','phenomenon'))

-- metra_observation_audit_events
event_type text not null
  check (event_type in (
    'created_draft','submitted','returned','approved','resubmitted'
  ))
```

---

## 3. تعريف RPC الحالي كاملاً — `metra_submit_observation`

```sql
create or replace function public.metra_submit_observation(
  p_user_id uuid, p_station_id uuid, p_idempotency_key text,
  p_observation_type text, p_observed_at timestamptz, p_payload jsonb,
  p_submit boolean default false
)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public as $$
declare
  v_observation public.metra_observations%rowtype;
  v_initial_status text;
begin
  if p_user_id is null or p_station_id is null then
    raise exception 'user_id_and_station_id_required' using errcode = '22023';
  end if;
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) not between 1 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;
  if p_observation_type not in ('daily','hourly','phenomenon') then
    raise exception 'invalid_observation_type' using errcode = '22023';
  end if;
  if p_observed_at is null or p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or pg_column_size(p_payload) > 65536 then
    raise exception 'invalid_observation_payload' using errcode = '22023';
  end if;
  if not public.metra_user_has_station_permission(p_user_id, p_station_id, 'observation.create') then
    raise exception 'station_observation_create_forbidden' using errcode = '42501';
  end if;
  if coalesce(p_submit, false) and
     not public.metra_user_has_station_permission(p_user_id, p_station_id, 'observation.submit') then
    raise exception 'station_observation_submit_forbidden' using errcode = '42501';
  end if;
  v_initial_status := case when coalesce(p_submit, false) then 'submitted' else 'draft' end;

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
    select * into v_observation from public.metra_observations
     where station_id = p_station_id and created_by = p_user_id
       and idempotency_key = p_idempotency_key for update;
    if v_observation.observation_type <> p_observation_type
       or v_observation.observed_at <> p_observed_at
       or v_observation.payload <> p_payload
       or v_observation.initial_status <> v_initial_status then
      raise exception 'idempotency_key_reused_with_different_request' using errcode = '23505';
    end if;
    return jsonb_build_object('id', v_observation.id, 'status', v_observation.status, 'replayed', true);
  end if;

  insert into public.metra_observation_audit_events (
    observation_id, station_id, actor_user_id, event_type, from_status, to_status
  ) values (
    v_observation.id, p_station_id, p_user_id,
    case when v_initial_status = 'submitted' then 'submitted' else 'created_draft' end,
    null, v_initial_status
  );
  return jsonb_build_object('id', v_observation.id, 'status', v_observation.status, 'replayed', false);
end;
$$;

revoke all on function public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  from public, anon, authenticated, metra_api_runtime;
grant execute on function public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  to service_role;
```

---

## 4. SQL Migration المقترحة كاملة (M1 فقط)

```sql
-- METRA U1 / M1 — DO NOT APPLY without explicit owner approval on M1.
begin;

-- Replace conname with live name from section 1 if different.
alter table public.metra_observations
  drop constraint if exists metra_observations_observation_type_check;

alter table public.metra_observations
  add constraint metra_observations_observation_type_check
  check (
    observation_type in (
      'daily', 'hourly', 'phenomenon', 'rainfall', 'soil'
    )
  );

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

  -- *** ONLY FUNCTIONAL DIFF vs current RPC ***
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
    select * into v_observation from public.metra_observations
     where station_id = p_station_id and created_by = p_user_id
       and idempotency_key = p_idempotency_key for update;
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

**لا حذف بيانات؛ لا منح لـ anon/authenticated؛ RLS دون إلغاء؛ create/submit/idempotency كما هي.**

---

## 5. فروقات RPC الحالي vs المقترح

| الموضع | الحالي | المقترح |
|---|---|---|
| قائمة الأنواع | `daily, hourly, phenomenon` | `+ rainfall, soil` |
| باقي الجسم والمنح | كما هو | كما هو |

---

## 6. قرار M2 — تعارض تدقيق المراجعة

| عنصر | القيمة |
|---|---|
| CHECK `event_type` | `created_draft`, `submitted`, `returned`, `approved`, `resubmitted` |
| ما تكتبه decide RPC في `event_type` | `p_decision` = `approve` أو `return_for_correction` |
| التوافق | **غير متوافق** مع CHECK |

**الأثر المتوقع من نصوص المستودع:** فشل إدراج التدقيق يرفع استثناء ويلغي عملية القرار (بما فيها تحديث الحالة) داخل استدعاء الدالة — فيؤثر على **hourly/daily/phenomenon** وعلى rainfall/soil بعد M1.

**أقل إصلاح (لا تنفيذ):** عند INSERT التدقيق استخدم `approved` / `returned` بدل `approve` / `return_for_correction`.

M2 مستقل عن M1.

---

## 7. التراجع عن M1

- **لا** تضييق CHECK مع وجود صفوف rainfall/soil.  
- إيقاف API فقط مع إبقاء القائمة الموسّعة = تراجع تشغيلي بلا فقد بيانات.  
- أرشفة موافق عليها ثم تضييق = تراجع هيكلي كامل.

---

## 8. اختبارات بعد التنفيذ الموافق

حفظ rainfall/soil؛ انحدار hourly/daily/phenomenon؛ رفض نوع/مستخدم/محطة؛ idempotency؛ اعتماد/إرجاع + تدقيق صحيح (بعد M2 إن لزم).

---

## 9. حدود

لا SQL منفَّذ. لا Supabase. لا push. لا E2E. بانتظار M1 و/أو M2 صراحةً.
