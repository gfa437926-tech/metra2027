# Acceptance & Verification Plan — Records, AI and CLIMATOL

**Status:** required gates for staged implementation. No test pass is implied by this plan.

## 1. UI acceptance
- All routes are registered in the existing Angular shell; exactly one shared sidebar remains.
- Arabic RTL labels, keyboard navigation, focus visibility, accessible image alternatives and responsive desktop/tablet/mobile layouts.
- Upload progress, retry, cancellation, offline queue (mobile), checksum confirmation and explicit scan/quarantine status.
- Every page has loading, empty, error, 401, 403, 404, 409 and 503 states where applicable.
- No fake station, observation, chart, model metric, breakpoint, comparison result or sample job appears as production data.
- Flutter supports camera/gallery capture and station selection from the approved API; it never trusts a station ID supplied only by local state.

## 2. API and security tests
- Unauthenticated requests never access storage, worker or database services.
- Cross-station and cross-authority object ID substitution tests for every source, page, extraction, comparison, dataset, model and climate job endpoint.
- Same-authority station A/B negative tests; revoked/expired grants; inactive account; expired station assignment; missing role/grant; stale JWT; role-name spoofing.
- Actor identity spoofing tests prove the API always derives actor from verified JWT subject.
- Object storage tests: private-by-default, signed URL expiry/scope, content signature, MIME mismatch, oversized file, decompression bomb, pixel/page limits, path traversal, malware quarantine and checksum mismatch.
- Audit tests prove append-only behavior for UPDATE/DELETE/TRUNCATE and record actor, timestamp, reason and source version.
- Idempotency and concurrent transition tests for upload completion, review decisions, model activation and job submission.
- Rate limits, quotas, cancellation, timeout, retry safety and bounded worker output.

## 3. Image extraction evaluation
- Keep a held-out evaluation set grouped by station and time; prevent page/scan leakage across splits.
- OCR: character/word error rate, exact-field accuracy, numeric sign/decimal accuracy, confusion matrix by handwriting/print and instrument type.
- Curve digitization: pixel-to-value MAE/RMSE, timestamp alignment error, calibration uncertainty and trace segmentation accuracy.
- Report metrics by station, instrument family, chart template, scan resolution and time period.
- Verify uncertainty propagation and that low-confidence values are routed to human review.
- No automatic acceptance threshold until meteorological owners approve it.

## 4. AI training/model governance
- Reproducible training from dataset version + code/container digest + parameters + seed.
- Train/validation/test separation; no test-set tuning; no cross-station/time leakage.
- Model card, dataset provenance, authority basis, intended use, failure modes and evaluation report required before approval.
- Candidate cannot activate without independent approval; rollback restores previous approved version.
- Drift alert only creates a review task; it does not retrain or activate automatically.
- Validate operation without live station data only against representative, approved offline datasets and documented performance bounds.

## 5. CLIMATOL/scientific tests
- R worker input validation, path containment, per-job isolation, no arbitrary shell execution, no network, resource/time limits and output allow-list.
- Test missing values, duplicated timestamps, non-monotonic series, leap years, calendar boundaries, unit mismatches, incomplete reference coverage and insufficient correlated reference stations.
- Reproduce output from pinned Climatol version/configuration/input manifest.
- Verify all outputs are derived and raw observations remain byte-for-byte unchanged.
- Review false-break scenarios representing genuine climate shifts; breakpoints must not be auto-deleted or auto-corrected.
- Independent reviewer/approver workflow; rejected jobs preserve artifacts and rationale.
- Aggregate/extreme/index/trend calculations require authoritative formula and units fixtures before implementation.

## 6. Release gates by module
| Module | Required evidence before status = complete |
|---|---|
| Paper archive | Private storage, checksum, metadata, station scope, API/UI tests |
| Mechanical archive | Instrument metadata, calibration provenance, image workflow tests |
| OCR/digitization | Real inference service, evaluation report, review queue, reproducibility |
| Three-source comparison | Approved normalization/tolerance profiles, alignment tests, reviewer workflow |
| AI lab | Dataset registry, reproducible training, held-out metrics, model approval/rollback |
| CLIMATOL | Integrated isolated worker, .NET adapter, diagnostics, scientific review and derived-series persistence |
| Climate products | Approved definitions, tested formulas, provenance and report/export security |

## 7. Integration sequence
1. Review existing archive PR #34 (Flutter) and #35 (.NET + disposable PostgreSQL tests); resolve branch/base divergence and station-scope grant limitation before integration.
2. Port isolated R worker from PR #18 only after verifying the complete head, edge-case CI and worker threat model; add a .NET adapter and job persistence contract.
3. Implement source archive metadata and private file storage behind approved server configuration.
4. Add mechanical chart metadata, extraction adapters and reviewer workflows.
5. Add source comparison using approved scientific profiles.
6. Add dataset/annotation/training/model registry pipeline.
7. Add CLIMATOL diagnostics, approval and derived series; then approved climate products.
8. Run exact-head Angular, Flutter, .NET, PostgreSQL security, R CMD check and end-to-end workflows; publish evidence before marking any module complete.

## 8. Explicit non-goals for this implementation branch
- No merge to main.
- No hosted Supabase migrations, DDL, RLS changes, seeds, user grants or production data access.
- No access to or changes in METRA OLD or its database.
- No import of legacy stations or observations.
- No deployment, paid compute provisioning or model training against unapproved data.
- No claim of completed OCR, AI training or scientific homogenization until real pipelines and acceptance tests pass.
