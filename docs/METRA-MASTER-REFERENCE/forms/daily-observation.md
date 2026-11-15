# Daily Observation Form

Source: metra-old/pages/daily/daily_send/daily.html + daily_validation.js
HTML fields: 32

## Bounds from comparisons in daily_validation.js
| Element | min | max |
|---|---|---|
| temperature | -20.0 | 50.0 |
| precipitation | 0.0 | 999.9 |
| snow thickness | 0 | 999 |
| evaporation | 0.0 | 99.9 |
| sunshine duration | 0.0 | 24.0 |
| sunshine % | 0 | 100 |
| direction | 0 | 36 |
| gust time | 0.0 | 23.9 |
| humidity | 0 | 100 |

Key fields: currentDate, reportType(24h/06UTC/18UTC), minTemp, maxTemp, precipitation, snowThickness, precipitationTrace, weather phenomena checkboxes, evaporation, sunshineDuration, sunshinePercentage, maxGustSpeed/Direction/Time, max/min Humidity+Time, observerNotes, responsibilityAgreement.
