# الأعطال والصيانة والاتصالات

## نماذج Old
| النوع | Form | HTML | حقول | FR | شاشة 2027 |
|---|---|---|---|---|---|
| أجهزة | fault-equipment | fix.html | 15 | FR-FAULT-EQ | SCR-INSTRUMENTS جزئي |
| اتصالات | fault-telecom | fix-tel.html | 21 | FR-FAULT-TEL | لا (U-04) |
| IT | fault-it | it.html | 10 | FR-FAULT-IT | لا (U-04) |

JSON: `fields/fields-fault-equipment.json` · `fields-fault-telecom.json` · `fields-fault-it.json`

## دورة البلاغ
Opened → Assigned → InProgress → Resolved → Closed (OnHold اختياري)

## عمليات وAPI مطلوبة (مقترحة — غير موجودة في مسح Features)
| عملية | أدوار | API ID |
|---|---|---|
| إنشاء | Observer/Telecom/IT/Workshop | API-FAULT-CREATE |
| تعيين | Lead | API-FAULT-ASSIGN |
| تحديث حالة | المُسند | API-FAULT-UPDATE |
| إغلاق | Lead/Head | API-FAULT-CLOSE |
| قائمة | حسب الصلاحية | API-FAULT-LIST |

## مثبت vs مقترح
- حقول HTML: **موثق مستخرج**
- SCR-INSTRUMENTS: **UI جزئي في الكود**
- API-FAULT-*: **مواصفة مطلوبة غير منفذة**

لا SLA مخترعة.
