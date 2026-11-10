# Electronic Auditor — Contract Readiness and Owner Decision Register

**Owner:** METRA 2027 Assistant 05 — Electronic Auditor  
**Status:** Draft for architecture/owner review; not an approved API contract  
**Updated (UTC):** 2026-11-10T23:34:37.134Z  
**Implementation branch:** `work/electronic-auditor-audit`  
**Source evidence branch:** `work/legacy-ui-migration-audit`  
**Safety:** Documentation only. No schema, migration, storage bucket, application source, or raw observation changed.

## 1. Purpose

Prepare a safe boundary for a future implementation of paper-register and mechanical-recorder auditing. This document intentionally records unresolved decisions rather than selecting an unapproved route, permission namespace, data schema, storage policy, or scientific rule.

The system has two extraction tracks and an optional triple-source comparison:

- Official paper register pages → field/value candidates with image regions.
- Mechanical charts → calibrated time-series candidates with chart loci.
- Electronic METRA observations → authorized read-only comparison source.

Extraction can work offline. Matching against electronic METRA observations requires authorized online access. All AI output remains a candidate until reviewed by an authorized human.

## 2. Evidence baseline

- Angular route `/electronic-auditor` exists behind `requireAuthenticatedUser`, but the workspace is a static scaffold with no upload, OCR, curve extraction, API binding, or review workflow.
- The inspected API composition root has no auditor service registration or endpoint mapping.
- The formal AI specification is marked for owner review and explicitly says production OCR/curve accuracy is not established.
- Backend project targets .NET 10. Its test project uses xUnit and ASP.NET MVC Testing.
- Backend CI builds/tests the API and runs authorization contract checks plus disposable PostgreSQL isolation tests.
- Angular CI/test script currently has TypeScript and three Node contract test commands; no auditor-specific test command is declared.

See `ELECTRONIC-RECORD-AUDITOR-AUDIT.md` for file-level evidence and source SHAs.

## 3. Canonical-contract decisions — unresolved

| Decision | Existing alternatives/evidence | Required authority |
|---|---|---|
| API prefix | `/api/v1/stations/{stationId}/electronic-audits` in mechanical design vs `/api/v1/stations/{stationId}/intelligent-audits` in broader spec | Owner / API architecture |
| Permission namespace | `electronic_auditor.*` vs `intelligent_audit.*` | Security / authorization owner |
| Scope | Mechanical-only module vs paper + mechanical + training laboratory | Product owner |
| Logical entity naming | `ElectronicAuditCase` / `electronic_audit_*` vs `intelligent_audit_*` | Data architecture owner |
| Client scope | Angular primary; Flutter capture/read-only case review is optional | Product owner |
| Instrument and register catalogues | Types listed, but exact models, units, scales, periods and calibration references are TBD | Meteorological/instrument owner |

No namespace is selected by this draft. No permission is considered granted merely because it appears in a design document.

## 4. Proposed logical workflow boundary

1. Create a station-scoped case with track and UTC period.
2. Authorize station and operation before any storage access.
3. Accept original image bytes under an owner-approved upload policy; calculate SHA-256 server-side.
4. Preserve the original as immutable; derived images are separate artifacts.
5. Run quality/classification/extraction as a versioned job; keep OCR/curve candidates separate from human-reviewed values.
6. For paper pages, retain field code, extracted text/value, unit as observed, bounding box, confidence, and model/version.
7. For charts, require a documented instrument profile and calibration reference before mapping pixels to time/value coordinates.
8. Record human overrides as new events/versions, never as silent edits to machine output.
9. Fetch electronic observations through an existing authorized read path only after station permission succeeds.
10. Compare source pairs with explicit element mapping, unit, time alignment, tolerance/rule-set version, missing-data policy, and uncertainty.
11. Run only owner-approved scientific rule packs; report findings rather than deciding.
12. Record final decision by an authorized human and append an immutable event.
13. Produce a report that links each finding to original/derived evidence and processing versions.

## 5. Minimum logical request/response fields to consider

These are field candidates for review, not committed DTOs or a JSON schema.

### Case identity
- case id
- station id
- track: paper | mechanical | combined (subject to owner decision)
- UTC period start/end
- instrument/profile reference when mechanical
- register template reference when paper
- created by / created at UTC
- lifecycle status and version

### Image artifact
- artifact id and case id
- role: original | derived
- content SHA-256, content type, byte length, pixel dimensions
- private storage reference (never a public URL)
- uploaded by / uploaded at UTC
- derivation parent id and processing version for derived images
- quality flags

### Extraction candidate
- extraction id and source artifact id
- extractor/model name and immutable version
- source kind: machine | human_override
- observed element code and raw recognized text
- parsed numeric value only when parseable
- observed unit string; normalized unit only with an approved mapping
- UTC observation instant or interval, if supported by the source
- confidence and review state
- bounding box for paper fields or curve locus for chart samples
- calibration id/version for chart-derived values

