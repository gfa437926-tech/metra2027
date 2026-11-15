# Hourly Observation Form

Source HTML: metra-old/pages/hourly/hourly_send/hourly_reports.html
Validation: enhanced-validation.js, cloud-total-cover-validation.js
HTML fields extracted: 36

## Proven bounds (enhanced-validation.js)
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

Rule: dryTemp >= wetTemp.
Cloud cover checks approx 0..8 in cloud-total-cover-validation.js.
Other HTML fields: pressureShape, avgWindDirection, precipitationAmount, totalCloudCover, cloud layers 1-4, cover12, cover123, observerNotes, responsibilityAgreement.
