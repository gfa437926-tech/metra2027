# METRA — منظومة التدقيق الذكي للسجلات الورقية والمسجلات الميكانيكية

**AI-Powered Meteorological Records Audit System — Formal Specification v1**

| Field | Value |
|---|---|
| Status | **Specification for owner review** — not implemented as production capability |
| Repository | `gfa437926-tech/metra2027` |
| Branch | `work/legacy-ui-migration-audit` |
| Related design | `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md` |
| Master plan | `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-MASTER-PLAN.md` |
| Scaffold UI | Angular `/electronic-auditor` (structural only) |
| Constraints | No legacy DB; no Supabase SQL apply without approval; no main merge; UTC only; no invented observation values or accuracy claims |

---

## 0. Purpose and non-goals

### 0.1 Purpose
Deliver an **independent audit subsystem** that:

1. Ingests **official paper station register pages** and extracts structured meteorological values.
2. Ingests **mechanical recorder charts** (thermograph, hygrograph, barograph, pluviograph, and other **documented** types) and digitizes curves into time series.
3. Compares extracted values with **electronic METRA observations**.
4. Optionally compares paper ↔ mechanical ↔ electronic (triple-source audit).
5. Runs versioned physical and mathematical checks.
6. Supports a **controlled AI training laboratory** with human-approved labels only.
7. Never silently mutates original electronic observations or original images.

### 0.2 Non-goals (v1 program)
- Claiming production OCR/curve accuracy before independent reference test sets exist.
- Auto-approving observations or overwriting `metra_observations.payload`.
- Training on the model’s own unreviewed outputs (prevents error amplification).
- Requiring station live connectivity for **offline extraction** of values from an image (connectivity is required only for **electronic match**).
- Inventing register templates, instrument scales, or station coordinates.

---

## 1. Two primary tracks

### Track A — Official paper registers (Daily / station registers)

**Input:** Photograph or scan of each official register **page**.  
**Metadata binding (required):** `stationId`, calendar date (UTC day rules per product), page number, register type/template id (when known).

**Pipeline:**
1. Store **original** image + SHA-256; never delete via app roles.
2. Classify page/template (AI + optional human confirm).
3. Detect cells/fields (document understanding).
4. Extract numbers, symbols, times, units; map to METRA element codes.
5. Structure as rows keyed by observation time (UTC).
6. Fetch electronic submissions for the same station/period (authorized).
7. Cell-level compare; highlight deltas.
8. UI: image + extracted table + electronic table; click value → bbox on image.
9. Emit audit outcome + findings list.

**Illustrative compare table (fictional numbers for UX only — not real observations):**

| Element | Paper extract | Electronic | Result |
|---|---|---|---|
| Temperature | 18.5 | 18.5 | match |
| Pressure | 1008.2 | 1006.2 | mismatch |
| Humidity | 72% | 72% | match |
| Wind speed | 12 | 21 | mismatch |

### Track B — Mechanical recorder charts

**Input:** Chart image for a supported instrument type/model.  
**Pipeline:**
1. Store original + hash.
2. Classify instrument family/model/chart layout from **instrument library** (no assumption that all charts share one layout).
3. Axis/scale/calibration definition (AI assist + mandatory human calibration for early releases).
4. Curve extraction → `(tUtc, value, confidence)`.
5. Compare to paper register samples (if present) and to electronic series with **explicit temporal alignment rules**.
6. Physical + mathematical engines (versioned rule packs).
7. Mark mismatch loci on the chart image.
8. Report agreement, confidence, residual uncertainty.

**Supported families (catalogue-driven; expand only when documented):**
- Thermograph  
- Hygrograph  
- Barograph  
- Pluviograph  
- Other types only after owner catalogue entry (model, scale, period, calibration reference)

---

## 2. Triple-source comparison engine

```
Paper register extract  ──┐
Mechanical curve series ──┼──► Central audit engine ──► Outcome + report
Electronic METRA values ──┘
```

**Engine responsibilities:**
- Element-wise and time-window matching (not page-level only).
- Temporal alignment policy per observation product (continuous chart vs discrete register times).
- Physical rule pack evaluation.
- Mathematical consistency / delta / missing-rate metrics.
- Confidence and “needs human review” flags.
- Outcomes: `match` | `mismatch` | `possible_error` | `inconclusive` | `needs_human_review` | `rejected_poor_image`

**Offline vs online:**
| Capability | Needs station electronic data? |
|---|---|
| Image classification + value/curve extraction | **No** (uses trained models + library) |
| Physical/math checks on extracted series alone | Partially (rules only) |
| Proof of match to observer submission | **Yes** (authorized METRA read) |

---

## 3. AI model suite (logical)

