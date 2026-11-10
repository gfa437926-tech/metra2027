# المرحلة G — تغطية اختبارات الأمن وعزل المحطات

**القاعدة:** نجاح الاختبار يثبت السلوك المغطى فقط. لا يعني اكتمال مراجعة اختراق أو تطبيق SQL على المستضاف.

## 1. اختبارات API (.NET) الموجودة / المضافة

| المجال | ملف الاختبار | ماذا يثبت |
|---|---|---|
| طابور النشرات | `ObservationQueueStationAuthorizationTests` | 403 دون صلاحية؛ عدم استدعاء الخدمة؛ نطاق المحطة |
| أعطال المعدات | `EquipmentFaultStationAuthorizationTests` | قائمة/تفاصيل/انتقال عبر المحطات؛ فصل update≠resolve |
| حوادث الدعم | `SupportIncidentStationAuthorizationTests` | عزل المحطة لمسارات الدعم |
| ترويسة أمن + مصادقة | `ApiSecurityHeadersAndAuthorizationTests` | رفض غير المصادق |
| أرشفة Excel | `ManualArchiveStationAuthorizationTests` (**جديد**) | list/confirm/summary عبر المحطات؛ 401؛ عدم استدعاء الدفتر عند الرفض |
| سياسات مجال | `ObservationAuthorizationPolicyTests` وغيرها | قواعد القرار/SoD حيث وُجدت |

## 2. PostgreSQL disposable (في المستودع / CI حيث مفعّل)

| سكربت | الغرض |
|---|---|
| `ops_station_isolation_pg_test.sql` | عزل ops |
| `ops_assignee_authorization_pg_test.sql` | المُسند إليه |
| `observation_decision_*` | قرار النشرة / SoD على قاعدة مؤقتة |

## 3. ما لم يُثبت في المرحلة G

- اختبار اختراق خارجي كامل.
- إثبات أن migrations مطبّقة على Supabase المستضاف.
- إخفاء قائمة Angular حسب كل permission code (ما زال UX على الجلسة فقط).
- منح `archive.*` في بيانات الإنتاج (يحتاج موافقة مرحلة E).

## 4. معيار قبول المرحلة G (هذا المستودع)

1. اختبارات عزل المحطة للمسارات الحرجة تمر في CI.
2. مسارات الأرشفة الجديدة مغطاة برفض عبر المحطات.
3. لا أسرار في العملاء.
4. لا تطبيق SQL ضمن هذه المرحلة.
