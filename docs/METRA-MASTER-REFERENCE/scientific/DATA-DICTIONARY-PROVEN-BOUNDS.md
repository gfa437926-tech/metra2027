# قاموس الحدود المستخرجة من شيفرة التحقق (مثبتة المصدر)

## نشرة ساعية — enhanced-validation.js
| Field ID | min | max | type |
|---|---|---|---|
| dryTemp | -20 | 50 | float |
| wetTemp | -20 | 50 | float |
| dewPoint | -20 | 50 | float |
| stationPressure | 850 | 1050 | float |
| seaLevelPressure | 0 | 1050 | float |
| relativeHumidity | 1 | 100 | int |
| windDirection | 0 | 36 | int |
| windSpeed | 0 | 99 | int |
| avgWindSpeed | 0 | 99 | int |
| visibility | 0 | 200 | int |
| vaporPressure | 0 | 99 | float |
| pressureSlope | 0 | 99 | float |
| pastWeather | 0 | 9 | int |
| currentWeather | 0 | 99 | int |
| utcTime | 0 | 23 | int |

قاعدة: dryTemp >= wetTemp (رسالة في نفس الملف).
سحب: cloud-total-cover-validation.js يتعامل مع نطاق ~0..8.

## نشرة يومية — مقارنات في daily_validation.js
حرارة -20.0..50.0؛ هطول 0..999.9؛ ثلج 0..999؛ تبخر 0..99.9؛ سطوع مدة 0..24.0؛ نسبة 0..100؛ اتجاه 0..36؛ وقت 0..23.9؛ رطوبة 0..100.

## زراعي — agricultural_validation_fix.js
رسالة صريحة: حرارة خارج النطاق (-20 إلى 60). سحب 0..8؛ هطول حتى 999.9.

## WMO
غير مستخرج كجدول رسمي من المستودع → يحتاج اعتماداً.
