# METRA 2027 — Flutter Completion Audit

**Audit date:** 2026-11-11 UTC  
**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `work/legacy-ui-migration-audit`  
**Audited source tip:** `22cd2e6b0edc95af2bfaf7e88acd83a20606cfef`  
**Requirements source:** `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`  
**Status:** Inventory established; implementation closure in progress.

## 1. Canonical Flutter source — resolved from repository evidence

The canonical, independently runnable Flutter client is **`flutter-app/`**.

Evidence:
- `flutter-app/README.md` identifies itself as the standalone Android/iOS client and documents pub get, analyze, test and build commands.
- `mobile/metra_mobile/README.md` explicitly states that the official Flutter source was moved to `flutter-app/` and that `mobile/metra_mobile` is retained temporarily as a reference.
- `.github/workflows/client-ci.yml` currently runs Flutter analyze and tests from `flutter-app/`.
- `flutter-app/` contains Android and iOS runner configuration, app source, package configuration and tests.

The master requirements and some earlier planning documents still refer to `mobile/metra_mobile/`. Those references are stale and must be reconciled in documentation. Do not merge or copy the two source trees blindly. Keep `mobile/metra_mobile/` read-only/reference until a separate history/diff review proves whether any unique behavior remains.

## 2. Current canonical source inventory

### Application source

- `lib/main.dart` — app startup, RTL theme and configuration gate.
- `lib/core/auth/metra_auth.dart` — Supabase authentication/session storage.
- `lib/core/api/metra_api_client.dart` — authenticated API client.
- `lib/features/home/metra_home.dart` — current app shell and bottom navigation.
- `lib/features/stations/station_directory_screen.dart` — station directory, map/list and filters.
- `lib/features/observations/observation_submit_screen.dart` — hourly entry.
- `lib/features/observations/daily_observation_submit_screen.dart` — daily entry.
- `lib/features/observations/observation_review_screen.dart` — review queue/decisions.
- `lib/features/observations/returned_observation_editor.dart` — returned record correction.
- `lib/features/observations/*_contract.dart` and labels — client field contracts.
- `lib/features/admin/manual_archive_screen.dart` — manual Excel archive confirmation.
- `lib/features/admin/registration_review_screen.dart` — registration request review.
- `lib/features/admin/station_assignment_screen.dart` — station assignment requests/decisions.
- `lib/features/forecasting/forecasting_center_screen.dart` — current catalogue/geographic comparison shell.
- `lib/features/maintenance/equipment_fault_screen.dart` — API-backed equipment fault workflow.
- `lib/features/maintenance/maintenance_report_screen.dart` — local secure-storage draft workflow; not equivalent to a server-backed maintenance workflow.
- `lib/features/support/support_incident_screen.dart` — API-backed support incident workflow.
- `lib/features/ops/station_ops_hub_screen.dart` and `station_ops_summary_screen.dart` — station operations hub/summary.
- `lib/features/reports/station_reports_hub_screen.dart` and `observation_status_screen.dart` — currently available report/status hub.

### Existing tests

The canonical Flutter test directory currently contains tests for:
- startup/configuration and station directory widget behavior;
- hourly submission and UTC conversion;
- daily submission and daily field contract;
- API client;
- observation review;
- returned observation editing;
- station operations hub;
- shared observation contract fixtures.

This is a useful baseline, not full acceptance coverage for every required page, role, route, error state or device size. No new test pass is claimed by this documentation audit.

## 3. Flutter completion matrix against the master requirements

