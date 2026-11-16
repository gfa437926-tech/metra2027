# 04 — الأدوار والصلاحيات

## أدوار
ROLE-OBSERVER · ROLE-STATION-HEAD · ROLE-AUDITOR · ROLE-NETWORK-DIR · ROLE-TELECOM · ROLE-WORKSHOP · ROLE-IT · ROLE-SYSADMIN · ROLE-CLIMATE · ROLE-AI · ROLE-FORECAST

## عزل المحطات (إلزامي)
1. العادي: محطته فقط
2. stationId دون صلاحية → 403
3. إخفاء Flutter ليس أمناً
4. الفرض في .NET + RPC

## مصفوفة (مستهدفة)
| العملية | Observer | Head | Auditor | Network | SysAdmin |
|---|---|---|---|---|---|
| عرض محطته | Y | Y | إن مُنح | إن مُنح | Y |
| عرض أخرى | N | N | إن مُنح | إن مُنح | Y |
| إرسال رصد | Y | Y | إن مُنح | N افتراضي | Y |
| اعتماد/رفض | N | إن مُنح | إن مُنح | إن مُنح | Y |
| إدارة مستخدمين | N | N | N | محدود | Y |
| أرشيف | gate+grant | نفس | نفس | نفس | نفس |

مثبت جزئياً: حراس Metra.Api.Tests. غير مثبت: كل خلية runtime.
