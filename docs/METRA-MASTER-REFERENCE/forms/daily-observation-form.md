# نموذج النشرة اليومية — Daily Observation Form

**المصدر القديم:** pages/daily/daily_send/daily.html + daily_validation.js + daily_main.js
**النظير الجديد:** mobile/metra_mobile/lib/features/observations/daily_observation_entry_screen.dart
**حالة التتبع:** P

## الحقول المستخرجة من HTML

| معرف الحقل | الاسم العربي | النوع | إلزامي | ملاحظات |
|---|---|---|---|---|
| currentDate | التاريخ | date | نعم | |
| reportType (24h/06UTC/18UTC) | نوع التقرير | radio | لا | 24h / 06utc / 18utc |
| minTemp | القيمة الصغرى في النهايات (سْ) | text | نعم | placeholder -05.3 |
| maxTemp | القيمة العظمى في النهايات (سْ) | text | نعم | 25.7 |
| precipitation | كمية الهطول لأقرب مم | text | نعم | 012.5 |
| snowThickness | أكبر سماكة ثلج لأقرب سم | text | نعم | 015 |
| precipitationTrace | الأثر (T) | text | لا | |
| thunderstorm, hail, snow, rain, frost, fog, mist, dustStorm, blowingDust, haze, stormyWind | ظواهر جوية | checkbox | لا | weatherPhenomena |
| evaporation | مجموع التبخر اليومي لأقرب عشر مم | text | نعم | |
| sunshineDuration | مجموع مدة سطوع الشمس الحقيقي | text | نعم | |
| sunshinePercentage | النسبة المئوية لسطوع الشمس | text | نعم | |
| maxGustSpeed | أكبر نفحة للرياح (م/ثا) | text | نعم | |
| maxGustDirection | اتجاه أكبر نفحة (درجة) | text | نعم | |
| maxGustTime | وقت أكبر نفحة (ساعة) | text | نعم | |
| maxHumidity / maxHumidityTime | أكبر رطوبة (%) وزمنها | text | نعم | |
| minHumidity / minHumidityTime | أصغر رطوبة (%) وزمنها | text | نعم | |
| observerNotes | ملاحظات الراصد | textarea | لا | |
| responsibilityAgreement | إقرار المسؤولية | checkbox | نعم | |

## قواعد التحقق (daily_validation.js)
دوال: validateTemperature, validatePrecipitation, validateSnowThickness, validateEvaporation, validateSunshineDuration/Percentage, validateWindSpeed/Direction, validateTime, validateHumidity, validateTemperatureRelation.
رسائل: «هذا الحقل مطلوب»، «تنسيق درجة الحرارة غير صالح»، «درجة الحرارة خارج النطاق».
الحدود الرقمية الدقيقة: غير مستخرجة كأرقام ثابتة من النص المفحوص → يحتاج اعتماداً علمياً (انظر 15-UNRESOLVED).