| Requirement area | Current evidence in Flutter | Audit status | Remaining work |
|---|---|---|---|
| Sign-in/session | Supabase auth gate, secure session storage, API token provider | Partial | Full account-state, expired/revoked session, recovery and negative tests |
| Registration request | No dedicated Flutter page found | Missing | Build pending-registration request UI after identity contract |
| Registration review | Admin screen exists and calls API | Partial | Permission-state, error, confirmation, system/station-stage tests |
| Password recovery | Dedicated recovery screen calls Supabase Auth resetPasswordForEmail with privacy-safe confirmation | Implemented; tests added; CI pending | Confirm redirect/deep-link settings before release |
| Profile/account | Dedicated authenticated account profile shows email, identity provider and server-authoritative permission explanation; sign-out requires confirmation | Implemented baseline; tests added; CI pending | Account metadata, assignment display and session lifecycle states |
| Shared home/navigation | Six bottom destinations; one home action opens forecasting | Partial | Role-aware links, route coverage, responsive navigation, forecasting always discoverable |
| Station directory | API-backed map/list, type filters, coordinate validation | Partial | Search/pagination/detail route, missing-coordinate handling and station selection lifecycle |
| Station detail | Dedicated catalogue detail screen opens from map markers and directory cards; shows code, type, operational/approval status, coordinates, elevation and WMO ID | Implemented baseline; tests added; CI pending | Add API-backed full detail/history when an approved endpoint exists |
| Station assignment | Admin screen exists and calls API | Partial | Role-grant visibility, lifecycle, revoked/expired assignments and tests |
| Hourly entry | Screen + contract + tests | Implemented baseline | Full source-field parity, accessibility and integration coverage |
| Hourly list/details | No dedicated history/detail screens found | Missing/Partial | API-backed list, filters, detail and history |
| Daily entry | Screen + contract + tests | Implemented baseline | Confirm field catalogue and full acceptance coverage |
| Daily list/details | No dedicated history/detail screens found | Missing/Partial | API-backed list, filters, detail and history |
| Review/return/resubmit | Queue, decisions and returned editor exist | Partial/Implemented baseline | Full workflow state matrix, race/error/stale session tests |
| Weather phenomena | No dedicated Flutter page found | Missing | Implement only against approved phenomenon contract/API |
| Auditor workspace | Archive confirmation exists; no complete auditor workspace | Partial | Missing-data register, review history and monthly audit workflow |
| Manual Excel archive | Screen + API client methods | Partial | Durable persistence remains owner-gated; monthly reconciliation and tests |
| Equipment faults | API-backed screen | Partial | Status lifecycle, permissions, validation and tests |
| Maintenance reports | Local secure-storage drafts only | Scaffold/local-only | Do not represent as submitted/central workflow; bind only after approved API |
| Support incidents | API-backed screen | Partial | Lifecycle, authorized queue and full tests |
| Operations summary | API-backed summary screen | Partial | Confirm metric definitions, freshness and empty/error behavior |
| Reports hub/status | Hub + observation status screen | Partial | Hourly/daily report lists, detail/export and monthly archive reconciliation |
| Monthly/annual/climate/rainfall | No complete Flutter specialist pages found | Missing | Contracts and APIs required before real totals |
| Agriculture/soil temperature | No complete Flutter specialist pages found | Missing | Approved fields/contracts/APIs required |
| Forecasting center | Catalogue-based geographic selection/comparison shell | Partial | Live observation snapshot API, station detail, weather elements, freshness, time series and comparisons by elevation/region |
| Electronic Auditor | No Flutter UI | Missing by current design | Read-only case list/detail only if owner confirms Flutter scope; full chart calibration is desktop/web-first |
| Offline mode | No complete equivalent to Angular offline queue established | Partial/Unverified | Offline architecture, encrypted drafts, sync/conflict rules and tests after approval |
| UI quality | RTL enforced; Material 3 theme | Partial | Original visual parity, responsive layouts, accessibility, localization and device testing |
| Release/security | secure storage and HTTPS config documented | Partial | obfuscation/release pipeline, signing process, dependency audit and device acceptance |

## 4. Confirmed structural issues to fix before declaring completion

1. `MetraHome` initially exposed Forecasting only from a Home card. In commit `5f881e4`, it was added as a dedicated shared bottom-navigation destination; role-specific visibility and live snapshot functionality remain to be completed.
2. The app shell uses a single selected station ID for several workflows. It needs a robust station-context selector/state that respects server-authorized assignments and does not treat catalogue selection as permission.
3. The hourly and daily entry forms exist, but separate report-list/detail/history screens are not evidenced in the canonical Flutter source inventory.
4. The maintenance report screen stores drafts locally using secure storage, while equipment faults have a separate API-backed screen. These must be clearly separated; local drafts must not be presented as submitted central records.
5. Several pages required by the master catalogue have no Flutter implementation yet: registration request, recovery, profile, station detail, phenomena, specialist reports, agriculture, soil, complete auditor workspace and electronic auditor capture.
6. Forecasting currently loads station directory records and calculates geographic comparison. The master plan states the live weather snapshot endpoint is not yet production-ready. Do not display catalogue metadata as live meteorological readings.
7. Flutter tests are concentrated on observation forms, API client, review, returned editor, station operations and basic startup/directory behavior. There is no complete role × page × state acceptance matrix yet.

## 5. Required implementation sequence — Flutter first

### F-01 — Source and navigation foundation
- Keep `flutter-app/` as canonical source.
- Forecasting Center now has a persistent bottom-navigation destination (commit `5f881e4`); add navigation/widget regression tests and verify role visibility.
- Record `mobile/metra_mobile/` as retired/reference-only in docs; do not delete it in this pass.
- Implement a consistent authenticated shell, station context and route registry.
- Make forecasting, reports, observations, operations and account areas discoverable without duplicate navigation.

### F-02 — Identity and account pages
- Password recovery screen and login entry point added in commits 70b4a58 and 8733b4e; widget tests for validation, generic confirmation and safe provider errors added in d225bc8.
- Remaining: registration request, profile, access denied/session expired, and account lifecycle tests.
- Registration review and assignment parity.

