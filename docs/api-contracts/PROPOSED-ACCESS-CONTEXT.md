# عقد Access Context — منفَّذ

**الحالة:** منفَّذ على API وFlutter باستخدام الآليات الحالية فقط (بدون RPC/schema/RLS جديد).

## Endpoint

```
GET /api/v1/me/access-context
Authorization: Bearer <access_token>
```

الممثل من JWT `sub` فقط.

## مصادر البيانات (موجودة مسبقاً)

| المصدر | الاستخدام |
|---|---|
| PostgREST `station_assignments` | محطات معتمدة سارية + `role_code` |
| PostgREST `authority_memberships` | سلطات معتمدة سارية + `role_code` |
| RPC `metra_user_has_station_permission` | فحص كل رمز صلاحية محطة على حدة |
| RPC `metra_user_has_authority_permission` | فحص صلاحيات السلطة المعروفة |

**لا تُستنتج الصلاحيات من اسم الدور.** الدور يُعرض كمعلومة تعيين فقط.

## شكل الاستجابة

```json
{
  "userId": "uuid",
  "accountState": "unknown",
  "stations": [
    {
      "stationId": "uuid",
      "roleCode": "observer",
      "permissions": ["observation.create", "observation.submit"]
    }
  ],
  "authorities": [
    {
      "authorityId": "uuid",
      "roleCode": "network_director",
      "permissions": ["stations.catalogue.review"]
    }
  ]
}
```

`accountState` يبقى `unknown` حتى يتوفر مسار قراءة حالة الحساب دون migration/RPC جديد.

## رموز الصلاحيات التي تُفحص

محطة: observation.create, observation.edit_own_draft, observation.submit, observation.review, observation.return_for_correction, observation.approve, registrations.station.approve, users.station.view, users.station.manage

سلطة: stations.catalogue.review, registrations.system.approve, authority.access.review, authority.access.revoke

## سلامة قراءة العضويات

- يجب أن تكون كل صفوف العضوية كائنات صالحة وتحمل معرّف UUID غير فارغ.
- أي صف مشوّه يجعل بناء السياق كله يفشل مغلقاً؛ لا يُعاد سياق جزئي.
- تُرفض القوائم التي تتجاوز 100 عضوية لكل نوع قبل فحص الصلاحيات.

## سلوك Flutter

- تحميل السياق بعد الدخول
- فشل التحميل → fail-closed (لا شاشات رصد/إدارة تشغيلية)
- منع فتح الرصد/الإدارة لمحطة بلا صلاحية مؤكدة
- رسائل عربية عبر `MetraPermissionDeniedPage` / `MetraPermissionDeniedMessages`
