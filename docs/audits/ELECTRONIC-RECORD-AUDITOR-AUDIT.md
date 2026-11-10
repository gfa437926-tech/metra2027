# Electronic Paper-Record Auditor — Repository Audit and Safe Design

**Status:** Documentation-only audit baseline; implementation status is not yet verified.
**Scope:** Paper-register images, electronic observations, and mechanical recorder charts.
**Safety boundary:** This document does not authorize database, raw-observation, Angular, Flutter, or Backend changes.

## 1. Audit execution and evidence

The repository README was inspected on `main`. It describes three independently runnable applications (Angular 20, Flutter, ASP.NET Core 10) and an existing secured observation submission/review workflow. It also warns that production integration is incomplete and that the legacy database must remain unchanged.

The requested coordination and module documents could not be found on the inspected refs:
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `واجهات/09-المدقق-الإلكتروني.md`
- `واجهات/README.md`
- `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`

The repository code-search index reports unavailable/not indexed, and the GitHub file API returned 404 for these paths on `main` and the inspected work/integration refs. Consequently, this pass cannot truthfully claim a complete source-tree audit or assert that no auditor implementation exists elsewhere. No source implementation was changed.

### Verified / unverified inventory

| Area | Evidence in this pass | Finding |
|---|---|---|
| Web/mobile/API applications | Root README | Present as independent applications |
| Observation submission and review | Root README | API workflow described; this is not evidence of paper-auditor support |
| Paper image upload/original preservation | No accessible module specification or source evidence | Unverified |
| OCR / computer vision pipeline | No accessible source evidence | Unverified |
| Mechanical chart digitization | No accessible source evidence | Unverified |
| Human comparison and approval UI | General API review endpoints only in README | Paper-specific workflow unverified |
| Immutable audit trail / model provenance | No accessible source evidence | Unverified |
| Requested coordination files | GitHub 404 on inspected refs | Missing from inspected refs |

## 2. Proposed end-to-end audit lifecycle

1. **Create an audit case** linked to station, instrument, observation period, report type, and authorized reviewer. Use stable identifiers; do not infer station metadata.
2. **Receive source material**: upload each page/chart as an immutable original object. Preserve original bytes, filename, media type, byte length, uploader, upload timestamp, and cryptographic checksum (for example SHA-256). Store derivatives separately.
3. **Validate the source**: check file signature, size limits, malware status, image dimensions, page orientation, blur, glare, clipping, folds, and missing pages. Never overwrite the original during rotation, deskew, denoise, or contrast enhancement.
4. **Register the source context**: identify register type, station/instrument, page number, date/time basis, units, scale, instrument identity, calibration record/version, and provenance. Unknown values remain explicitly unknown.
5. **Extract candidate values**: OCR for printed/handwritten text and CV for tables, grid lines, plotted traces, axes, ticks, and chart annotations. Every candidate must retain source-page coordinates/bounding region, extraction method, model/version, confidence, and any preprocessing lineage.
6. **Normalize only with explicit metadata**: map extracted fields to a versioned field dictionary. Do not assume units, scales, time basis, or missing ticks. Preserve both literal transcription and normalized candidate value.
7. **Compare without mutation**: read electronic observations and compare by station, observation time, field, unit, and applicable versioned rules. Keep the comparison result in the audit domain; never update, replace, or “correct” raw observations.
8. **Classify differences**: exact match, within an explicitly approved tolerance, mismatch, missing on paper, missing electronically, ambiguous reading, image insufficient, metadata conflict, or not comparable.
9. **Human review**: present the original image and extracted overlay side-by-side with electronic value, difference, source coordinates, confidence, and provenance. A qualified reviewer can accept extraction, edit the candidate with a reason, mark unreadable, request a rescan, or escalate. The system records before/after candidate values and reviewer identity.
10. **Independent decision**: an authorized approver confirms match, confirms discrepancy, or rejects/returns the case. Extraction operator and approver roles should be separated where policy requires it. No model may approve a case.
11. **Seal the case**: append decision, evidence references, timestamps, reviewer/approver identities, rule/model versions, and source checksums. Corrections create new events/versions; never erase prior decisions.
12. **Export/report**: produce a traceable audit report with links to immutable originals, extracted candidates, comparison, review history, and final human decision.

## 3. Original-image retention and security

- Originals are write-once from the application perspective; no destructive image processing.
- Store originals and derivatives in separate object keys/collections with explicit relation and checksum.
- Encrypt in transit and at rest; enforce least-privilege station and role scopes.
- Use short-lived authorized access to image objects; avoid public buckets and permanent public URLs.
- Record upload/download/access events where required by policy.
- Apply file type allowlists, size/page limits, malware scanning, and safe image decoding.
- Define retention, legal hold, backup, restore, and deletion policy before production rollout.
- Do not put secrets, raw images, or sensitive operational records into Git.

