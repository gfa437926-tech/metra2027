# SCR-HOURLY — رصد ساعي / Hourly Observation

| الخاصية | القيمة |
|---|---|
| Screen ID | SCR-HOURLY |
| Dart | features/observations/hourly_observation_entry_screen.dart |
| الهدف | إدخال نشرة ساعية |
| الأدوار | ROLE-OBSERVER |
| API | API-OBS-SUBMIT · API-OBS-VALIDATE-HOURLY |
| FR | FR-OBS-HOURLY |
| الحقول | FLD-HOURLY-001 … FLD-HOURLY-036 (36) — انظر fields-hourly.json / CSV |
| الحالة | **UI + gated submit** |

## حالات الاستخدام
- UC-HO-01 ملء إلزامي وإرسال عند فتح البوابة
- UC-HO-02 رفض wetTemp > dryTemp
- UC-HO-03 gate مغلق → لا إرسال ناجح
- UC-HO-04 403 لمحطة غير مصرّح بها

## حالات UI
تحميل · فراغ (بدون محطة) · أخطاء تحقق · 401/403 · نجاح
