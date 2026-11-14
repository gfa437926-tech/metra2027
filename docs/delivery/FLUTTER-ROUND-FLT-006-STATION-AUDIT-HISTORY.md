# FLT-006 — Station audit history and report-contract boundary

- **Date (UTC):** 2026-11-11
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `fix/flutter-client-ci-mainline-2026-11-11`
- **PR:** [#34](https://github.com/gfa437926-tech/metra2027/pull/34)
- **Status:** Implementation committed; Client CI #1133 passed on the updated branch head after the station-switch regression test was corrected.

## Implemented

1. Added `StationAuditEvent` and `getStationAuditLog()` to the Flutter API client.
2. The client calls the existing authenticated API route:
   `GET /api/v1/stations/{stationId}/audit-log?limit=100`
   with a supported limit of 1–250 and the current bearer token.
3. Added a read-only station audit screen displaying the exact projection fields supplied by the existing `get_station_audit_log` RPC: entity/action, actor, event time, optional reason, target user, role code, approval-status transition and validity interval.
4. Added the navigation destination **سجل التدقيق**. A station must first be selected from the approved station directory.
5. The screen explicitly distinguishes station/assignment audit events from meteorological observation history. It provides no edit/delete controls.
6. Added API tests for route, token, response parsing and invalid-limit rejection, plus widget tests for event rendering and permission-denied handling.
7. Replaced the generic reports placeholder with a dedicated reports capability hub covering historical observations, hourly/daily, monthly/annual, climate/homogeneity and export. Each module names the missing contract and is visibly marked as waiting for an API contract; it renders no invented measurements or charts.

## Reports and observation-history boundary

The current reviewed ASP.NET Core route inventory contains no daily/monthly/annual report aggregation API and no submitted/approved observation archive/list/detail endpoint. The existing observation queue is a review workflow and must not be presented as a complete historical archive. Therefore:
- The reports destination remains explicitly unavailable until an approved read/report contract and aggregation definitions exist.
- No client-side climate formula, totals, placeholder measurements or synthetic historical observations were added.
- The station audit screen is not labelled as an observation archive.

## Verification and safety

- Flutter analyzer, Flutter tests and Angular build: **passed on Client CI #1099** for commit `1635b7064843ed5c13711bc0fd47b07a565c2128`.
- No Backend, SQL, migration, Supabase, database, R/Climatol, raw observation or legacy repository changes.
- No database schema change or production deployment.
- CI status must be updated with the exact commit SHA after the workflow finishes.


## Follow-up verification — 2026-11-11T21:19Z

- Fixed a stale-response race in the observation archive screen: a response started for a previously selected station is discarded after the station selection changes or is cleared.
- Added a widget regression test that holds the first station response, loads the second station, then completes the stale first response and verifies the second station's payload remains the only payload shown.
- The initial CI attempt #1132 exposed a test-harness issue (26 passed, 1 failed: the test tried to drag a ListView before one existed). The test harness was corrected; the application analyzer had already passed on that attempt.
- Client CI #1133: **SUCCESS** on commit `f3e6e730b26cb1e874c93657ff342c79abc2aaa2`.
  - Flutter analyze: passed.
  - Flutter tests: **27 passed**.
  - Angular build: passed.
- CI run: https://github.com/gfa437926-tech/metra2027/actions/runs/43101799253
- This verifies the current PR head only; it does not certify the entire Flutter app as complete.
- PR remains Draft and unmerged. No hosted database, Supabase schema, migration, RLS, grant, legacy database or legacy repository was changed.
