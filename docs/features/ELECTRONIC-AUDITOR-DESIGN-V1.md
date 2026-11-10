# Electronic Auditor — المدقق الإلكتروني Design v1

**Status:** Design for owner review — **not implemented** in API/UI/DB  
**Branch:** `work/legacy-ui-migration-audit`  
**Tip at authoring:** `b069f648031c33aed478e20e11e9f3055f27eed9`  
**Related:** `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-MASTER-PLAN.md`

## 1. Purpose

Provide a specialized technical–scientific workflow to:
1. Ingest **mechanical recorder paper charts** (thermograph, hygrograph, barograph, pluviograph, …).
2. Digitize curves into time-stamped values (UTC).
3. Compare against **electronic** observations already stored in METRA.
4. Run versioned **physical** and **mathematical** validation engines.
5. Record an audit decision and report **without** silently overwriting original electronic observations.

This is **not** generic OCR product packaging. Accuracy claims are forbidden until measured against independent human reference charts.

## 2. Out of scope (v1 design)

- Auto-correction of `metra_observations.payload`
- Deletion of original uploaded chart bytes
- Use of legacy DB or metra-old assets
- Applying SQL to Supabase without owner approval
- Invented instrument models, scale factors, or chart templates

## 3. Instrument catalogue policy

Supported types are **placeholders pending owner catalogue**:

| Type code | Name | Chart characteristics (TBD from catalogue) |
|---|---|---|
| `thermograph` | Thermograph | Time × temperature scale |
| `hygrograph` | Hygrograph | Time × RH% scale |
| `barograph` | Barograph | Time × pressure scale |
| `pluviograph` | Pluviograph | Time × precipitation / tip scale |

Each deployed type must record: manufacturer/model (if known), scale units, chart period, calibration reference document id/version, digitization SOP version.

## 4. Domain model (logical — no migration applied)

```
ElectronicAuditCase
  id, stationId, instrumentType, instrumentSerial, chartPeriodStartUtc, chartPeriodEndUtc
  status: draft | images_ready | calibrated | extracted | compared | decided | closed
  createdBy, createdAtUtc

ElectronicAuditImage
  id, caseId, kind: original | corrected
  contentSha256, contentType, storageKey, widthPx, heightPx
  uploadedBy, uploadedAtUtc
  qualityFlags[]

ElectronicAuditCalibration
  id, caseId, imageId
  axisModel (JSON: origin, xUnitPerPx, yUnitPerPx, timeBaseUtc, valueUnit)
  calibrationPoints[]
  calibratedBy, calibratedAtUtc, methodVersion

ElectronicAuditExtractedSeries
  id, caseId, calibrationId
  samples[]: { tUtc, value, confidence, source: machine|human_override }
  extractedAtUtc, extractorVersion

ElectronicAuditComparison
  id, caseId, seriesId
  electronicObservationIds[]
  pairs[]: { tUtc, chartValue, electronicValue, delta, uncertainty }
  comparedAtUtc

ElectronicAuditEngineResult
  id, caseId
  engine: physical | mathematical
  ruleSetId, ruleSetVersion
  findings[]: { code, severity, message, evidenceRef }
  ranAtUtc

ElectronicAuditDecision
  id, caseId
  outcome: match | mismatch | inconclusive | rejected_poor_image
  notes, decidedBy, decidedAtUtc
  # does NOT mutate observations

ElectronicAuditEvent (append-only)
  caseId, actorId, action, atUtc, payloadJson
```

**Integrity rules**
- Original image rows are immutable from application roles.
- Every processing step references prior artifact ids.
- Machine vs human sample values are distinguished.
- Decision never writes observation payload.

## 5. Workflow steps (API sketch — not implemented)

All routes under `/api/v1/stations/{stationId}/electronic-audits/...` and **RequireStationPermission** (fail closed).