### F-03 — Station and observation workflows
- Station detail, selection and authorized context. Station detail baseline is now implemented in commits 88d95df and eb92c0d; widget coverage is in abee1bb and 3431b93.
- Hourly/daily lists, details and history.
- Complete review/return/resubmit states.
- Weather phenomena only after approved API contract.

### F-04 — Operations and audit
- Equipment faults, support incidents and maintenance separation.
- Manual archive confirmation and auditor workspace.
- Monthly archive status and missing-data register where contracts exist.

### F-05 — Reports and specialist pages
- Hourly/daily/monthly/annual/climate/rainfall.
- Agriculture and soil temperature.
- Keep unapproved modules explicitly unavailable; no fake values or fake save.

### F-06 — Forecasting Center
- Live snapshot contract/API integration when available.
- Map, station details, comparison by coordinates/elevation/region.
- Rainfall, wind, pressure, temperature minimum/maximum, humidity and other available observations.
- UTC observation/received timestamps, stale-data states and source identity.
- External source adapter placeholder only; no connection until owner supplies source details.

### F-07 — Quality, security and release
- Widget/unit/integration tests for every page and workflow.
- Role/page/action matrix and direct API denial tests.
- RTL, accessibility, small/large device and rotation tests.
- Offline behavior only after its design is approved.
- `flutter analyze`, `flutter test`, Android build and release-security evidence.

## 6. Acceptance rule

Flutter is not complete until every requirement page is classified as:
- implemented and verified with test evidence;
- intentionally out of Flutter scope with owner-approved rationale; or
- blocked with the exact missing API/domain decision documented.

A file existing, a card linking to a page, or CI compiling the app does not count as page completion.

## 7. Guardrails

- Work only in `gfa437926-tech/metra2027`.
- Do not modify `metra-old` or its database.
- No Supabase SQL, migration, RLS, grants or seed apply without explicit owner approval.
- No merge to `main` or deployment without approval.
- Do not invent meteorological values, station coordinates, role grants or domain formulas.
- Keep source code readable; do not replace source with obfuscated artifacts.


## Implementation update — 2026-11-11 UTC

- Task FLT-AUTH-02 — Password recovery: **implemented, verification pending**.
- Added `flutter-app/lib/features/auth/password_recovery_screen.dart`.
- Connected the login screen to Supabase Auth `resetPasswordForEmail`.
- Added `flutter-app/test/password_recovery_screen_test.dart` covering invalid email, trimmed email submission, privacy-safe success text and provider-error redaction.
- CI triggered by the auth integration: Client CI #812 (Flutter analyze/test + Angular build), URL: https://github.com/gfa437926-tech/metra2027/actions/runs/43029197173. At the time of this audit update it was still running; the test-file commit followed the workflow trigger, so a new run for the latest tip must be checked separately.
- No identity schema, SQL, redirect URL or production setting was changed.


## Further Flutter implementation — 2026-11-11 UTC

### FLT-AUTH-02 — Password recovery
- Status: implemented; automated verification pending.
- Source: `flutter-app/lib/features/auth/password_recovery_screen.dart`.
- Login integration: `flutter-app/lib/core/auth/metra_auth.dart`.
- Tests: `flutter-app/test/password_recovery_screen_test.dart`.
- Privacy: success text is identical whether or not an email maps to an eligible account; provider internals are not exposed.

### FLT-ACCOUNT-01 — Account profile
- Status: implemented baseline; automated verification pending.
- Source: `flutter-app/lib/features/account/account_profile_screen.dart`.
- Navigation integration: `flutter-app/lib/features/home/metra_home.dart`.
- Tests: `flutter-app/test/account_profile_screen_test.dart`.
- Security: the screen does not invent or locally grant roles; it explicitly states that permissions remain server-authoritative. Sign-out requires user confirmation.

### CI evidence
- Client CI #811 passed on prior source tip `8b7eaea`; it does not include the new authentication/profile changes.
- Client CI #816 was triggered for the profile integration commit `e8bce50`; subsequent test-file commits may supersede/cancel earlier runs.
- Latest tip at audit time: `4219b5d`. A CI run for this exact tip must be confirmed before these changes are marked verified.


### FLT-STATION-DETAIL-01 — Station catalogue detail
- Status: implemented baseline; automated verification pending.
- Added `flutter-app/lib/features/stations/station_detail_screen.dart`.
- Directory cards and map markers open the detail route while preserving the selected station callback.
- Detail fields are limited to the station catalogue contract: Arabic/English names, local code, type, operational/approval status, demo flag, coordinates, elevation and WMO ID.
- Missing coordinates/WMO values are shown as unavailable; catalogue metadata is explicitly distinguished from live observations.
- Tests: `flutter-app/test/station_detail_screen_test.dart` and the directory navigation regression in `flutter-app/test/widget_test.dart`.