## 4. OCR and computer-vision extraction

### Paper registers
- Detect page boundary, orientation, skew, table regions, row/column boundaries, labels, and cell regions.
- Run language/script-aware OCR for printed and handwritten content; handwriting should be treated as a higher-risk candidate.
- Retain raw OCR text, alternatives where available, confidence, polygon/bounding box, engine/model identifier, model version, configuration, and preprocessing steps.
- Apply field-specific parsing only after the form layout and field dictionary are approved.
- Low confidence, conflicting OCR alternatives, merged cells, overwritten entries, and out-of-layout text must route to human review.

### Mechanical recorder charts
Supported instrument families: Thermograph, Hygrograph, Barograph, and Pluviograph.

A safe chart pipeline must:
1. preserve the original chart image and capture instrument identity, chart type, chart paper/template identifier, deployment interval, and calibration metadata;
2. detect chart boundary, axes, grid, time marks, scale marks, trace, pen artifacts, and annotations;
3. associate each axis with a documented unit, direction, range, and calibration version;
4. extract trace coordinates as pixels first, retaining image coordinate system and uncertainty;
5. map pixels to physical values only from verified chart geometry and calibration metadata;
6. retain trace-to-value transform parameters, calibration source, scale/tick detections, model/version, confidence, and uncertainty;
7. flag discontinuities, trace overlap, ink fading, paper distortion, missing grid/ticks, saturation, and ambiguous pen traces;
8. keep digitized values as candidates until a qualified reviewer confirms them.

No default graduation, unit, scale, calibration constant, or scientific threshold is supplied by this design. These must come from approved instrument/chart documentation.

## 5. Comparison model

A comparison key should include station identity, instrument/source identity where applicable, observation timestamp and time standard, field identifier, and unit. Comparison rules must be versioned and approved by the meteorological domain owner.

Each comparison item should retain:
- electronic observation identifier and immutable raw value reference;
- paper source identifier, page, region, and literal transcription;
- candidate normalized value and unit (nullable until verified);
- extraction source, model/version, confidence, and transform/calibration reference;
- comparison rule/version and calculated difference (only when valid);
- classification and reason;
- human review and approval events.

Do not compare values when time basis, station identity, field mapping, unit, or calibration is unresolved. Do not silently convert missing or unknown values.

## 6. Human review and audit log

The audit log is append-only and event-oriented. Suggested event types:
`CaseCreated`, `SourceUploaded`, `SourceValidated`, `ExtractionStarted`, `CandidateExtracted`, `CandidateCorrected`, `ComparisonCalculated`, `ReviewRequested`, `ReviewCompleted`, `DecisionApproved`, `DecisionRejected`, `RescanRequested`, `CaseClosed`.

Each event should carry actor/service identity, UTC timestamp, case/source/candidate IDs, event schema version, correlation ID, and references to prior/new versions. Never store only the final edited value; retain the original extraction and the full change history.

## 7. Minimum test matrix

| Scenario | Expected system behavior |
|---|---|
| Clear printed page | Candidate extraction with page/region provenance; human confirmation still required |
| Legible handwriting | Candidate plus confidence; reviewer confirms |
| Ambiguous digit (e.g. 3/8) | Ambiguous classification; no automatic selection |
| Blurred / low-resolution image | Quality failure or low-confidence review; request rescan |
| Glare, shadow, fold, stain | Flag affected region; preserve original |
| Cropped page / missing page | Incomplete-source status; do not mark case complete |
| Rotated or skewed scan | Process derivative; original checksum remains unchanged |
| Duplicate upload | Detect checksum duplicate; retain explicit duplicate relation |
| Corrupt or unsupported file | Reject safely with reason; no partial case approval |
| OCR value differs from electronic observation | Mismatch candidate; reviewer/approver decision required |
| Paper value missing | Missing-on-paper classification |
| Electronic value missing | Missing-electronic classification; do not synthesize observation |
| Unit or time basis unknown | Not comparable; request metadata |
| Different station or timestamp | Block comparison and flag identity conflict |
| OCR engine/model version changes | Preserve prior extraction; new version creates a new candidate run |
| Thermograph trace overlaps grid | Preserve pixel trace and uncertainty; route to human review |
| Hygrograph chart lacks verified scale | Do not convert pixels to humidity values |
| Barograph chart has unknown pressure scale | Do not infer pressure units or graduations |
| Pluviograph trace has missing time marks | Do not infer accumulation/rate without approved chart metadata |
| Calibration record absent/expired | Mark calibration unresolved; no accepted physical values |
| Reviewer edits extracted value | Record old/new candidate, reason, actor, timestamp |
| Unauthorized reviewer/approver | Deny action and record security event |
| Reviewer attempts raw observation edit | Deny; raw observation remains unchanged |
| Approval attempted before review | Reject transition |
| Audit event altered/deleted | Integrity test must fail or tampering be detectable |
| Reprocessing same source | New extraction run; original and prior run remain accessible |