### Comparison
- comparison id and case id
- source artifact/extraction identifiers for each side
- electronic observation identifier(s), loaded read-only
- element mapping and temporal alignment policy version
- source values and units as stored/observed
- computed delta only when units and time alignment are compatible
- uncertainty, missing-data flags, and rule-set version

### Decision and event
- decision id, case id, outcome, notes
- deciding actor id and UTC timestamp
- decision version
- append-only event id, actor, action, UTC timestamp, prior/new artifact references
- explicit non-mutation evidence for original electronic observation payload

## 6. Security and integrity gates

- Fail closed for unknown user, station, permission, case ownership, or storage authorization.
- Check station permission before storage read/write and before retrieving electronic observations.
- Do not expose service-role keys, object-store credentials, or worker credentials to Angular/Flutter.
- Enforce upload size/type/pixel/page limits after the owner/security policy supplies values.
- Validate file content, not just filename or client MIME type.
- Treat decompression bombs, malformed images, polyglot files, and unsupported formats as rejected inputs.
- Original bytes and their hash must be immutable to application roles; derived images are separate records.
- Every processing action records actor/service, version, input artifact hash, output artifact hash, and UTC time.
- AI confidence is not authorization and does not replace human approval.
- Decision and extraction must never update/delete raw observation payloads.
- Training datasets may contain only human-approved labels with provenance; test sets must remain isolated from training.

## 7. Test and acceptance gates

| Area | Minimum test evidence |
|---|---|
| Station isolation | Cross-station case/image access returns forbidden before storage access |
| Authentication | Missing/invalid identity cannot create, upload, extract, compare, decide, or read report |
| Upload security | Spoofed MIME, unsupported type, oversized bytes/pixels/pages, corrupt image and decompression bomb rejected |
| Original integrity | Original bytes/hash unchanged after correction, extraction, human override and decision |
| Provenance | Every candidate points to source artifact, extractor version, calibration/model and UTC event |
| Paper extraction | Human-labeled reference pages; field-level accuracy and bbox localization measured on held-out set |
| Chart extraction | Owner-calibrated reference charts; time alignment error and value error measured by instrument family |
| Unit/time safety | Incompatible units, unknown calibration and ambiguous time alignment produce inconclusive/review-needed result |
| Comparison | Missing values and incomplete intervals are explicit; no invented values or silent coercion |
| Decision non-mutation | Observation payload hash/value is unchanged after every audit decision |
| Audit log | Event append-only; actor, action and timestamp cannot be rewritten by ordinary app roles |
| Model governance | No unreviewed production output enters training; promotion/rollback requires designated approval |
| Regression | API test suite, station-isolation contracts, Angular component tests and worker tests run in CI |

Accuracy thresholds must be set only after owner-supplied independent reference sets and scientific tolerances are available.

## 8. Required owner inputs before implementation

1. Approve one canonical API prefix and permission namespace.
2. Confirm whether the broad intelligent-audit specification supersedes or extends the mechanical-only design.
3. Supply official paper register templates, element codes and field/time semantics.
4. Supply instrument catalogue: manufacturer/model, chart period, axes, units, scale, calibration reference and SOP version.
5. Approve private object storage, retention, encryption, malware scanning, size/type limits and immutable-original controls.
6. Define electronic observation read policy and station-scope permissions.
7. Supply approved physical/mathematical rule references and time-alignment tolerances.
8. Supply de-identified reference images and human-verified labels for test/validation/held-out sets.
9. Name authorized roles for upload, audit, decision, model management and model promotion.
10. Approve any future database schema package before migrations are applied.

## 9. Explicit non-actions

This document does not authorize:
- Supabase/database changes, SQL, migrations, RLS or storage bucket creation.
- Access to or modification of `metra-old` or legacy databases.
- Modification of raw observation values.
- OCR/CV claims, scientific thresholds, model training or production deployment.
- Changes to Angular/Flutter/Backend implementation owned by other assistants.
- Merge to `main`.

## 10. Next safe implementation sequence after decisions

1. Freeze canonical contracts and permission matrix.
2. Add pure domain types and deterministic validators with synthetic fixtures only.
3. Add authorization and lifecycle tests before any persistence.
4. Add upload metadata/hash handling behind an approved private storage adapter.
5. Add paper manual-entry MVP before automated OCR.
6. Add mechanical manual calibration before semi-automatic curve extraction.
7. Add human-reviewed extraction and comparison.
8. Add worker inference and training only after reference-data governance is ready.
9. Report held-out metrics; do not claim accuracy before acceptance.
