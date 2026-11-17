# مقترح عقد Access Context — غير منفَّذ

**الحالة:** مقترح للموافقة فقط. لا يوجد endpoint ولا RPC ولا جدول جديد في هذا المستند.

## لماذا مطلوب؟

الفرض الحالي للصلاحيات على الخادم يعمل عبر:

- JWT `sub` → هوية الممثل
- تعيين محطة معتمد + منحة فردية سارية
- RPC مثل `metra_user_has_station_permission` و`metra_user_has_authority_permission`

ذلك كافٍ لرفض العمليات (401/403) لكنه **لا يوفّر** للعميل قائمة موثوقة من:

- الأدوار المعتمدة
- المحطات المعيَّنة
- رموز الصلاحيات السارية

بدون هذا العقد لا يمكن إخفاء وجهات التنقل أو حجب الشاشات مسبقاً دون تخمين.

## ما هو موجود فعلياً (لا يكفي كسياق وصول)

| المصدر | ماذا يعيد | لماذا لا يكفي |
|---|---|---|
| `GET /api/v1/stations` | محطات مرئية بعد فلترة الخادم | لا أدوار ولا permission codes |
| `GET /api/v1/stations/{id}/users` | مستخدمو المحطة (لمن يملك `users.station.view`) | ليس سياق المستخدم الحالي |
| `GET /api/v1/authorities/{id}/permission-options` | خيارات صلاحيات لسلطة واحدة | يتطلب `authorityId` مسبقاً؛ ليس تجميعاً عالمياً |
| `RequireStationPermission` / RPC | قرار boolean داخلي | لا يُعاد للعميل |

## مقترح عقد (يحتاج موافقة صريحة قبل التنفيذ)

```
GET /api/v1/me/access-context
Authorization: Bearer <access_token>
```

استجابة مقترحة (شكل فقط — غير ملزم):

```json
{
  "userId": "uuid",
  "accountState": "active",
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

قواعد إلزامية إن اعتُمد:

1. الممثل من JWT فقط — لا `userId` من الجسم.
2. المحطات/السلطات من تعيينات وعضويات معتمدة وسارية فقط.
3. الصلاحيات من منح فردية معتمدة وغير ملغاة وضمن نافذة الصلاحية.
4. لا bypass لـ `system_admin` على عمليات الرصد.
5. RPC قابل للتنفيذ فقط بـ `service_role` من ASP.NET.

## ما لن يُنفَّذ قبل الموافقة

- لا `GET /api/v1/me/*` جديد
- لا RPC جديد
- لا migration / RLS
- لا إخفاء وجهات Flutter اعتماداً على أدوار ثابتة أو JWT claims غير موثّقة

## سلوك Flutter الحالي (آمن)

- التنقل ثابت
- الخادم يرفض العمليات غير المصرح بها
- `MetraErrorPresenter` يعرض رسائل عربية لـ 401/403
- طبقة `MetraAccessContext` في العميل **مغلقة** (`isResolved = false`) حتى يتوفر العقد
