# METRA 2027 — Records, AI Quality Assurance & Climate Homogenization

**Status:** implementation contract / staged delivery  
**Target:** Angular web + Flutter field client + ASP.NET Core 10 API + isolated R/Climatol worker  
**Data policy:** immutable source evidence; derived products are versioned; no legacy database access or migration.

## 1. Product modules

### A. Paper records archive
- Upload scanned pages or camera captures; accept PDF, JPEG, PNG and TIFF only after content-type and file-signature checks.
- Capture station, observation date/time range, variable set, source, page number, uploader and capture method.
- Preserve original bytes, SHA-256, size, MIME type, upload time and immutable storage object version.
- Support multi-page documents, non-destructive page rotation/crop, page annotations and review status.
- Search by station, period, variable, source and workflow state. Access is station-scoped and grant-based.

### B. Mechanical recorder archive
Support Thermograph, Hygrograph, Barograph and Pluviograph. Record instrument family/model/serial (when known), chart type, chart start/end, time/value scale calibration, timezone, units, chart speed, scan resolution and calibration metadata. Missing metadata remains explicitly unknown; it must never be guessed.

### C. Image extraction and digitization
- OCR proposes printed/handwritten labels and numeric annotations; chart digitization proposes trace coordinates and time/value samples.
- Store every proposal with model/version, algorithm configuration, image/page hash, bounding box or pixel coordinates, calibration transform, confidence and extraction timestamp.
- Preserve exact source pixel coordinates and calibrated value transformation so a reviewer can reproduce a reading.
- Separate OCR text from curve-trace extraction. A text OCR model is not a chart digitizer.
- Low-confidence, out-of-range, ambiguous and calibration-incomplete proposals enter human review; no silent auto-accept.
- Corrections create new versions and append audit events. Never overwrite the original image or prior extraction.

### D. Three-source comparison
Compare on a common station/time/variable/unit basis: (1) paper register, (2) mechanical chart, (3) electronic/official observation. Display aligned timelines, source images, chart traces, extracted points, pairwise differences, configured tolerances, missing/duplicate readings, time alignment and uncertainty. Each comparison pins source record IDs/versions, normalization rule and tolerance profile versions, and calculation time.

No source is automatically declared truth. A reviewer records a decision, rationale, evidence and (where required) a second approval. Corrections to derived extractions never change original sources.

### E. AI training and model registry
- Dataset registry: versioned source manifests, authority basis, station/time coverage, variable/instrument labels, class balance, exclusions and SHA-256 manifests.
- Annotation workspace: reviewer assignment, double annotation, adjudication and label schema version.
- Deterministic train/validation/test splits grouped by station and time to reduce leakage. Keep final held-out evaluation data inaccessible to training jobs.
- Reproducible training: image preprocessing, code/container digest, hyperparameters, seed, dataset version, resource limits, logs and cancellation.
- Evaluation: OCR CER/WER and exact-field accuracy; curve extraction MAE/RMSE and time alignment; calibration/error by instrument family; confidence calibration and per-station/per-period slices.
- Model registry: immutable versions, artifacts, checksums, lineage, evaluation report, intended use, limitations, status and approval record.
- Deployment requires explicit approval and rollback target. Drift monitoring can recommend review/retraining; it cannot silently replace a production model.
- No trained model is claimed until a real run and held-out evaluation pass.

### F. CLIMATOL and climate homogeneity
- Build series from approved quality-controlled observations without modifying raw records.
- Configure variable, units, period, temporal resolution, candidate/reference stations, completeness, Climatol version and method parameters.
- Run isolated, resource-limited R jobs with validated inputs, per-job workspaces, bounded execution time, no network access and allow-listed output files.
- Review missingness, outliers, breakpoints, reference correlations, pairwise comparisons and metadata changes. A statistical breakpoint is evidence for review, not proof of artificial inhomogeneity; genuine climate signals must not be removed merely because a test detects a shift.
- Preserve raw series and create versioned homogenized derived series with full method/configuration/worker lineage.
- Climate products: daily/monthly/seasonal/annual aggregates, extremes, indices, trends, spatial comparisons and reports only after authoritative definitions, units, missing/trace semantics, calendar boundaries and completeness rules are approved and tested.
- Approval workflow: analyst → independent reviewer → authorized approver; rejected jobs retain evidence and rationale.

## 2. User experience and navigation

### Angular web — full scientific workspace
Add a top-level capability named جودة البيانات والمناخ with routes/pages:
- أرشيف السجلات الورقية
- أرشيف المسجلات الميكانيكية
- استخراج القراءات من الصور
- المقارنة بين مصادر الرصد
- مراجعة القراءات واعتمادها
- مختبر تدريب الذكاء الاصطناعي
- مجموعات البيانات
- إصدارات النماذج
- لوحة التجانس المناخي
- تحليل السلاسل ونقاط الانقطاع
- المحطات المرجعية
- السلاسل الخام والمجانسة
- المعدلات والمؤشرات والاتجاهات
- التقارير العلمية وسجل التشغيل

Reuse the existing application shell and its single sidebar; do not add a second navigation rail. All screens require loading, empty, error, forbidden, unavailable and stale-data states. Never fall back to fictional stations, images, readings, metrics or model results.

### Flutter mobile
Provide field workflows for secure capture/upload, station-scoped archive browsing, image/page metadata, reviewer annotations, extraction review and comparison snapshots. Heavy model training and large Climatol jobs remain server-side; mobile shows job status and review results. Queue uploads safely when offline, show pending/synced/failed state, and never claim server persistence before acknowledgement.

## 3. Security and governance
- Authenticate every API operation. Derive actor identity exclusively from validated JWT subject; ignore client-supplied actor/user/role/station identity.
- Enforce active account, explicit permission grant, active station assignment and exact resource scope on every request. Fail closed on missing configuration or authorization.
- Do not infer permissions from role labels. Use separate, approved, time-bounded and revocable individual grants.
- Apply object-level authorization to every image, page, extraction, dataset, model, job and comparison ID (BOLA/IDOR protection).
- Uploads: allow-list formats; verify magic bytes; enforce size/page/pixel limits; malware scan; store originals privately; issue short-lived scoped download URLs; prevent path traversal and public bucket access.
- Keep secrets server-side. No service-role key in Angular or Flutter.
- Append-only audit for upload, view/export where required, extraction, correction, annotation, training, evaluation, approval, rejection, model activation and Climatol execution.
- Encrypt transport and private storage; define retention/legal hold and backup/restore policy before production.
- No hosted database DDL, data writes, RLS changes, seeds, grants or deployment are part of this branch increment. Future migrations are reviewed source artifacts tested only against disposable PostgreSQL until explicitly approved.

## 4. Scientific invariants
1. Raw observation rows and original source files are immutable.
2. Every derived value is traceable to exact input IDs/versions and code/model/configuration versions.
3. Timezone, calendar, unit conversion, rounding, missing/trace semantics and aggregation definitions are explicit and versioned.
4. No interpolation, gap filling, homogenization or AI correction is silently written back into raw observations.
5. A model confidence score is not a scientific quality flag or an approval.
6. Human decisions retain reviewer, timestamp, rationale and before/after values.
7. Comparisons expose uncertainty and missing evidence; they do not manufacture a preferred source.

## 5. Release gates
A module is not complete merely because a route or mock screen exists. Completion requires a real API contract, authorization, persistence, UI integration, automated tests, operational telemetry, documentation and an exact-head CI pass. Until then, show غير مفعّل / الخدمة غير متاحة with a clear reason.
