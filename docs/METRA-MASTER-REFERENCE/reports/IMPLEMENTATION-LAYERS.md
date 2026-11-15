# تقرير طبقات التنفيذ

**لا PASS لاختبارات غير مشغّلة.**

| المكوّن | موثق | في الكود | منفذ تشغيلياً | واجهة فقط | مستقبلي |
|---|---|---|---|---|---|
| حقول 174 | نعم CSV/JSON | HTML قديم | — | — | حدود علمية نهائية |
| SCR-HOURLY/DAILY | نعم | Dart | submit gated | — | U-08 |
| API-OBS-SUBMIT/DECISION | نعم | C# | حراس؛ يعتمد البوابة | — | — |
| QUEUE/STATIONS/AUDIT | نعم | نعم | مسارات عميل | — | — |
| ARCHIVE | نعم | مسار عميل | **503** | — | U-09 |
| agri/rain/soil/h_climate | حقول | HTML | لا Flutter | — | U-03 |
| telecom/IT faults | حقول | HTML | لا API | أدوات جزئية | U-04 |
| CLIMATOL/AI | مواصفة | UI Dart | لا محرك | نعم | U-15/16 |
| FeatureGate | نعم | نعم | مغلق علمياً | — | U-08 |

## اختبارات هذه المهمة
| | في المستودع | شُغّل هنا |
|---|---|---|
| Metra.Api.Tests | نعم | **لا** |
| Flutter test | نعم | **لا** |
| استخراج 174 + AUTO-VERIFY تتبع | نعم | **نعم — نجح** |