| Step | Method (proposed) | Permission |
|---|---|---|
| Create case | POST `.../electronic-audits` | case.create |
| Upload image | POST `.../{caseId}/images` | image.upload |
| Quality report | GET `.../{caseId}/images/{id}/quality` | case.read |
| Save calibration | PUT `.../{caseId}/calibration` | extract.run |
| Run extraction | POST `.../{caseId}/extract` | extract.run |
| Review/override samples | PATCH `.../{caseId}/series/{id}` | extract.run |
| Compare | POST `.../{caseId}/compare` | compare.run |
| Run engines | POST `.../{caseId}/engines/{physical\|math}` | compare.run |
| Decide | POST `.../{caseId}/decision` | decide |
| Report | GET `.../{caseId}/report` | report.read |

Cross-station access → 403 before storage reads.

## 6. Validation engines

### 6.1 Physical engine
Rules bound to instrument type + unit + documented operating range.  
Each rule carries: `ruleId`, `version`, `referenceDoc`, `appliesToInstrument[]`, `severity`.  
Examples of **rule shapes** (values not invented here): range checks, impossible RH, pressure rate limits **only when reference tables are supplied by owner**.

### 6.2 Mathematical engine
Consistency between chart series and electronic series: max |delta|, time alignment tolerance, missing-sample ratio, correlation thresholds — **parameters versioned and referenced**, not hard-coded magic numbers without citation.

Engines return findings; they do not approve observations.

## 7. UI (Angular primary)

Screen regions:
1. Case header (station, instrument, period UTC, status)
2. Original image viewer (zoom/pan) — read-only original
3. Corrected image layer (if any)
4. Calibration tools (axis points)
5. Extracted curve overlay
6. Sample table (machine/human)
7. Electronic values table
8. Delta / uncertainty
9. Engine findings
10. Decision + notes + actor + time UTC

Flutter: optional **case list + read-only detail** for field supervisors; full calibration remains desktop/web.

## 8. Image processing service

- Separate worker (OpenCV or equivalent) invoked by backend job id  
- Inputs: storage key of original, calibration model  
- Outputs: corrected image key (optional), polyline, sample candidates, quality metrics  
- No Supabase service-role key in Flutter/Angular  
- Worker credentials only on server

## 9. Testing strategy (before any accuracy claim)

| Test | Required evidence |
|---|---|
| AuthZ isolation | User A cannot open station B case |
| Original immutability | API rejects overwrite/delete of original image |
| Decision non-mutation | Observation payload unchanged after decide |
| Poor image | Quality gate → outcome `rejected_poor_image` without false match |
| Reference charts | Owner-supplied set; human values vs machine MAE/RMSE reported |
| Engine versioning | Results store ruleSetVersion |

## 10. Implementation phases (after owner approval of design)

| EA phase | Deliverable | DB apply? |
|---|---|---|
| EA-0 | This design + permission names in matrix draft | No |
| EA-1 | Angular scaffold route + empty state + nav entry (feature-flagged) | No |
| EA-2 | Backend case CRUD in-memory or feature-flagged stubs + auth tests | No |
| EA-3 | Schema review package for owner | Review only |
| EA-4 | Image upload to secured storage + hash | After storage design approval |
| EA-5 | Worker extraction MVP | No accuracy claim |
| EA-6 | Compare against observation API | No |
| EA-7 | Engines with owner-provided rule packs | No |
| EA-8 | Acceptance on reference charts | Report metrics |

## 11. Integration with METRA roadmap

Listed in Master Plan §6 and §7. Blocks that depend on owner:
- Instrument catalogue & chart scales  
- Rule pack references  
- Storage bucket policy  
- Schema apply  

## 12. Honest status

| Item | State |
|---|---|
| Design document | This file |
| API | Not implemented |
| Angular/Flutter UI | Not implemented |
| OpenCV worker | Not implemented |
| SQL | Not written for apply |
| Accuracy | Not measured |

