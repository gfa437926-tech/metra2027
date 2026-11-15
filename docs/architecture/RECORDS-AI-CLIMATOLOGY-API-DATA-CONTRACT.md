# Records, AI and Climatology — API & Data Contract

**Status:** proposed contract for implementation; not a database migration.  
**API root:** /api/v1  
**All identifiers:** opaque UUIDs. All timestamps: ISO-8601 UTC. All paged collections: bounded limit + validated cursor. Mutations use idempotency where retries are possible.

## 1. Logical resource model

| Resource | Purpose | Important invariants |
|---|---|---|
| record_sources | Paper register, mechanical chart, official/electronic source metadata | Source identity and station/time scope immutable once accepted |
| source_files | Original file and immutable derivative inventory | SHA-256, private object key/version, MIME, size, uploader |
| source_pages | Page-level metadata and annotations | Page order and source-file lineage retained |
| instruments | Instrument family, model, serial, calibration metadata | Unknown calibration stays unknown |
| extraction_jobs | OCR/digitization execution | Model/config/input hashes and terminal state |
| extraction_candidates | Proposed text/trace values | Pixel coordinates, confidence, calibration and provenance |
| reading_reviews | Human review and adjudication | Append-only decisions; no silent replacement |
| source_comparisons | Pairwise/three-way comparison snapshots | Exact source versions, normalization and tolerance version |
| dataset_versions | Immutable dataset manifest | Split manifest and lineage immutable |
| annotations | Human labels and adjudication | Label schema version and reviewer provenance |
| training_jobs | Reproducible training executions | Dataset, code, image and seed pinned |
| model_versions | Candidate/approved/retired model registry | Artifact checksum and evaluation evidence required |
| climate_series_versions | Raw or derived series identity | Raw series read-only; homogenized series derived |
| homogenization_jobs | Isolated Climatol run | Worker/version/config/input/output manifest pinned |
| climate_approvals | Independent scientific review | Reviewer/approver separation and rationale |
| audit_events | Security and scientific audit | Append-only; actor derived server-side |

This is a logical resource catalogue, not an approved physical schema. Exact columns, keys, retention and RLS require schema review before migrations are authored or applied.

## 2. REST endpoints

### Source archive
- POST /sources — create source metadata; station and source kind validated server-side.
- POST /sources/{sourceId}/upload-intents — request short-lived, size-limited private upload intent.
- POST /sources/{sourceId}/complete-upload — verify object, magic bytes, checksum and scan status.
- GET /sources — station-scoped search with time/type/state filters and bounded pagination.
- GET /sources/{sourceId} — metadata and file/page manifest.
- GET /sources/{sourceId}/pages/{pageId}/preview-url — short-lived authorized preview URL.
- POST /sources/{sourceId}/pages/{pageId}/annotations — add non-destructive annotations.

### Extraction and review
- POST /extraction-jobs — submit OCR or chart-digitization job with source page, task, approved model and configuration.
- GET /extraction-jobs/{jobId} — status, progress and safe diagnostics.
- GET /extraction-jobs/{jobId}/candidates — candidates with coordinates, confidence and calibration metadata.
- POST /candidates/{candidateId}/review-decisions — accept, correct, reject or request re-extraction; append-only.
- GET /reading-reviews — scoped review queue.

### Comparison
- POST /comparisons — create comparison from explicit paper/chart/electronic source record IDs and versioned comparison profile.
- GET /comparisons/{comparisonId} — aligned readings, pairwise deltas, tolerance outcomes, uncertainty and provenance.
- POST /comparisons/{comparisonId}/decisions — reviewer decision and rationale.

### Dataset, training and model registry
- POST /datasets and POST /datasets/{id}/versions — register dataset and immutable manifest.
- POST /datasets/{id}/versions/{version}/annotations — submit/adjudicate labels.
- POST /training-jobs — submit bounded reproducible training job against immutable dataset version.
- GET /training-jobs/{id} — job state and log summary.
- GET /training-jobs/{id}/evaluation — metrics and held-out evaluation artifacts.
- GET /models and GET /models/{id} — model registry.
- POST /models/{id}/approval-decisions — approve/reject candidate with role separation.
- POST /models/{id}/activation — activate approved model with expected-current-version compare-and-set.

### CLIMATOL and climate products
- POST /climatology/jobs — submit validated station-series selection, period, variable, references and pinned worker/config.
- GET /climatology/jobs/{id} — state, diagnostics and artifact manifest.
- GET /climatology/jobs/{id}/diagnostics — breakpoints, outliers, reference correlations and completeness.
- POST /climatology/jobs/{id}/review-decisions — approve/reject/return with rationale.
- GET /climate-series/{id}/versions — raw and derived versions.
- GET /climate-products — only approved products with definition/version metadata.
- POST /climate-products/{id}/exports — authorized export with audit.

## 3. State machines

**Upload/source:** draft → upload_pending → scanning → available → archived. Failures are explicit and retryable. Rejected/quarantined files cannot enter extraction jobs.

**Extraction job:** queued → running → succeeded | failed | cancelled. Candidate review: pending → accepted | corrected | rejected | needs_reextraction. Job output is immutable.

**Training/model:** queued → running → evaluating → completed | failed | cancelled. Model: candidate → approved → active → retired (or rejected). Approval references immutable evaluation report and dataset version.

**Homogenization:** queued → validating → running → diagnostics_ready → under_review → approved | rejected | failed | cancelled. Publication creates a new derived series version; it never mutates raw values.

## 4. API response conventions
- 401 unauthenticated, 403 unauthorized/out-of-scope, 404 absent or intentionally undisclosed, 409 stale expected version/state, 413 upload too large, 415 unsupported format, 422 invalid scientific/configuration input, 503 worker/storage unavailable.
- Return stable machine-readable error codes; never expose credentials, object-store paths, stack traces or private worker filesystem paths.
- Use ETag/expected-version for workflow transitions.
- All list endpoints enforce maximum page size and station/authority scope before querying.
- Long-running jobs return a job ID; clients poll or subscribe only through authenticated scoped channels.

## 5. Scientific payload rules
Every reading has value, unit, observed_at_utc, source_record_id/version, method, quality/review state and provenance. Trace-derived readings additionally require x/y pixel coordinates and a versioned chart calibration transform. Derived values retain original inputs and conversion-rule version.

A comparison profile defines allowed time alignment, units, tolerance by variable/instrument, missing/trace treatment and uncertainty policy. It must be approved and versioned; there is no universal hard-coded tolerance.

A climate product definition pins aggregation calendar, day boundary, units, completeness threshold, missing/trace semantics, formula/code version and source series versions. Do not implement monthly/annual totals or indices until authoritative domain definitions are available and tested.

## 6. Authorization matrix (minimum)
| Capability | Minimum policy |
|---|---|
| Upload/browse source | Active account + explicit archive grant + exact active station assignment |
| View/download image | Same as source plus object-level authorization and short-lived URL |
| Review extraction | Separate review grant; station scope; no self-approval where separation is required |
| Create/compare sources | Explicit comparison capability and access to every referenced source |
| Create dataset/train | AI-lab capability; dataset scope; bounded compute quota |
| Approve/activate model | Independent model-approver grant; cannot approve own training run |
| Run Climatol | Climate-analyst grant; station/series scope and worker policy |
| Approve homogenization | Independent climate-approver grant; cannot approve own run |
| Export | Explicit export grant, scoped data, audited purpose and bounded output |

Role names alone never grant access. Every referenced object is re-authorized; possession of a UUID is not authorization.
