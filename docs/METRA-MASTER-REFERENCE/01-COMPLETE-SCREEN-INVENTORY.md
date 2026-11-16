# 01 — قائمة الواجهات الكاملة (Screen Inventory)

**تاريخ الجرد:** 2026-11-15
**مصدر قديم:** gfa437926-tech/metra-old
**مصدر جديد:** gfa437926-tech/metra2027

## أ. واجهات METRA Old (HTML/JS)

### أ.1 الدخول والتنقل
- O-01 تسجيل الدخول — index.html + js/login.js
- O-02 الإطار الرئيسي — main.html + js/main.js
- O-03 الشريط الجانبي — sidebar.html + js/sidebar.js

### أ.2 إدخال الرصدات
| # | الواجهة | المسار | حقول تقريبية |
|---|---|---|---|
| O-10 | النشرة الساعية | pages/hourly/hourly_send/hourly_reports.html | 36 |
| O-11 | النشرة اليومية | pages/daily/daily_send/daily.html | 32 |
| O-12 | المناخية الساعية | pages/h_climate/h_climate_send/h_climate_send.html | 15 |
| O-13 | الزراعية | pages/arg/send-argicultural/agricultural_reports.html | 31 |
| O-14 | المطرية | pages/rain/rain_send/rainfall_reports.html | 7 |
| O-15 | حرارة التربة | pages/soil/soil_send/soil-send.html | 7 |

### أ.3 الأعطال
- O-20 fix.html (15) — أجهزة/مقاييس
- O-21 fix-tel.html (45) — اتصالات
- O-22 it.html (10) — IT

### أ.4 لوحات المديرين
- manager-dashboard.html, manag-net.html, telecom-manager.html, workshop-manager.html, it-maneger.html

### أ.5 view-data التقارير
- hourly/daily/climate/agricultural/rainfall/soil/phenomena/weather_analytics

**إجمالي شاشات HTML ~27 | حقول نماذج مستخرجة 311**

## ب. واجهات METRA 2027 Flutter (14 وجهة)
N-01 الرئيسية … N-14 الأجهزة — انظر فرع work/flutter-full-interface-completion-2026-11-15

ملفات: home, stations, forecast_centres, observations (hourly/daily/review), audit, reports, ai, climatol, admin, records, instruments

## ج. جديد في 2027 بلا مقابل قديم كامل
CLIMATOL، AI workspace، records digitization، instrument inventory الكامل، archive fail-closed، R4 station permissions
