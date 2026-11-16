# Form Spec — النشرة الساعية / Hourly Observation

| Item | Value |
|---|---|
| Form ID | hourly-observation |
| HTML | pages/hourly/hourly_send/hourly_reports.html |
| Validation | enhanced-validation.js + cloud-total-cover-validation.js |
| Fields | 36 — see fields/hourly-observation-fields.md |
| Flutter | SCR-HOURLY gated submit |

Proven bounds (enhanced-validation.js): dryTemp/wetTemp/dewPoint -20..50; stationPressure 850..1050; seaLevelPressure 0..1050; relativeHumidity 1..100; windDirection 0..36; windSpeed 0..99; visibility 0..200; vaporPressure 0..99; pastWeather 0..9; currentWeather 0..99; utcTime 0..23.
Rule: dryTemp >= wetTemp.
