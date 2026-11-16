# فهرس الحقول الكامل — 174

الإصدار: FINAL-2026-11-15 · مصدر: HTMLParser على metra-old + حدود JS

| form | count |
|---|---|
| hourly | 36 |
| daily | 32 |
| agricultural | 31 |
| fault-telecom | 21 |
| hourly-climate | 15 |
| fault-equipment | 15 |
| fault-it | 10 |
| rainfall | 7 |
| soil | 7 |
| **Total** | **174** |

## معرفات FLD (عينة هيكلية — الكتالوج الصفّي الكامل في FIELDS-174-COMPLETE-PART1/2 و CSV)

نمط المعرف: `FLD-{FORM}-{NNN}` مثال: FLD-HOURLY-001 … FLD-HOURLY-036، FLD-DAILY-001…، FLD-AGRICULTURAL-…، FLD-FAULT_TELECOM-…، FLD-FAULT_EQUIPMENT-…، FLD-FAULT_IT-…، FLD-HOURLY_CLIMATE-…، FLD-RAINFALL-…، FLD-SOIL-…

### حدود مثبتة من JS (ساعي)
dryTemp/wetTemp/dewPoint -20..50 · stationPressure 850..1050 · seaLevelPressure 0..1050 · relativeHumidity 1..100 · windDirection 0..36 · windSpeed 0..99 · visibility 0..200 · vaporPressure 0..99 · pastWeather 0..9 · currentWeather 0..99 · utcTime 0..23 · dry>=wet

### يومي (مقارنات daily_validation)
temp -20..50 · precip 0..999.9 · snow 0..999 · evaporation 0..99.9 · sunshine 0..24 · sunshine% 0..100 · direction 0..36 · time 0..23.9 · humidity 0..100

### زراعي
رسالة حرارة -20..60 (تعارض U-02)

الملفات: `fields-174.csv` · `FIELDS-174-COMPLETE-PART1.md` · `PART2.md` · `*-full-records.md`
