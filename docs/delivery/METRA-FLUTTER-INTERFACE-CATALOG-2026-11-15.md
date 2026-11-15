# METRA 2027 — Flutter interface catalogue

**Delivery scope:** Flutter/Dart only. Angular is intentionally deferred.

This catalogue describes the current mobile navigation and the scientific sub-workspaces. A visible screen or local draft is not evidence that a server workflow, data persistence, OCR engine, scientific runtime, or production deployment exists.

## Main navigation — 14 destinations

| # | Arabic destination | Screen responsibility |
|---:|---|---|
| 1 | الرئيسية | Operational dashboard and shortcuts to stations, observations, reports, scientific workspaces and instruments. |
| 2 | المحطات | Station catalogue, map/list views, filters and station selection. |
| 3 | التنبؤ | Forecast-centre and forecast-product workspace. |
| 4 | ساعي | Hourly observation entry. |
| 5 | يومي | Daily observation entry. |
| 6 | مراجعة | Submitted observation review and approval/return flow, subject to server authorization. |
| 7 | تدقيق | Electronic observation audit and station audit entry. |
| 8 | تقارير | Reports hub and protected observation archive entry. |
| 9 | ذكاء | AI lifecycle workspace (subsections below). |
| 10 | مناخي | CLIMATOL and climate homogenization workspace (subsections below). |
| 11 | مستخدمون | User administration, account/role and station assignment surfaces. |
| 12 | إعدادات | Account, sign-out, language/display, help and station audit shortcut. |
| 13 | السجلات | Paper/mechanical recorder archive, image audit and triple-source comparison. |
| 14 | الأجهزة | Instrument inventory, station deployment, calibration and maintenance. |

Navigation is shared and adaptive for compact and wide screens, with RTL direction and horizontal scrolling when the number of destinations exceeds the available width.

## Recorder archive and image audit

1. **Archive:** metadata definition for station, instrument, recorder family and capture period; paper register and the four mechanical families: Thermograph, Hygrograph, Barograph and Pluviograph.
2. **Image review:** original image, derived display preparation, chart calibration, OCR/curve extraction review, human correction and approval surfaces.
3. **Triple-source comparison:** paper value, mechanical-chart value and electronic observation aligned by station, variable, time and unit; discrepancy and reviewer decision surfaces.
4. **Image vs ground-truth comparison:** original image and extraction candidate side-by-side with the independently approved reference value, provenance, timestamps, units, absolute/relative differences and tolerance decision.
5. **Quality and approval:** source completeness, image quality, scale calibration, extraction confidence, review decisions, provenance and audit reporting.

The typed capture form validates UUIDs, recorder family, ISO-8601 capture boundaries, timezone and chart type. Its current draft remains local-only.

## CLIMATOL and climate homogenization

1. Job preparation and input series selection.
2. Time-series explorer and source/raw-series context.
3. Candidate breakpoint detection and reference-station review.
4. Adjustment/version review, immutable corrected-series lineage, monthly/seasonal/annual climate reports, normals, trends and indices.

The interface does not claim to execute CLIMATOL or produce corrected data until the secured runtime and API are deployed.

## AI lifecycle

1. Dataset inventory, source images, ground-truth assets and versioning.
2. Annotation and correction surfaces for OCR values, timestamps, chart axes and recorder traces.
3. Train/validation/test preparation with station/time leakage controls.
4. Experiment preparation, training-job status, metrics (CER/WER, MAE/RMSE, precision/recall, F1 and calibration), model registry, evaluation, approval, deployment and monitoring.

Training, inference, model persistence and deployment remain server-gated. No synthetic model results are shown.

## Instrument lifecycle

1. Instrument catalogue and metadata.
2. Station deployment periods and assignment constraints.
3. Calibration certificates, reference standards, uncertainty, validity and due dates.
4. Maintenance tickets, downtime, repair actions and lifecycle status.

The new instrument workspace currently creates local drafts and explicit empty states; it does not write to the backend.

## Shared controls and operational boundaries

- Arabic RTL, shared METRA design tokens and adaptive navigation.
- Empty/loading/error/unavailable states instead of fabricated station observations or scientific results.
- Client never connects directly to operational PostgreSQL tables.
- No service-role credentials in Flutter.
- No migration or write to the legacy database or hosted Supabase during this UI work.
- The scientific ERD/data dictionary must be reviewed and approved before executable migrations or hosted schema changes.
- Production readiness still requires secured .NET APIs, object storage and quarantine scanning, OCR/curve digitization, CLIMATOL runtime, AI orchestration, integration tests, Android/iOS release builds, signing and staging verification.
