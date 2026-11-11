# METRA 2027 — Requirements traceability (Flutter-first wave)

**Updated UTC:** 2026-11-11T17:48:59.359Z  
**Canonical Flutter path:** `flutter-app/` (CI + README; `mobile/metra_mobile/` is reference only)  
**Branch tip at write:** `51ed88afa415072e9e41679f585610e5615b9b5d`  
**DB apply:** none in this wave  

Legend: `Done` = API-backed usable · `Partial` · `Scaffold` = honest empty/no fake data · `Missing` · `Blocked` (needs owner/API/contract)

| ID | Unit | Flutter screen | API | Status |
|---|---|---|---|---|
| FLT-004 | Login / account gate | `MetraAuthGate` + `account_state_gate.dart` | Supabase JWT + `GET /api/v1/account/registration-status` | Partial — active-only home gate and fail-closed pending/blocked/error states; access-context and revoked-session tests remain |
| FLT-004b | Registration request | `registration_screen.dart` | registration APIs | Partial — server station/role catalogue, status and duplicate-pending guard; broader rejection/reapply policy tests remain |
| FLT-004c | Password recovery | `password_recovery_screen.dart` + `password_update_screen.dart` | Supabase Auth recovery event | Partial — app deep-link and new-password form implemented; Supabase allow-list/device round-trip pending |
| FLT-004d | Account profile | `account_profile_screen.dart` | `GET /api/v1/account/registration-status` | Partial — account/request state, review note, UTC timestamp; effective grants/assignments not exposed |
| FLT-004e | Authority memberships / permissions | `authority_access_screen.dart` | authority access lifecycle APIs | Partial — self request, queues, approve/reject/revoke and audit; membership request dialog lifecycle covered by CI; target-user and effective-access context remain |
| FLT-004f | Registration audit | `registration_audit_screen.dart` | station/system registration audit | Partial — immutable registration audit read; observation review event history remains separate |
| FLT-004g | Station assignment / audit | `station_assignment_screen.dart` + `station_audit_log_screen.dart` | station user/assignment/audit APIs | Partial — validity window, detail and audit; searchable eligible-user directory remains |
| FLT-006 | Station directory + detail | `stations/*` | `/api/v1/stations` | Partial/Done baseline — coordinate source/accuracy now included in canonical detail |
| FLT-007 | Hourly entry | `observation_submit_screen.dart` | submit/validate | Done baseline — exact UTC/hour conditional field matrix and fixtures |
| FLT-008 | Daily entry | `daily_observation_submit_screen.dart` | submit | Done baseline — report-specific fields and fixtures |
| FLT-009 | Phenomena | `phenomenon_capture_screen.dart` | validate + submit | Partial — capture/validation; history/report parity remains |
| FLT-010 | Rainfall | `SpecialistUnitShellScreen` rainfall configuration/local preview | No approved aggregate API | Partial UI / Blocked operationally |
| FLT-011 | Climate | `SpecialistUnitShellScreen` query filters/local preview | No approved climate report API | Partial UI / Blocked operationally |
| FLT-012 | Agriculture | `SpecialistUnitShellScreen` station-scoped form/local preview | No approved field/API contract | Partial UI / Blocked operationally |
| FLT-013 | Soil temperature | `SpecialistUnitShellScreen` station-scoped form/local preview | No approved depth/unit/sensor API contract | Partial UI / Blocked operationally |
| FLT-014 | Forecasting | `forecasting_center_screen.dart` | stations + server compare/profile | Partial — map/search and 2–12 station server comparison; live snapshots/bulletins unavailable |
| FLT-015 | Electronic audit | `electronic_auditor_screen.dart` — 8 tabs incl. paper, mechanical, comparison, review, library, training, reports | No case/evidence/OCR API | Partial UI / Blocked operationally |
| FLT-016 | AI workspace | `ai_workspace_screen.dart` — analysis, anomalies, reports, governance | No AI gateway | Partial UI / Blocked operationally |
| FLT-017 | Climatol | `climatol_workspace_screen.dart` — station/variable/period setup, pipeline, diagnostics, versions | No isolated worker/API | Partial UI / Blocked operationally |
| FLT-018 | Reports hub | reports/* + manual_archive_screen.dart | status queues, returned queue, archive confirmations/monthly summary, station audit | Partial — history reads up to 100 per currently authorized queue with type/status/text/UTC filters and detail; full approved/rejected/version history, missing-data register, aggregate monthly/annual/climate/rainfall/agriculture/soil reports and PDF/Excel exports require new approved API read models |\n| FLT-019 | AFTN console | `aftn_console_shell_screen.dart` — inbox, outbox, local composer, channel/audit | No AFTN gateway/message API | Partial UI / Blocked operationally |
| OP | Faults / support | maintenance + support | Yes | Partial — verify complete lifecycle, evidence and authorization |
| — | Review/return/resubmit | observation_review + returned editor | Yes | Done baseline — additional concurrency/authorization tests remain |

**Explicit non-claims:** Climate/rainfall/agriculture/soil shells must not show fabricated totals. Climatol/AI must not run without server-side gateway and owner approval.


## Verified frontend implementation snapshot — 2026-11-11T17:48:59.359Z

- Flutter CI `43071280050`: analyzer passed; 85 tests passed.
- Angular CI in the same run: npm tests, production build and Chromium PWA/IndexedDB smoke checks passed.
- AI, Climatol, electronic-audit, AFTN and specialist screens have navigable, RTL workspaces and honest unavailable states; they are **not** operationally complete until their named backend contracts exist.
- No database changes or deployment were performed.


## Reports/history implementation trace — 2026-11-11T18:32:18.872Z

- Flutter report/history screens now use the existing station-scoped review, returned, manual-archive and station-audit APIs only.
- History access is partial by permission: a 403 on one queue does not hide the other permitted queue; 403 on both fails closed.
- Archive confirmation is evidence that an external/manual Excel archive occurred. It does not upload files or transfer observation data. The API's default service path is process-local in-memory unless MetraOps is configured; durable use must be verified separately.
- Aggregate report and full historical read models remain blocked. No schema or database changes were made.
