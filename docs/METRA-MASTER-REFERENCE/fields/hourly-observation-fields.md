# Fields — النشرة الساعية / Hourly Observation

Source: metra-old/pages/hourly/hourly_send/hourly_reports.html + enhanced-validation.js
Count: 36

| Field ID | name_ar (from label) | type | req | min | max | unit | bound_source |
|---|---|---|---|---|---|---|---|
| currentDate | التاريخ (ميلادي) | text | N | — | — | — | غير محدد |
| currentTime | الوقت الحالي | text | N | — | — | hour | غير محدد |
| utcTime | التوقيت العالمي UTC | select | Y | 0 | 23 | hour | JS proven |
| dryTemp | درجة الحرارة الجافة | text | Y | -20 | 50 | °C | JS proven |
| wetTemp | درجة الحرارة الرطبة | text | Y | -20 | 50 | °C | JS proven; dry>=wet |
| stationPressure | ضغط المحطة | text | Y | 850 | 1050 | mbar | JS proven |
| seaLevelPressure | ضغط سطح البحر | text | Y | 0 | 1050 | mbar | JS proven |
| pressureSlope | ميل الضغط | text | N | 0 | 99 | — | JS proven |
| pressureShape | شكل الضغط | text | N | — | — | — | غير محدد |
| relativeHumidity | الرطوبة النسبية | text | Y | 1 | 100 | % | JS proven |
| vaporPressure | ضغط بخار الماء | text | N | 0 | 99 | mbar | JS proven |
| dewPoint | درجة الندى | text | Y | -20 | 50 | °C | JS proven |
| vaporPressureDiff | فرق ضغط بخار الماء | text | N | — | — | — | غير محدد |
| windDirection | اتجاه الرياح السطحية | text | Y | 0 | 36 | code/degrees | JS proven |
| windSpeed | سرعة الرياح السطحية | text | Y | 0 | 99 | m/s | JS proven |
| avgWindDirection | متوسط الاتجاه | text | N | — | — | — | غير محدد |
| avgWindSpeed | متوسط السرعة | text | N | 0 | 99 | m/s | JS proven |
| visibility | الرؤية الأفقية | text | Y | 0 | 200 | hundreds of m | JS proven |
| currentWeather | الطقس الحاضر | text | N | 0 | 99 | code | JS proven |
| pastWeather | الطقس الغابر | text | N | 0 | 9 | code | JS proven |
| precipitationAmount | كمية الهطول | text | N | — | — | mm | غير محدد |
| totalCloudCover | التغطية الكلية للسحب | select | Y | ~0 | ~8 | oktas? | cloud validation |
| cloud1-4 Amount/Type/Height | طبقات السحب | text | N | — | — | — | غير محدد |
| cover12 | مجموع 1+2 | text | Y | — | — | — | غير محدد |
| cover123 | مجموع 1+2+3 | text | Y | — | — | — | غير محدد |
| observerNotes | ملاحظات | textarea | N | — | — | — | — |
| responsibilityAgreement | إقرار | checkbox | Y | — | — | — | HTML required |

Scientific status: JS bounds are code-proven; formal scientific adoption still required before production.
