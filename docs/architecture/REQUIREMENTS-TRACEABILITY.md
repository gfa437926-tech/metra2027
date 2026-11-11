# METRA 2027 — Requirements traceability (Flutter-first wave)

**Updated UTC:** 2026-11-11  
**Canonical Flutter path:** `flutter-app/` (CI + README; `mobile/metra_mobile/` is reference only)  
**Branch tip at write:** see WORK-LOG  
**DB apply:** none in this wave  

Legend: `Done` = API-backed usable · `Partial` · `Scaffold` = honest empty/no fake data · `Missing` · `Blocked` (needs owner/API/contract)

| ID | Unit | Flutter screen | API | Status |
|---|---|---|---|---|
| FLT-004 | Login / account gate | `MetraAuthGate` + `account_state_gate.dart` | Supabase JWT + `GET /api/v1/account/registration-status` | Partial — active-only home gate and fail-closed pending/blocked/error states; access-context and revoked-session tests remain |
| FLT-004b | Registration request | `registration_screen.dart` | registration APIs | Partial — server station/role catalogue, status and duplicate-pending guard; broader rejection/reapply policy tests remain |
| FLT-004c | Password recovery | `password_recovery_screen.dart` + `password_update_screen.dart` | Supabase Auth recovery event | Partial — app deep-link and new-password form implemented; Supabase allow-list/device round-trip pending |
| FLT-004d | Account profile | `account_profile_screen.dart` | `GET /api/v1/account/registration-status` | Partial — account/request state, review note, UTC timestamp; effective grants/assignments not exposed |
| FLT-004e | Authority memberships / permissions | `authority_access_screen.dart` | authority access lifecycle APIs | Partial — self request, queues, approve/reject/revoke and audit; target-user and effective-access context remain |
| FLT-004f | Registration audit | `registration_audit_screen.dart` | station/system registration audit | Partial — immutable registration audit read; observation review event history remains separate |
| FLT-004g | Station assignment / audit | `station_assignment_screen.dart` + `station_audit_log_screen.dart` | station user/assignment/audit APIs | Partial — validity window, detail and audit; searchable eligible-user directory remains |
| FLT-006 | Station directory + detail | `stations/*` | `/api/v1/stations` | Partial/Done baseline — coordinate source/accuracy now included in canonical detail |
| FLT-007 | Hourly entry | `observation_submit_screen.dart` | submit/validate | Done baseline — exact UTC/hour conditional field matrix and fixtures |
| FLT-008 | Daily entry | `daily_observation_submit_screen.dart` | submit | Done baseline — report-specific fields and fixtures |
| FLT-009 | Phenomena | `phenomenon_capture_screen.dart` | validate + submit | Partial — capture/validation; history/report parity remains |
| FLT-010 | Rainfall | specialist shell | No aggregate API | Scaffold / Blocked |
| FLT-011 | Climate | specialist shell | No aggregate API | Scaffold / Blocked |
| FLT-012 | Agriculture | specialist shell | No approved field/API contract | Scaffold / Blocked |
| FLT-013 | Soil temperature | specialist shell | No approved depth/unit/sensor API contract | Scaffold / Blocked |
| FLT-014 | Forecasting | `forecasting_center_screen.dart` | stations + server compare/profile | Partial — map/search and 2–12 station server comparison; live snapshots/bulletins unavailable |
| FLT-015 | Electronic audit | `electronic_auditor_screen.dart` | No case/evidence API | Scaffold / Blocked |
| FLT-016 | AI workspace | specialist shell | No AI gateway | Scaffold / Blocked |
| FLT-017 | Climatol | specialist shell | No isolated worker/API | Scaffold / Blocked |
| FLT-018 | Reports hub | reports/* | status + archive partial | Partial — hourly/daily history and exports need read models |
| OP | Faults / support | maintenance + support | Yes | Partial — verify complete lifecycle, evidence and authorization |
| — | Review/return/resubmit | observation_review + returned editor | Yes | Done baseline — additional concurrency/authorization tests remain |

**Explicit non-claims:** Climate/rainfall/agriculture/soil shells must not show fabricated totals. Climatol/AI must not run without server-side gateway and owner approval.
