# METRA 2027 — Scientific workspaces and complete UI scope

## Scope added to the application navigation

The scientific workspace entry points are:
- `/scientific/climatol`: climate-series homogenization and Climatol workflow.
- `/scientific/records`: paper records and mechanical recorder archive.
- `/scientific/comparison`: three-source comparison (paper, mechanical chart, electronic observation).
- `/scientific/quality`: image reading, OCR/digitization review, anomaly and quality-control workflow.
- `/scientific/ai`: dataset, annotation, train/validation/test, experiment, evaluation and model registry workspace.

Each workspace provides overview, operation setup, human review/approval, and audit/history views. The shared screen deliberately labels every unavailable service as disconnected and disables execution controls. It does not fabricate readings, metrics, model versions, OCR output, or homogenization results.

## Scientific and data-integrity rules

1. Preserve original observations and uploaded image bytes as immutable source records.
2. Keep OCR output, curve digitization, comparison findings, and homogenized series as derived records linked to their source hashes.
3. Record station, instrument, parameter, observation time, timezone, page/region coordinates, extractor/model version, confidence, actor, and processing timestamp.
4. Never auto-approve OCR or AI output. Require an authorized human reviewer and a reasoned decision.
5. A detected statistical breakpoint is not, by itself, evidence that a real climate change should be removed.
6. Keep raw and homogenized time series separate; never overwrite source observations.
7. Enforce station/role authorization on every API operation (including object-level checks against IDOR/BOLA).
8. Store dataset splits by station/time group to prevent leakage between train, validation, and test.
9. Model registry entries must include dataset version, source hashes, training configuration, metrics, evaluation report, approval, and deployment status.
10. Uploaded files require malware/type/size checks, private object storage, checksum, and immutable audit events.

## UI workflow details

### CLIMATOL
Series selection; station/reference network selection; variable and period; completeness diagnostics; missing/outlier diagnostics; breakpoint review; isolated job execution; artifact inventory; raw-vs-adjusted overlays; reviewer decision; monthly/seasonal/annual normals, indices, extremes, trends, maps, and report exports.

### Paper and mechanical records
Paper register archive plus Thermograph, Hygrograph, Barograph, and Pluviograph device archives. Each item carries station, instrument, chart/page period, parameter, original file hash, upload actor, capture time, and review state.

### Image extraction and comparison
OCR must preserve image coordinates and confidence for each token. Curve digitization must preserve calibrated axes, pixel-to-value transform, point coordinates, and uncertainty. Comparison aligns all three sources by station, parameter, and time and shows absolute/relative deltas and configured tolerances.

### AI training lab
Dataset versioning, annotation queue, leakage-safe splits, reproducible training jobs, evaluation metrics, model registry, approval gates, staged deployment, drift monitoring, and retraining review. No trained model is claimed until a real dataset and reproducible evaluation exist.


### Flutter workspace coverage

The mobile application now exposes the records workspace as an internal four-part flow: archive, image review/digitization, triple-source comparison, and quality/approval. The CLIMATOL workspace includes homogenization setup, time-series exploration, breakpoint/reference-station review, approval, and climate reports. The AI workspace includes dataset/annotation, leakage-safe split preparation, experiment setup, evaluation, model registry, approval, deployment, and monitoring surfaces.

These mobile screens prepare local UI state only. They do not upload files, run extractors, execute climate jobs, train models, or persist approvals until the secured .NET services are integrated.

## Integration boundary / current status

This change adds the navigable Angular and Flutter workspace UI and workflow affordances only. The R Climatol worker remains in its separate draft PR/branch and is not silently merged here. OCR, image storage, model training, comparison APIs, and production persistence are not connected by this UI-only change. The UI intentionally displays this limitation. No hosted database is modified and no migration is applied.

## Acceptance checklist

- [x] Route entry points and shared workspace navigation.
- [x] Arabic RTL overview, setup, review, and audit/history surfaces.
- [x] Distinct workflows for Climatol, paper/mechanical records, triple-source comparison, quality/OCR, and AI model lifecycle.
- [x] No fabricated operational metrics or results.
- [ ] API contracts and authorization integration.
- [ ] Private image/object storage and immutable audit events.
- [ ] OCR and curve digitization workers with validation.
- [ ] .NET Climatol adapter and job orchestration.
- [ ] AI training/evaluation/model registry services.
- [ ] Angular component tests and end-to-end permission tests.
- [x] Flutter CLIMATOL, AI lifecycle, records archive, image review, comparison, and quality UI surfaces.
- [ ] Flutter field capture, secured upload, and backend integration.
