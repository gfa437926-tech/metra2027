# REQ-002 — Inventory of root RAR archive

**Date UTC:** 2026-11-11  
**Archive:** `10-5-2026 برنامج ادارة البيانات الجوية مع الربط على.rar`  
**Tool:** `unrar lb` / partial extract (RAR 5)  
**Status:** `COMPLETED` for listing; content used as **read-only reference** only  

## Summary

| Metric | Value |
|---|---|
| Files listed | 171 |
| HTML pages (unique basenames) | 28 |
| Page module folders under `pages/` | arg, daily, form, h_climate, hourly, rain, soil, weather_phenomena |

## Page modules (legacy UI reference)

| Module | Role (from path names) |
|---|---|
| `hourly` / `hourly_reports.html` | Hourly observation entry/reports |
| `daily` / `daily.html` / `daily_reports.html` | Daily observation |
| `rain` / `rainfall_reports.html` | Rainfall |
| `h_climate` / `climate_hourly_reports.html` | Climate hourly |
| `soil` / `soil_temperature.html` / `soil-send.html` | Soil temperature |
| `arg` / `agricultural_reports.html` | Agricultural reports |
| `weather_phenomena` / `phenomena.html` | Phenomena |
| `form` | Forms / IT / submit handlers |
| `weather_analytics.html` | Analytics |
| `manager-dashboard.html`, `telecom-manager.html`, `workshop-manager.html`, `it-maneger.html` | Role dashboards |
| `index.html`, `main.html`, `sidebar.html`, `login` assets | Shell / auth |

## Constraints

- Archive is **legacy reference**. Do not copy secrets from any embedded config.
- Do not treat RAR JS as production Backend.
- Modern implementation remains `flutter-app/`, `angular-app/`, `backend/Metra.Api/`.

## Extraction note

Full recursive extract reported one directory-create conflict under `pages/rain/.../js/js`; listing via `unrar lb` succeeded for inventory purposes.
