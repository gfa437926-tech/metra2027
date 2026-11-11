# Flutter reports and operations CI review

**Review UTC:** 2026-11-11T18:11:13.334Z  
**Repository:** gfa437926-tech/metra2027  
**Branch:** work/flutter-canonical-consolidation  
**Reviewed CI run:** 43074926822  
**Reviewed commit:** 46a46967c3f486e13d8b88f605e6c6a8d9876d31

## Evidence

- Flutter analyzer: **passed**.
- Flutter tests: **90 passed, 2 failed**.
- The preceding run 43074577377 had 88 passed / 4 failed. The two operations-screen queue tests and two submit tests were reduced to the two report/history failures after test changes.
- Angular npm tests and production build passed in the same run; Chromium PWA/IndexedDB smoke repetitions were still running at review time.
- No Flutter source was changed as part of this review; the Flutter implementation path is being actively updated by the parallel contributor.

## Remaining Flutter failures

| Test | Observed failure | Review note / suggested next check |
|---|---|---|
| reports_history_screens_test.dart — manual archive month navigation | requests.lastWhere throws Bad state: No element at line 117; no matching monthly-summary request is present after tapping “الشهر السابق”. | Inspect the captured request list (method, path, query) before lastWhere. Verify the month button callback is reached and that _loadSummary() future is awaited in the test. The API method currently uses GET /api/v1/stations/{stationId}/archive-confirmations/monthly-summary?year=…&month=…. |
| reports_history_screens_test.dart — observation history | The test cannot find “السجلات المطابقة: 2 من 2 سجلاً محمّلاً” at line 176, although both requests and authorization assertions pass. | First assert that the FutureBuilder is not in its error state and surface snapshot.error in the test if it is. Confirm both mock payloads parse as ObservationQueueItem; then assert the loaded count before any type filter. The screen intentionally reads up to 50 review-queue and 50 returned items, not a complete approved/rejected archive. |

## Previously observed operations-test failures now resolved

- Empty-state lookup tests initially used ensureVisible before the lazy list item existed; subsequent test revision reduced the suite failures.
- Form submit taps were outside the 800×600 test viewport after scrolling. The current run no longer reports these two submit tests as failures; keep a deterministic tall viewport or pump the scroll animation after ensureVisible.

## Scope and safety

- These are test/UI integration issues, not evidence of a production data defect.
- Do not bypass the tests or weaken station-scope, authorization-header, UTC-payload or server-response assertions.
- No database migration, RLS/grant change, legacy database access, deployment or main-branch merge was performed.
