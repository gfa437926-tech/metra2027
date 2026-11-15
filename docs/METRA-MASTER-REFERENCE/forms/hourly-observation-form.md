# نموذج النشرة الساعية — Hourly Observation Form

**المصدر:** pages/hourly/hourly_send/hourly_reports.html + enhanced-validation.js + cloud-total-cover-validation.js
**النظير:** features/observations/hourly_observation_entry_screen.dart
**الحالة:** P

## الحقول الرئيسية
currentDate, currentTime, utcTime(select, إلزامي), dryTemp, wetTemp, stationPressure, seaLevelPressure, pressureSlope, pressureShape, relativeHumidity, vaporPressure, dewPoint, vaporPressureDiff, windDirection, windSpeed, avgWindDirection, avgWindSpeed, visibility, currentWeather, pastWeather, precipitationAmount, totalCloudCover(select), cloud1-4 Amount/Type/Height, cover12, cover123, observerNotes, responsibilityAgreement.

## تحقق موثق
- الحرارة الجافة ≥ الرطبة
- نطاقات مُشار إليها في enhanced-validation (لا تُعمم على نماذج أخرى دون دليل)
- تحقق تغطية السحب الكلية
