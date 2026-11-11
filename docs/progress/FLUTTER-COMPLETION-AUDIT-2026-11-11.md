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


### FLT-QUALITY-01 — Flutter analyzer correction
- Client CI #823 failed at `flutter analyze` due to one stale unused optional parameter (`action`) in the legacy `_InformationPage` helper after account settings moved to `MetraAccountProfileScreen`.
- Corrective commit: `a75bc36add6d7e3609eb84aa78b45f1faaabfe1f` removes the obsolete parameter and its unused field/forwarding.
- The failure was isolated to the analyzer warning; Flutter tests were skipped by the workflow because analyze is a prerequisite.
- Client CI #824 was triggered on the correction and is the verification run to monitor. Do not treat #823 as passed.


### FLT-QUALITY-02 — Follow-up analyzer correction
- Client CI #824 confirmed that the first cleanup exposed the same stale optional action parameter on the underlying `_StatusCard` helper (line 175), not a new feature defect.
- Corrective commit: `416539c774d58d545010079c7d9ab47b9c48d4b3` removes the unused optional action field and rendering branch from `_StatusCard`.
- Client CI #824 therefore remains failed; the correction must be validated by a new CI run. Do not mark recovery/profile/station-detail tests verified until that run completes.


## FLT-QUALITY-03 — Client CI #829 test corrections — 2026-11-11T13:37:38.156Z

- Task status: **in progress; source assertions corrected, rerun verification pending**.
- PR #11 head before correction: 6120fb6c0c6c84b77b787f0dc09c91972e124bf9.
- Client CI #829: Angular job **passed** (npm tests, Angular build, and three Chromium PWA/IndexedDB smoke runs).
- Flutter job: `flutter analyze` **passed**; `flutter test` **failed** with 44 passing and 2 failing tests.
- Root cause: two widget tests expected a bare station code, while the actual UI intentionally renders a labeled selectable value (`رمز المحطة: <code>`). This was an assertion/UI-contract mismatch, not a runtime analyzer failure.
- Corrected `flutter-app/test/station_detail_screen_test.dart` to assert the visible labeled code: commit `c8213830edba2e0fafa6cacfa1e89313bb08ef3c`.
- Corrected `flutter-app/test/widget_test.dart` to assert the visible labeled code after directory navigation: commit `381eafab46153ac1d9d84248925f478f98a20470`.
- Current PR #11 head at this update: `381eafab46153ac1d9d84248925f478f98a20470`.
- Fresh CI result for this exact head is not yet available; do not mark Flutter tests verified until a new Client CI run completes successfully.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-AUTH-03 — Two-stage registration request UI — 2026-11-11T13:46:39.786Z

- Task status: **implemented baseline; verification pending**.
- Added `flutter-app/lib/features/auth/registration_screen.dart`:
  - Supabase identity creation is a separate first step; no METRA role is granted by identity creation.
  - After authentication, loads only active, approved, non-demo stations from the current station directory and requestable roles from `GET /api/v1/registration-roles`.
  - Loads account registration state from `GET /api/v1/account/registration-status`.
  - Submits first/father/family name, optional phone, station, requestable role, terms version `metra-terms-2026-11`, and a cryptographically random idempotency key to `POST /api/v1/registration-requests`.
  - Displays pending station/system approval, active/rejected/suspended/disabled state without granting client-side permissions.
  - Uses server response as authority; no client-side role assignment, no privileged key, no SQL.
- Added login entry point and a signed-in “more” menu entry to continue/track registration.
- Added API client methods for requestable roles, current registration status and registration submission.
- Added widget tests for filtering demo stations, selecting a requestable role, submitting the canonical request envelope, pending status and email-confirmation flow.
- Source commits: `9efec07064936a7cad99dc68432ef1fe1f4c1cff`, `eb915af974b18dd08afe5ffefba4574a9178c993`, `2281fe537457d2fc4f45e70d0c8e8865e6b42b15`, `57702513ee46005ae78fbdb2091bb3ec5fc486bf`.
- Test commit: `acdc0bdc1e774c553863346599575d564f257bb9`; follow-up picker assertion correction: `f1f33357081377341c49456407953567c393d3e7`.
- CI found a registration-screen collection syntax error and analyzer infos in the first implementation. Corrected in `84187f1c7688292b286fbd808cdc162b9b231320`, `1031381fc520539ab2173f359e1a0040d7277aaa`, and `1219722948a82a4b48d2aac535851c410249f9ab`.
- Client CI #833 (run `43030878129`) had `flutter analyze` pass and 45 tests pass / 1 fail; failure was the station detail footer assertion before scrolling. Test corrected in commit `23031e69c30d813be5ea8c830269d62ac8e0970c`.
- Client CI on the registration screen initial implementation (run `43031853120`) failed at analyze due to the syntax error; Flutter tests were skipped. This is not a passing run.
- Exact-head verification for current source tip `1219722948a82a4b48d2aac535851c410249f9ab` is pending. Do not mark this feature or the station detail footer test verified until Client CI completes successfully.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-AUTH-03 — Registration lifecycle verification — 2026-11-11T14:06:21.913Z

