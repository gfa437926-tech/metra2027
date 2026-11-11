# Flutter reference-path consolidation — source-to-canonical evidence

- **UTC:** 2026-11-11T16:51:48.627Z
- **Task:** CONSOLIDATE-FLUTTER-02
- **Source tree:** `mobile/metra_mobile/` at `main`
- **Canonical destination:** `flutter-app/` at `work/flutter-canonical-consolidation`
- **Repository:** `gfa437926-tech/metra2027`
- **Status:** Source inventory complete; unique capabilities selectively integrated; full Flutter/visual verification pending.

## 1. Path inventory

The reference tree contains 28 tracked entries including directories. Comparing relative file paths against the canonical Flutter tree leaves one unique Dart screen file:

- `lib/features/forecast_centres/forecast_centre_screen.dart`

That file was **not copied as a duplicate** because the canonical `flutter-app/lib/features/forecasting/forecasting_center_screen.dart` already provides a stronger implementation: catalogue map, search, multi-station selection, server-side comparison for 2–12 stations, station profile API, and explicit no-live-snapshot behavior. The reference screen's local geographic calculation is not substituted for the canonical server comparison contract.

## 2. Common-file disposition

| Reference file | Canonical comparison | Disposition |
|---|---|---|
| `lib/api_config.dart` | Byte-identical | No copy needed |
| `analysis_options.yaml` | Byte-identical | No copy needed |
| `pubspec.yaml` | Byte-identical | No dependency change needed |
| `pubspec.lock` | Different lock snapshots (899 vs 811 lines) | Preserve canonical lock; manifest is identical and no new dependency is required by the merged code |
| `lib/main.dart` | Canonical version includes RTL/Arabic app wrapper | Preserve canonical |
| `lib/core/api/metra_api_client.dart` | Canonical client is substantially larger and exposes more workflows | Preserve canonical; port station coordinate provenance and add authority membership/permission lifecycle methods |
| `lib/core/auth/metra_auth.dart` | Canonical auth is richer | Preserve canonical; add account-state gate and password-recovery deep-link completion |
| `lib/core/widgets/metra_adaptive_navigation.dart` | Unique reusable navigation component | Copied to canonical and integrated into `MetraHome` |
| `lib/features/home/metra_home.dart` | Canonical is substantially larger (637 vs 112 lines) | Preserve canonical; integrate responsive navigation and authority-access route |
| `lib/features/observations/observation_review_screen.dart` | Canonical is substantially richer (406 vs 187 lines) | Preserve canonical; no overwrite |
| `lib/features/stations/station_directory_screen.dart` | Reference screen contains coordinate metadata detail; canonical has separate detail route | Preserve canonical route architecture; add coordinate source/accuracy to model and station/forecast detail views |
| `test/metra_api_client_test.dart` | Canonical suite is broader | Port coordinate-source/accuracy parsing assertions |
| `test/observation_review_screen_test.dart` | Canonical suite is broader | Preserve canonical tests |
| `test/widget_test.dart` | Canonical navigation assertions differ after adaptive integration | Keep canonical test and constrain its viewport to compact NavigationBar mode |
| `README.md`, `DEPLOYMENT.md` | Canonical docs already target `flutter-app/` and CI | Preserve canonical docs; no old path references copied |

## 3. Integrated capabilities

1. Responsive navigation: shared `MetraAdaptiveNavigation` is now used by the canonical home shell (NavigationBar on compact screens, NavigationRail on wide screens).
2. Station metadata: `coordinateSource` and `coordinateAccuracyM` are parsed from the approved station-directory projection and displayed in station detail and forecasting profile.
3. Forecasting: retained canonical API-backed map/comparison screen; no duplicate screen and no invented live weather.
4. Account state: operational home now requires server `account_state=active`; pending/null routes to registration/status; suspended/disabled/rejected/unknown and lookup failures fail closed.
5. Account management: added authority membership/permission request, review, revocation and audit screen using existing server endpoints; registration review links to station/system audit history.
6. Assignment workflow: optional UTC expiry, assignment detail sheet and tests.
7. Recovery: Android/iOS `metra2027://auth-callback` registration, password-recovery event handling and new-password screen.

## 4. Account-specific gaps still open

- The existing registration-status endpoint does not expose the current user's effective authority memberships, station assignments or permission grants; a dedicated access-context API is still needed.
- Authority access UI currently supports self-membership requests and current-user permission requests; it does not yet provide target-user search/delegated membership requests.
- Authority membership/permission request UI does not yet allow an optional `valid_to` end timestamp.
- Station assignment still requires a user UUID because there is no authorized searchable eligible-user endpoint.
- Full admin user profile, contact metadata, assignment history, and user lifecycle controls are not available from current API contracts.
- Supabase Dashboard must allow-list `metra2027://auth-callback`; real-device recovery email round-trip remains pending.

## 5. Non-transfer decisions

- No wholesale directory copy, no replacement of canonical home/auth/API/review screens, and no deletion of `mobile/metra_mobile/`.
- No old station catalogue reuse; all station screens continue to use the approved current station API.
- No database writes, schema changes, migrations, RLS/grants or service-role credentials.
- No merge to `main` and no production deployment.

## 6. Verification boundary

Source tests were added for responsive navigation, station metadata, account-state routing, authority access, registration audit, password update, registration duplicate prevention, and assignment validity/detail. The Client CI run for the pre-correction code tip is not evidence for the latest station-assignment correction. The latest exact-head CI result must be checked before marking the branch verified. Android/iOS signing and real-device tests remain separate release gates.
