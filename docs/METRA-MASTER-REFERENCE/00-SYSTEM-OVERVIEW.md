# 00 — نظرة عامة على النظام

**الوثيقة:** METRA 2027 — MASTER REFERENCE  
**الإصدار:** FINAL-DRAFT-2026-11-15

منصة أرصاد (Flutter + .NET API) لاستبدال واجهات `metra-old` مع الحفاظ على الحقول والتحقق، وإضافة CLIMATOL وAI/سجلات وصلاحيات خادم.

| المكوّن | المسار | الحالة المثبتة |
|---|---|---|
| Flutter | mobile/metra_mobile/ | UI؛ إرسال رصد gated؛ أرشيف 503 |
| .NET | backend/Metra.Api/ | endpoints + حراس اختبار |
| Legacy | metra-old (خارجي) | مرجع فقط — لا يُعدَّل |

مبادئ: عزل محطات على الخادم؛ لا حدود علمية مخترعة؛ أرشيف fail-closed؛ AI بلا كتابة رسمية دون بشر.
