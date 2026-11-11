# METRA 2027 — Work log

## 2026-11-11 — REQ-002 + Flutter specialist scaffolds

**Branch:** `work/legacy-ui-migration-audit`  
**Tasks:** REQ-002, FLT-001 update, FLT-010–017 scaffolds, nav wiring  

### Done
- Listed RAR archive (171 files); documented page modules.
- Confirmed canonical Flutter path is `flutter-app/` (CI + README).
- Added honest specialist shells (no fake observation totals).
- Added Electronic Auditor Flutter scaffold linked from More menu.
- Wired daily entry and specialist entry points from home More menu.
- Updated requirements traceability and progress docs.

### Tests
- Not run in this environment if Flutter SDK absent — record actual CI after push.

### Constraints honored
- No legacy DB touch; no Supabase migration apply; no main merge.

## 2026-11-11 — FLT-006 station directory search

**Tasks:** FLT-006  
**Done:**
- Client-side search on station directory (name, code, WMO, type/status text).
- Empty search-result state; selected-station hint.
- Unit tests for `filterStationDirectory`.
**CI note:** Prior Client CI on `5da9d38` — Flutter job success; Angular Chromium install failed (env), unrelated to Flutter change.
**Constraints:** No DB apply; no main merge.

## 2026-11-11 — FLT review type filter

**Done:** Client-side FilterChip on observation review (hourly/daily/phenomenon) without changing server contracts.

## 2026-11-11 — CI on work branch + reports navigation

**Done:**
1. Client CI and Backend CI now trigger on `work/legacy-ui-migration-audit` (previously main-only; explains missing runs).
2. Chromium install step: one automatic retry (still fails the job if both attempts fail; no skip).
3. More menu: «حالة نشرات المحطة» and «تقارير المحطة» require selected station then open live API-backed screens.
4. ObservationStatusScreen: lists review/returned items in UTC, 403/401 messages, open review action, phenomenon counts.
5. StationReportsHubScreen: Scaffold for standalone navigation.

**Constraints:** No SQL, no main merge, no old DB.

### CI workflow update blocked
Attempted to add `work/legacy-ui-migration-audit` to Client/Backend CI `on.push.branches`.
Push rejected: PAT lacks `workflow` scope.
**Owner action required:** either grant the token `workflow` scope, or edit
`.github/workflows/client-ci.yml` and `backend-ci.yml` in the GitHub UI to include:
`branches: [main, work/legacy-ui-migration-audit]`

## 2026-11-11 — deferred to end of workstream
- Automatic CI path filters for work branch (needs `workflow` scope).
- Angular Chromium install / offline browser e2e flakiness in Client CI.
- Live forecasting meteorological snapshot (pending contract + owner approval).
- Specialist unit APIs (rainfall/climate/agriculture/soil/AI/Climatol).
- Supabase SQL apply, main merge, staging publish.