| Model | Role |
|---|---|
| Image classifier | Page type / instrument chart type |
| Document understanding | Tables, cells, handwriting/print regions |
| Value extractor | Digits, symbols, units, times |
| Curve digitizer | Polyline → time series |
| Anomaly / mismatch detector | Inconsistent values, large deltas |
| Confidence estimator | Clear vs doubtful readings |

### 3.1 Training laboratory (separate subsystem)
1. Collect images with provenance (station, device, date, capture conditions).  
2. Human specialists create **reference labels** (values, boxes, curve anchors).  
3. Build train/validation/test splits; **no leakage** of test images into training.  
4. Train candidate model versions.  
5. Evaluate on held-out multi-station / multi-device sets.  
6. **Promotion gate:** metrics + safety review + designated approver.  
7. Continuous learning **only** from human-approved corrections; store model version, metrics, rollback target.

**Forbidden:** auto-labeling production traffic into training without human approval.

### 3.2 Model governance records
- `modelVersion`, training data snapshot id, metrics JSON, promoter id, promotedAtUtc, rollbackOf  

---

## 4. Functional requirements (FR)

| ID | Requirement |
|---|---|
| FR-01 | Create audit case bound to station + period (UTC) + track (paper / mechanical / combined) |
| FR-02 | Upload one or more original images; persist content hash; retain originals |
| FR-03 | Record derived (processed) images with processing version; never replace original row |
| FR-04 | Paper: extract structured values with image bounding boxes |
| FR-05 | Mechanical: calibrate axes and extract time series |
| FR-06 | Human override of any extracted sample; mark `source=human_override` |
| FR-07 | Load electronic observations for comparison under station authorization |
| FR-08 | Run triple or dual compare; store pairs and deltas |
| FR-09 | Run physical and mathematical engines with explicit `ruleSetId/version` |
| FR-10 | Record decision by authorized human; **no auto-write to observations** |
| FR-11 | Audit event log append-only (who/what/when UTC) |
| FR-12 | Reports exportable for a case (PDF/structured JSON — format TBD) |
| FR-13 | Instrument/register **library** CRUD for authorized model managers |
| FR-14 | Training lab: datasets, labels, jobs, metrics, promotion (isolated environment) |
| FR-15 | Extraction may run without live station DB; match step degrades gracefully |
| FR-16 | Multi-station generalization tests required before production model promotion |

---

## 5. Non-functional requirements (NFR)

| ID | Requirement |
|---|---|
| NFR-01 | UTC only for observation and chart time bases |
| NFR-02 | Fail-closed station authorization on all case/image/compare APIs |
| NFR-03 | No service-role or training secrets in Angular/Flutter |
| NFR-04 | Immutable original images from application roles |
| NFR-05 | Model inference version pinned and stored on each extraction |
| NFR-06 | Arabic RTL UI for auditor workstation |
| NFR-07 | Traceability: every alert links to image region and rule/model version |
| NFR-08 | Ability to roll back to previous promoted model |

---

## 6. Roles and permissions

Independent from observer submission rights:

| Role (logical) | Capabilities |
|---|---|
| Register uploader | Upload pages/charts for own stations; no final decide |
| Electronic auditor | Review extracts, overrides, run compare |
| Audit approver | Final case decision |
| Model manager | Datasets, training jobs, promotion request |
| Model approver | Promote/rollback model versions |
| System admin | Permission grants only within policy |

**Permission codes (proposed; not wired):**  
`intelligent_audit.case.read|create`, `…image.upload`, `…extract.run`, `…compare.run`, `…decide`, `…report.read`, `…library.manage`, `…training.manage`, `…model.promote`

Observer / forecasting **read** does not imply decide or promote.

---

## 7. Data design (logical — **no migration applied**)

Entities extend `ELECTRONIC-AUDITOR-DESIGN-V1` with paper-track and ML governance:

- `intelligent_audit_case` (track, stationId, periodUtc, status)  
- `intelligent_audit_image` (original|processed, sha256, storageKey)  
- `register_template` / `instrument_chart_profile` (library)  
- `intelligent_audit_extraction` (paper cells or curve samples + bboxes + confidence + modelVersion)  
- `intelligent_audit_comparison`  
- `intelligent_audit_engine_result`  
- `intelligent_audit_decision`  
- `intelligent_audit_event` (append-only)  
- `ml_dataset`, `ml_label`, `ml_training_job`, `ml_model_release`

**Storage:** dedicated object store for images; DB holds metadata and hashes only.  
**Schema apply:** owner approval required; package to be filed under `docs/security/` when ready.

---

## 8. Application architecture

