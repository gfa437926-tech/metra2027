# Fields — النشرة اليومية / Daily Observation

Source: pages/daily/daily_send/daily.html + daily_validation.js | Count 32

| Field ID | type | req | min | max | unit | bound_source |
|---|---|---|---|---|---|---|
| currentDate | date | Y | — | — | — | HTML |
| reportType 24h/06UTC/18UTC | radio | N | — | — | — | HTML |
| minTemp | text | Y | -20 | 50 | °C | daily_validation comparisons |
| maxTemp | text | Y | -20 | 50 | °C | daily_validation |
| precipitation | text | Y | 0 | 999.9 | mm | daily_validation |
| snowThickness | text | Y | 0 | 999 | cm | daily_validation |
| precipitationTrace | text | N | — | — | — | — |
| thunderstorm,hail,snow,rain,frost,fog,mist,dustStorm,blowingDust,haze,stormyWind | checkbox | N | — | — | — | HTML |
| evaporation | text | Y | 0 | 99.9 | mm | daily_validation |
| sunshineDuration | text | Y | 0 | 24 | hour | daily_validation |
| sunshinePercentage | text | Y | 0 | 100 | % | daily_validation |
| maxGustSpeed | text | Y | — | — | m/s | needs confirm |
| maxGustDirection | text | Y | 0 | 36 | code | daily_validation |
| maxGustTime | text | Y | 0 | 23.9 | hour | daily_validation |
| maxHumidity + Time | text | Y | 0 | 100 | % | daily_validation |
| minHumidity + Time | text | Y | 0 | 100 | % | daily_validation |
| observerNotes | textarea | N | — | — | — | — |
| responsibilityAgreement | checkbox | Y | — | — | — | HTML |
