# METRA 2027 — Requirements traceability (Flutter-first wave)

**Updated UTC:** 2026-11-11  
**Canonical Flutter path:** `flutter-app/` (CI + README; `mobile/metra_mobile/` is reference only)  
**Branch tip at write:** see WORK-LOG  
**DB apply:** none in this wave  

Legend: `Done` = API-backed usable · `Partial` · `Scaffold` = honest empty/no fake data · `Missing` · `Blocked` (needs owner/API/contract)

| ID | Unit | Flutter screen | API | Status |
|---|---|---|---|---|
| FLT-004 | Login / session | `MetraAuthGate` | Supabase JWT | Partial |
| FLT-004b | Registration request | `registration_screen.dart` | registration APIs | Partial |
| FLT-004c | Password recovery | `password_recovery_screen.dart` | Supabase reset | Partial |
| FLT-004d | Profile | `account_profile_screen.dart` | local session + notes | Partial |
| FLT-005 | Registration review / assignment | admin screens | Yes | Partial |
| FLT-006 | Station directory + detail | stations/* | `/api/v1/stations` | Partial/Done baseline |
| FLT-007 | Hourly entry | `observation_submit_screen.dart` | submit/validate | Done baseline |
| FLT-008 | Daily entry | `daily_observation_submit_screen.dart` | submit | Done baseline |
| FLT-009 | Phenomena | `phenomenon_capture_screen.dart` | validate + submit | Partial |
| FLT-010 | Rainfall | specialist shell | No aggregate API | Scaffold |
| FLT-011 | Climate | specialist shell | No aggregate API | Scaffold |
| FLT-012 | Agriculture | specialist shell | No | Scaffold |
| FLT-013 | Soil temperature | specialist shell | No | Scaffold |
| FLT-014 | Forecasting | `forecasting_center_screen.dart` | stations + compare | Partial |
| FLT-015 | Electronic / intelligent audit | `electronic_auditor_screen.dart` | None yet | Scaffold |
| FLT-016 | AI workspace | specialist shell | No AI gateway | Scaffold |
| FLT-017 | Climatol | specialist shell | No worker | Scaffold |
| FLT-018 | Reports hub | reports/* | status + archive partial | Partial |
| OP | Faults / support | maintenance + support | Yes | Partial |
| — | Review/return/resubmit | observation_review + returned editor | Yes | Done baseline |

**Explicit non-claims:** Climate/rainfall/agriculture/soil shells must not show fabricated totals. Climatol/AI must not run without server-side gateway and owner approval.