## 8. Acceptance criteria before implementation

- A complete repository inventory and approved requirements document are available.
- Product owner approves supported register layouts, languages/scripts, field dictionary, units, time standard, and instrument chart templates.
- Meteorological authority approves comparison tolerances and chart calibration sources.
- Security owner approves storage, access, retention, encryption, and audit-event policy.
- Data owner approves read-only access to raw electronic observations.
- Human roles, separation of duties, escalation, and sign-off rules are defined.
- Test corpus contains representative clear, degraded, handwritten, and mechanical-chart examples with expert-verified ground truth.
- OCR/CV evaluation reports include field-level accuracy, false-match rate, unreadable rate, and uncertainty; no model is treated as an approver.

## 9. Next safe implementation slice

After source-tree access and requirements review, implement an isolated, database-independent domain package and test fixtures for:
- immutable source metadata and checksum contract;
- extraction-run and candidate-value contracts;
- comparison classifications;
- append-only review/approval event contracts;
- tests proving no raw observation mutation.

Do not add migrations, database tables, API endpoints, Angular/Flutter screens, or production OCR dependencies until the Backend owner and product/security owners agree on contracts and ownership.


## 10. Follow-up source inspection — 2026-11-10T23:32:37.175Z (UTC)

A second pass located the authoritative auditor requirements on the separate documentation branch `docs/metra-all-ui-specification`, rather than on the previously inspected refs. This corrects the earlier limitation: the documents are available on that branch, but are not necessarily merged into the implementation branch.

### Requirements and coordination evidence

- `واجهات/مهما.md` — fetched from `docs/metra-all-ui-specification`; defines UI-IMPL-001 as the global next task and lists UI-IMPL-008 (electronic auditor) and UI-IMPL-009 (mechanical charts) as not yet implemented. It requires UTC, no old DB, no schema changes without approval, no raw observation mutation, and no merge/deploy without approval.
- `واجهات/تغيير.md` and `واجهات/README.md` — fetched from the same branch; they define append-only reporting and distinguish specifications from verified implementation.
- `واجهات/09-المدقق-الإلكتروني.md` — fetched; specifies paper register upload, SHA-256, quality checks, OCR as unapproved suggestion, mechanical chart support, human decision, provenance, role separation, and no raw payload mutation.
- `docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md` — fetched from the same branch (blob SHA `423f3c46f73df649b776862e636d86e63aa32594`); explicitly says owner review/specification only, not production capability. It defines paper and mechanical tracks, triple-source comparison, human-approved training labels, authorization, logical entities (no migration), and IA-0 through IA-10 phases.
- `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md` — fetched from the same branch; confirms application boundaries and the need to inspect the actual source branch before implementation.

### Source-level findings on `work/legacy-ui-migration-audit`

- `angular-app/src/app/app.routes.ts` (blob SHA `80c4a288c8fb799e1604e4ce958a9819f8133039`) registers `/electronic-auditor` behind `requireAuthenticatedUser` and lazy-loads `ElectronicAuditorWorkspaceComponent`. This corrects the stale master-plan row that described the route as missing.
- `angular-app/src/app/features/electronic-auditor/electronic-auditor-workspace.component.ts` (blob SHA `cc97ba225699fbf4c99fe758b8ffb5426da81508`) is a standalone inline-template scaffold. It explicitly states there is no chart OCR or API binding; all six workflow areas are marked unavailable. No separate HTML or component spec file was found at the expected sibling paths.
- `backend/Metra.Api/Program.cs` (blob SHA `59f50db0ff791f6e1e3e3474543046695639625f`) registers existing services and maps existing endpoint groups, but contains no electronic-auditor service registration or auditor endpoint mapping. The master implementation plan also records the auditor API/worker as not started.
- `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md` (blob SHA `c44b5bb5dd60aa74c7b1cf53c3b4e739fd60500b`) is a design note only; it explicitly states API, UI functionality, OpenCV worker, SQL, and measured accuracy are not implemented.
- `docs/delivery/METRA-2027-FINAL-IMPLEMENTATION-MASTER-PLAN.md` (blob SHA `8401af9262e11a91f349d80fe21f4989ccc6002f`) records the auditor module as not started and lists the workflow as planned. Its route inventory is stale relative to the inspected `app.routes.ts`; the actual route is present but points to a scaffold.