| Component | Tech | Responsibility |
|---|---|---|
| Auditor web UI | Angular | Cases, upload, review, compare, library, reports |
| Field capture | Flutter | Photo capture/upload, case status (not full calibration lab) |
| Core API | ASP.NET Core | AuthZ, cases, compare orchestration, reports |
| Image / CV workers | Python + OpenCV (+ doc/vision models) | Deskew, curve extract, OCR assist |
| Training environment | Isolated (not production API process) | Train/eval/promote artifacts |
| PostgreSQL | New METRA DB only | Metadata, results, governance |
| Object storage | Approved private bucket | Originals and derivatives |

Inference workers receive **job ids and storage keys** from the API; clients never hold worker credentials.

---

## 9. UI information architecture

| Section | Function |
|---|---|
| Audit dashboard | Counts: incoming, match, mismatch, pending review |
| Paper registers | Upload/manage pages |
| Mechanical charts | Upload, classify, calibrate |
| Source comparison | Paper ↔ mechanical ↔ electronic |
| Reading review | Human correction of extracts |
| Errors & alerts | Severity-ranked findings |
| Device & template library | Models, scales, calibrations |
| AI training lab | Images, labels, jobs (restricted role) |
| Model releases | Metrics, promotion, rollback |
| Audit reports | Final outputs and approval trail |

Angular scaffold at `/electronic-auditor` is a **placeholder** until these sections are built.

---

## 10. API sketch (non-normative until implementation)

Prefix: `/api/v1/stations/{stationId}/intelligent-audits`

| Step | Example |
|---|---|
| Create case | `POST /` |
| Upload image | `POST /{caseId}/images` |
| Start extraction job | `POST /{caseId}/extract` |
| Patch samples | `PATCH /{caseId}/extractions/{id}` |
| Compare | `POST /{caseId}/compare` |
| Run engines | `POST /{caseId}/engines/{physical\|mathematical}` |
| Decide | `POST /{caseId}/decision` |
| Report | `GET /{caseId}/report` |

Cross-station → **403** before storage access.  
Feature flags until model promotion criteria are met.

---

## 11. Development phases (program track)

| Phase | Deliverable | DB apply? |
|---|---|---|
| IA-0 | This specification + link from master plan | No |
| IA-1 | Inventory real register templates & instruments from owner sources | No |
| IA-2 | Reference image library process + labeling SOP | No |
| IA-3 | Paper track MVP (upload + manual cell entry + electronic compare) | Schema review first |
| IA-4 | Mechanical track MVP (manual calibration + semi-auto curve) | Review |
| IA-5 | Scientific engines with owner rule packs | Review |
| IA-6 | Training lab MVP (offline) | Isolated |
| IA-7 | Controlled continuous learning + promotion gates | Isolated |
| IA-8 | Offline extraction generalization tests | No prod claim |
| IA-9 | Full METRA integration + AuthZ matrix tests | After approvals |
| IA-10 | Acceptance on held-out multi-station sets | Metrics report |

---

## 12. Acceptance criteria (measurable — thresholds set **after** reference sets exist)

Per register type / instrument family, on **held-out** images:

- Value extraction accuracy (exact / within tolerance)  
- Curve time alignment error  
- Share of samples requiring human review  
- True mismatch detection rate  
- False alert rate  
- Performance on stations/devices **absent from training**  
- Stability across model versions  
- Explainability: each alert maps to image region + rule/model version  

**No single global success percentage** is fixed in this document before the reference corpus is characterized.

---

## 13. Binding principles (proposed project requirements)

1. Independent subsystem: Intelligent Audit for paper registers and mechanical recorders.  
2. Triple-source audit when data exist; graceful degradation when electronic data absent.  
3. Specialized AI for values and curves; governance and versioning mandatory.  
4. Extraction operable without live station connectivity; match is separate.  
5. Continuous learning only from **human-approved** corrections.  
6. No automatic mutation or final approval by the model alone.  
7. Full provenance: images, labels, models, decisions.  
8. Extensible library for new templates/devices without redesigning the core.

---

## 14. Implementation status (honest)

| Item | State as of this document |
|---|---|
| Formal specification | **This file** |
| Prior mechanical-auditor design | `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md` |
| Angular route scaffold | `/electronic-auditor` structural only |
| Production OCR/curve models | **Not present** |
| Training lab | **Not present** |
| SQL / RLS for audit entities | **Not applied** (none written for production apply in this change) |
| Accuracy claims | **None** |

---

## 15. Owner decisions required before build-out

1. Priority order: paper track first vs mechanical first vs parallel.  
2. Supply sample anonymized register pages and chart images for library bootstrapping (or confirm collection SOP).  
3. Designate model approver role holders.  
4. Object storage provider and retention policy.  
5. Whether early MVP allows **manual** digitization only (recommended) before any model promotion.  
6. Schema review package timing relative to core METRA DB approvals.

---

**Document control:** v1 — specification only; supersedes informal chat descriptions; does not authorize SQL apply or production model deployment.
