# Legacy UI → METRA 2027 modern gap inventory

Status is based on repository routes and code on `work/legacy-ui-migration-audit`.
This is **not** a claim of visual/functional parity with production legacy usage.

| Legacy surface (repo root) | Modern target | API-backed? | Gap |
|---|---|---|---|
| `index.html` + `login.js` | `/login` | Supabase Auth | Session model differs; localStorage `currentUser` still used on dashboard |
| `main.html` observer home | `/` dashboard | Partial | Some legacy actions remain informational |
| `hourly_reports.html` | `/reports/hourly` + Flutter intake | Partial | Field parity with legacy form not proven |
| `daily_reports.html` / `daily.html` | `/reports/daily` | Partial | Full legacy validation matrix not proven |
| `rainfall_reports.html` | `/reports/rainfall` | Partial | Same |
| `climate_hourly_reports.html` / `h_climate_send.html` | `/reports/climate` | Partial | Same |
| `phenomena.html` / `weather_phenomena.html` | `/phenomena`, `/phenomena/input` | Partial | Dashboard now routes to input |
| `soil_temperature.html` / `soil-send.html` | `/soil-temperature` | Partial | |
| `agricultural_reports.html` | `/agriculture` | Partial | |
| Review/approve flows (`rec-main.html` etc.) | `/observations/workflow` | **Yes** for core decide/return/resubmit | Legacy screen layout parity open |
| `it.html` / `it-maneger.html` | `/support-incidents` | **Yes** core lifecycle | Not full legacy IT manager console |
| `telecom-manager.html` | `/support-incidents` | **Yes** shared support domain | Telecom-specific legacy UX not ported 1:1 |
| `workshop-manager.html` / fix screens | `/equipment-faults` | **Yes** core lifecycle | Workshop-specific legacy UX open |
| `manager-dashboard.html` / `manag-net.html` | `/users` (+ role cards on dashboard) | **Partial** (registration review, authority access, station users in review panel) | Ban/full admin parity not proven |
| `weather_analytics.html` | no dedicated route | No | Analytics still a gap |
| Station catalogue admin | API station directory/review endpoints | Backend yes | Dedicated Angular admin screen still thin |

## Highest remaining UI gaps
1. Analytics / advanced admin dashboards (`weather_analytics`, full manager net)
2. Proven field-level parity for hourly/daily/climate forms
3. Station catalogue administration UX beyond directory APIs
4. Explicit stationId query plumbing from dashboard into station-scoped screens