- Task status: **منجزة ضمن واجهة Flutter؛ CI أخضر على مصدر هذه الجولة**.
- Delivered files: `flutter-app/lib/features/auth/registration_screen.dart`, API client registration methods, login registration entry, shared “more” menu registration/status entry, and `flutter-app/test/registration_screen_test.dart`.
- The flow separates Supabase identity creation from the METRA station/role approval request; it only offers server-returned requestable roles and active/approved/non-demo stations. It submits a versioned terms acknowledgement and secure idempotency key. No role is granted by the client.
- Test fixture was corrected to use UTF-8 bytes for Arabic JSON; the registration widget test uses a full-height test viewport so consent and submit controls are interactable.
- Exact verification: Client CI #43034587973 — `flutter pub get` success, `flutter analyze` success, **48 Flutter tests passed**. Angular npm tests and build also passed in the same workflow; Chromium PWA/IndexedDB smoke step was still running at this documentation snapshot.
- Verified source tip: `39452b0ada03dffb536773dbca59c5786e3e93b4`.
- Earlier failed runs are retained as failure history, not counted as passes: #43032212381, #43032484963, #43032957896, #43033286062, #43033776011, #43034322385. Their root causes (Arabic test fixture encoding, viewport/scroll interaction, and ambiguous scrollable selection) were corrected in subsequent test commits.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-AUTH-03 — Two-stage registration UI — 2026-11-11T14:07:16.205Z

- Task status: **منجزة ومتحقق منها في Flutter**.
- Delivered: `flutter-app/lib/features/auth/registration_screen.dart`; registration-role/status/submit API methods; login entry; signed-in shared-menu entry; widget test.
- Flow: Supabase identity creation is separate from METRA registration. The form loads only active, approved, non-demo stations and server-returned requestable roles, records terms version `metra-terms-2026-11`, sends a secure idempotency key, and displays the server's approval state. The client never grants a role.
- Test fixture uses UTF-8 byte responses for Arabic JSON. The form test uses a full-height test viewport to exercise consent and submit controls.
- Verified Client CI #43034587973 on source SHA `39452b0ada03dffb536773dbca59c5786e3e93b4`: `flutter pub get` passed, `flutter analyze` passed, **48 Flutter tests passed**. Angular npm tests and build passed in the same run; Chromium PWA/IndexedDB smoke was still running at the time of this record.
- Prior failing CI runs remain failures, not passes: #43032212381, #43032484963, #43032957896, #43033286062, #43033776011, #43034322385. Root causes were corrected in subsequent commits (Arabic fixture UTF-8 encoding; form test viewport interaction; scrollable finder ambiguity).
- Documentation commit: `af4fc58b9e74da9affd3e4674bde76e8c6a5e770`.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-FORECAST-UI-01 — Forecasting centre station map — 2026-11-11T14:11:00Z

- Task status: **implemented baseline; exact-head CI verification pending**.
- Added an interactive catalogue map to `flutter-app/lib/features/forecasting/forecasting_center_screen.dart` using the existing `flutter_map` / `latlong2` dependencies.
- Only validated coordinates from the current approved station-directory API are plotted. Stations with missing/invalid coordinates remain visible in the station list and are explicitly counted; no coordinates or weather readings are fabricated.
- Map markers toggle station selection; selected stations can be compared by great-circle distance and elevation difference. The comparison is geographic metadata only and is not described as a meteorological correlation.
- Kept the live-observation boundary explicit: temperature, wind, rainfall and bulletin details remain unavailable until an approved live snapshot/bulletin API contract exists.
- Added `flutter-app/test/forecasting_center_screen_test.dart` covering catalogue map availability, station selection, geographic comparison and elevation delta.
- Source commit: `59cec32c4a37bbb921e87ba6e83f59d6549a91f1`.
- Widget test commit: `e59d272a0448b3d97cbabd218be1d09c46a7b8a7`.
- Current PR #11 head: `e59d272a0448b3d97cbabd218be1d09c46a7b8a7`. No workflow run was returned for this exact SHA at the time of this note.
- Client CI #861 (`43036054744`) was pending for the prior head `4af504672a1d1fc45839a2d33558f5960ad9b31c`; it cannot verify these newer commits.
- No SQL/migrations/RLS/grants/seeds were applied; no legacy database or `metra-old` changes; no merge to main.


## FLT-FORECAST-UI-01 — CI finding and correction — 2026-11-11T14:14:00Z

- Client CI #865 (run `43036369712`) checked the forecasting map and test change.
- Flutter dependency resolution passed. `flutter analyze` failed only in the newly added widget test because it used unsupported `TestFlutterView.setPhysicalSize/setDevicePixelRatio` methods and awaited synchronous reset methods. The workflow therefore skipped `flutter test`.
- Corrected the test to use the supported `tester.view.physicalSize` and `tester.view.devicePixelRatio` properties and synchronous reset methods.
- Correction commit: `0d8bc257451d1266faef827848b355cbedba92f4`.
- Client CI #865 is a failed run; exact-head rerun is required. The map feature is implemented but **not yet verified**.
- The Angular job had passed npm tests and build; Chromium smoke was still running when the Flutter analyzer failure was read.
