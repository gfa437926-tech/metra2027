# METRA 2027 — Flutter Navigation Map

Branch: work/flutter-complete-from-pr34

## Primary destinations (MetraAdaptiveNavigation)

0. الرئيسية — Home dashboard + shortcuts  
1. المحطات — Station directory + map  
2. التنبؤ — Forecast centre comparison  
3. ساعي — Hourly observation entry  
4. يومي — Daily observation entry  
5. مراجعة — Observation review (station-scoped)  
6. تدقيق — Electronic audit (read-only)  
7. تقارير — Reports hub → archive push route  
8. ذكاء — AI workspace  
9. مناخي — Climatol workspace  
10. مستخدمون — User management (tabs)  
11. إعدادات — Account / station audit link / help  

## Secondary routes

- Observation archive: `Navigator.push` from Reports hub  
- Station audit log: from Settings when a station is selected  

## Station context

Station-scoped screens require a selection from the station directory. Empty states instruct the user to select a station first. Server-side authorization remains authoritative.