### Revised verified inventory

| Area | Current evidence-based finding |
|---|---|
| Requirements | Formal UI and AI auditor specifications exist on the documentation branch; owner review remains required |
| Angular route | Present and authenticated-guarded |
| Angular workspace | Scaffold only; no upload/extraction/API/review behavior |
| Backend auditor endpoints/services | Not found in inspected API composition root; master plan says not started |
| OCR / CV worker and training lab | Not implemented per formal specification and design status |
| Mechanical chart calibration/digitization | Design only; no implementation evidence |
| Persistence/schema | Logical design only; no migration applied or authorized |
| Human decision and immutable event workflow | Required by specification; no implementation evidence |

This is now a source-backed module-level inventory, not a claim that every repository directory or every possible branch has been exhaustively searched. No implementation files were changed.


## 11. Follow-up implementation-boundary and CI inventory — 2026-11-10T23:34:37.134Z (UTC)

### Backend and test pipeline evidence

Inspected on `work/legacy-ui-migration-audit`:

- `backend/Metra.Api/Metra.Api.csproj` (SHA `0bd4baeabab746f890bbad64305ef091058dd2e3`): ASP.NET Core Web SDK, `net10.0`, nullable/implicit usings; references ASP.NET OpenAPI 10.0.0, JWT bearer 10.0.0, Microsoft.OpenApi 2.7.5 (pinned security advisory fix), and Npgsql 9.0.3. No image-processing package is declared in this project file.
- `backend/Metra.Api.Tests/Metra.Api.Tests.csproj` (SHA `b3865614f5829ba1753f4a5884383dd670984242`): `net10.0`, xUnit 2.9.3, Microsoft.NET.Test.Sdk 17.14.1, ASP.NET MVC Testing 10.0.0; references the API project.
- `.github/workflows/backend-ci.yml` (SHA `8bcf0e73bfe59b91557ee90d52d3b9b75bdab952`): runs disposable PostgreSQL isolation tests, .NET restore with high/critical NuGet advisory warnings treated as errors, authorization SQL contract scripts, API build, `dotnet test`, Docker build, and container liveness/readiness checks. Its PostgreSQL job uses a disposable CI service, not the user's Supabase project.
- `angular-app/package.json` (SHA `bca051e8722a14bc30494f9179ce38fb5250426f`): Angular 20; current test script runs TypeScript tests and three Node contract test files. No auditor-specific test command is declared.
- The expected test project file exists. Several guessed auditor/general test filenames were not found at the guessed paths; this does not prove the test directory has no tests. Exact test-source inventory remains open.

### Contract conflicts that block implementation

The two formal design documents use different API and permission namespaces:

| Source | API prefix | Permission namespace |
|---|---|---|
| `docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md` | `/api/v1/stations/{stationId}/electronic-audits` | `electronic_auditor.*` |
| `docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md` | `/api/v1/stations/{stationId}/intelligent-audits` | `intelligent_audit.*` |

They also use different logical naming conventions (`ElectronicAuditCase` / `electronic_audit_*` versus `intelligent_audit_*`). Both label these as proposed/logical and not wired. No API route or permission has been implemented for the auditor in the inspected API composition root. Do not implement either namespace until the owner/architecture authority selects one canonical contract and confirms the relationship between the mechanical-only design and the broader paper + mechanical + training program.

### Proposed contract gates (documentation only)

Before API/worker code is written, require explicit decisions for:

1. Canonical route prefix, permission namespace, case identifier, and track enum.
2. Whether the older mechanical-chart design is superseded by the broader intelligent-audit specification, or remains a compatible subset.
3. Upload policy: accepted MIME types, maximum bytes/pixels/pages, decompression limits, content sniffing, malware scanning, retention, private object-store location, and immutable-original enforcement. These values must be set by the owner/security policy, not invented here.
4. Storage authorization ordering: station permission must be checked before any object-store read/write; clients receive no service-role or worker credentials.
5. Extraction provenance contract: original artifact id + SHA-256, derived artifact id, extractor/model version, calibration reference/version, per-reading confidence, source (machine/human override), bounding box or curve locus, and UTC timestamps.
6. Comparison contract: explicit source identifiers, element mapping, time alignment policy, units, tolerance/rule-set version, missing-data handling, and uncertainty; no silent unit conversion.
7. Decision contract: authorized human actor, outcome, note, timestamp, immutable event, and an explicit invariant that observation payload is unchanged.
8. Test fixture policy: owner-provided de-identified register pages and chart images, human reference labels, train/validation/test isolation, and held-out station/device evaluation.

This is a readiness checklist, not a finalized API contract or permission grant. No DB schema, migration, storage bucket, OCR worker, or application source was changed.
