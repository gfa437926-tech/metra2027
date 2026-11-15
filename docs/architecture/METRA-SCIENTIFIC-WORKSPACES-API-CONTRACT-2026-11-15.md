# METRA 2027 — Scientific Workspaces API Contract (proposal)

**Status:** API design proposal; no routes are exposed by this document.  
**Transport:** HTTPS JSON for control-plane operations; private object-storage transfer for large files; asynchronous jobs for OCR, chart digitization, homogenization and AI.  
**Authority:** .NET API authenticates the caller and evaluates authority/station/resource scope on every request. Actor IDs supplied by clients are ignored.

## 1. API conventions

- Prefix: `/api/v1`.
- IDs: UUID; timestamps: ISO-8601 UTC; station-local timestamps include `timezoneId` and the original local representation.
- Archive query bounds must carry an explicit UTC designator (`Z`); unspecified/local timestamps are rejected rather than interpreted using the API host timezone.
- All mutation requests accept `Idempotency-Key`; stale updates require `If-Match`/ETag or an explicit version.
- Error envelope: `code`, `message`, `traceId`, optional field errors. Never expose SQL, storage keys, stack traces or secrets.
- List endpoints use opaque cursor pagination; no unbounded result sets.
- Large operations return `202 Accepted` with a job ID and status URL.
- Files are uploaded to a quarantine flow using short-lived, single-purpose transfer authorization. The API never returns a permanent public object URL.
- Job status and result access are separately authorized; possession of a UUID is not authorization.
- Audit event creation is server-side and cannot be disabled by clients.

## 2. Recorder digitization

| Method & route | Purpose | Main authorization |
|---|---|---|
| POST `/recorder-captures` | Create a capture metadata record | station recorder.write |
| POST `/recorder-captures/{id}/upload-intents` | Issue a one-use quarantine upload intent | capture scoped write |
| POST `/recorder-captures/{id}/complete-upload` | Verify upload, hash and scan state | capture scoped write |
| GET `/recorder-captures/{id}` | Read capture metadata and processing state | station recorder.read |
| GET `/recorder-captures/{id}/assets` | List private asset metadata | capture scoped read |
| POST `/recorder-captures/{id}/digitization-jobs` | Queue OCR/trace extraction | recorder.digitize |
| GET `/digitization-jobs/{jobId}` | Poll job status | job owner or scoped reviewer |
| GET `/digitization-jobs/{jobId}/candidates` | Read candidate values and geometry | capture scoped review |
| POST `/extracted-values/{id}/decisions` | Accept/reject/correct candidate | recorder.review |

Upload-intent response contains an opaque transfer token, expiry, maximum size and required checksum header. It does not contain a durable public URL. The server verifies actual object size, content signature, SHA-256, scan result and decoded image properties before marking an asset reviewable.

## 3. Triple-source comparison

| Method & route | Purpose |
|---|---|
| POST `/source-comparisons` | Create comparison request for station/variable/time window |
| GET `/source-comparisons/{id}` | Read aligned sources and method metadata |
| GET `/source-comparisons/{id}/discrepancies` | List mismatches with tolerances |
| POST `/source-discrepancies/{id}/decisions` | Record reviewer resolution |

A comparison can include paper/mechanical trace values, manually transcribed values and electronic observations. Each displayed value must identify source ID, time, unit, quality flag, algorithm/version and review status. Missing sources remain missing; the service must not fabricate a third value.

## 4. CLIMATOL / climate homogenization

| Method & route | Purpose |
|---|---|
| GET `/climate-series` | List authorized station-variable series |
| POST `/homogeneity-runs` | Start a reproducible analysis job |
| GET `/homogeneity-runs/{id}` | Read run state, configuration and provenance |
| GET `/homogeneity-runs/{id}/breakpoints` | Read detected breakpoint candidates |
| POST `/breakpoints/{id}/decisions` | Accept/reject/defer a candidate |
| POST `/adjustment-versions` | Generate a new immutable adjusted-series version |
| POST `/adjustment-versions/{id}/approval` | Approve publication under dual-control policy |
| GET `/climate-products` | List authorized climate products |
| POST `/climate-products` | Generate a climate product from pinned inputs |

A run request pins target series, reference series, period, software image/version, method, parameters and input snapshot. A run cannot change the source series. Adjustment outputs are separate versions and require review. Publishing a climate product is a distinct permission from running analysis.

## 5. AI governance

| Method & route | Purpose |
|---|---|
| POST `/ai/datasets` | Define a dataset |
| POST `/ai/datasets/{id}/builds` | Build immutable sample snapshot |
| GET `/ai/dataset-builds/{id}` | Inspect split manifest and leakage report |
| POST `/ai/samples/{id}/annotations` | Create versioned annotation |
| POST `/ai/experiments` | Queue training against a pinned dataset build |
| GET `/ai/experiments/{id}` | Read progress, logs and metrics |
| GET `/ai/models` | List model versions |
| POST `/ai/models/{id}/evaluations` | Evaluate against a pinned holdout snapshot |
| POST `/ai/models/{id}/approval` | Approve or reject model release |
| POST `/ai/inference-jobs` | Queue inference for an approved model |
| GET `/ai/inference-jobs/{id}` | Read inference status and result reference |

Dataset build must produce a manifest with station/time split policy, sample hashes, exclusions and leakage checks. Training cannot use the test split. A model is not deployable based only on training metrics; it requires independent evaluation and approval. Inference output is a candidate and never auto-approves a meteorological observation.

## 6. Job state model

```text
queued -> validating -> running -> succeeded
                         |       -> failed
                         |       -> cancelled
```

- Every attempt has a distinct attempt number, worker image digest, start/end times and bounded log artifact.
- Retry creates a new attempt under the same logical job; completed attempt records remain immutable.
- Cancellation is cooperative and audited.
- A job status endpoint returns only safe metadata, not raw internal exception messages.
- Workers use least-privilege service identities and scoped, expiring input/output access.

## 7. Authorization matrix (minimum)

| Capability | Station observer | Station reviewer | Climate scientist | AI curator | Authority admin |
|---|---:|---:|---:|---:|---:|
| Read own station observations | Yes | Yes | Granted scope | Dataset scope | Granted scope |
| Create recorder capture | Yes | Yes | No by default | No | Granted scope |
| Review extracted values | No | Yes | No by default | No | Granted scope |
| Run homogenization | No | No | Yes | No | Granted scope |
| Approve adjusted climate series | No | No | Separate approver | No | Separate approver |
| Curate AI dataset | No | No | Scoped read | Yes | Granted scope |
| Train/evaluate model | No | No | No by default | Yes | Granted scope |
| Approve model release | No | No | No | Separate approver | Separate approver |

Role names are illustrative; final permission codes must be agreed in the identity/authorization design. Sensitive scientific approvals should use dual control where configured.

## 8. Required integration tests

1. Unauthenticated request returns 401.
2. User from authority A cannot read or mutate authority B resources.
3. Station assignment to A does not permit access to station B.
4. Expired/revoked memberships and grants deny access immediately.
5. Replayed idempotency key does not create duplicate captures/jobs/decisions.
6. Expired upload intent cannot be reused; a token cannot access another capture.
7. Forged MIME, mismatched signature, oversized content and checksum mismatch are rejected.
8. Quarantined or malware-positive assets cannot be previewed or digitized.
9. Candidate OCR/trace values never become approved observations without reviewer decision.
10. Comparison outputs preserve all source IDs and units.
11. Homogenization run pins immutable input snapshot and software/config version.
12. A breakpoint candidate alone cannot modify or publish the source series.
13. AI test samples cannot be used for training; station/time leakage is detected.
14. Unapproved model cannot run production inference.
15. Every decision and privileged read/write emits an immutable audit event.

## 9. Implementation boundary

This contract does not imply that any route, worker, storage provider, OCR engine, CLIMATOL executable, AI framework or deployment exists. The next code slice should implement DTOs and application-service interfaces against the approved domain model, then a disposable PostgreSQL integration test. Provider-specific storage, identity and compute adapters are selected only after deployment requirements and credentials are explicitly configured.

## Recorder digitization submission orchestration
The application service sequence is: validated authenticated subject → capture/asset/station-scope authorization → authoritative accepted-asset status read → pure enqueue policy → transactional outbox submission. Authorization is intentionally performed before asset-state lookup to avoid disclosing unrelated resource existence.

The outbox provider contract must atomically persist the idempotency claim and pending job/outbox message. It must compare a canonical fingerprint of the complete request for a repeated actor/key pair: an identical retry returns the existing job; a different payload returns an idempotency conflict. A separate dispatcher publishes committed outbox messages. A direct broker publish followed by a database write is not an acceptable implementation because it creates a dual-write loss/duplication window.

No provider, DI registration, endpoint, database migration or broker integration is included yet. The service is provider-neutral and tested with isolated test doubles; production activation remains blocked on the approved schema and durable provider implementation.

### Digitization request shape validation

The application service rejects empty capture and accepted-asset identifiers before invoking authorization or persistence dependencies. This is limited to syntactic identifier validation and does not query resource state; authorization still precedes all asset existence and lifecycle reads. Regression tests assert that malformed identifiers cause no authorizer, asset-reader or outbox calls.

### Recorder security audit event contract

Recorder security audit writes use an immutable `RecorderSecurityAuditEvent` containing the authenticated actor subject, asset, optional capture and job identifiers, a bounded correlation identifier, transition and safe reason code. The actor must come from validated server authentication context and must never be accepted from request-body data. Audit events must exclude image bytes, credentials, tokens and free-form user text. Provider implementations must reject empty actor/resource identifiers and unsafe or unbounded metadata, append records only, and persist audit evidence atomically with the related state transition whenever both are committed in the same datastore transaction. No audit provider or database schema is activated by this contract-only change.

### Recorder upload filename normalization boundary

The provider-neutral upload validator accepts only a safe ASCII leaf filename composed of letters, digits, dot, underscore and hyphen, within the existing length bound. It rejects path separators, control characters, whitespace, and non-ASCII/confusable characters before extension/media-type checks. Storage adapters should generate opaque object keys and must not use the submitted filename as a storage path or public object identifier.

### Canonical digitization request fingerprint

Outbox adapters can use `RecordDigitizationRequestFingerprint.TryCompute` to derive a deterministic lowercase SHA-256 digest from the canonical capture ID, accepted asset ID and validated algorithm profile. The idempotency key and actor are not included in the payload digest; they scope the idempotency claim separately. Reusing the same actor/key with a different fingerprint must return an idempotency conflict, while the same fingerprint must replay the existing job. This helper performs no persistence and does not replace the required atomic transaction in the outbox provider.

### Outbox fingerprint handoff

The application service now computes the canonical request fingerprint after actor/resource authorization and accepted-state validation, then passes it explicitly to `IRecorderDigitizationOutbox.TryCreateAsync`. A durable provider must independently verify that the supplied digest matches the canonical submission payload, then persist and compare it atomically with the actor-scoped idempotency-key claim and job/outbox insertion. The service does not treat a locally computed digest as proof of persistence or uniqueness; those guarantees belong to the provider transaction.


## Scanner identity canonicalization hardening

- Scanner name and version are bounded to 100 characters and restricted to canonical ASCII tokens: letters, digits, dot, underscore, colon and hyphen.
- Whitespace, path separators, Unicode lookalikes and control characters remain quarantined rather than being accepted as scanner provenance.
- This is input-shape validation only; it does not authenticate a scanner binary or replace a trusted scanner deployment/attestation mechanism.


### Scanner reason-code validation

Optional scanner reason codes are treated as untrusted metadata. If present, they must use the same bounded canonical ASCII token grammar as scanner identity fields; invalid values keep the asset quarantined. The reason code is not used as a free-form log message. This check does not establish scanner trust or malware verdict authenticity.

### Mandatory evidence gate for asset acceptance transitions

- The application now exposes `RecordImageAssetTransitionPolicy`, which combines the lifecycle transition check with `RecordImageAcceptancePolicy` whenever a caller requests `Scanning -> Accepted`.
- The acceptance transition is rejected unless the scanner verdict is explicitly `Clean`, scanner identity and optional reason metadata are canonical, and the integrity evidence confirms SHA-256, content signature, dimensions and a positive bounded byte length.
- Missing evidence, unknown verdicts, threats and invalid scanner metadata cannot be converted into an accepted transition by supplying the requested target state alone.
- Other legal lifecycle transitions continue to use the lifecycle rules without requiring scan evidence; invalid and terminal transitions remain rejected.
- Persistence adapters must use this combined policy before committing acceptance. This is a pure application contract and test coverage only: it does not create a storage/scanner provider, authenticate scanner binaries, persist state, or register runtime endpoints.

### Independent integrity-gate regression coverage

- Extended acceptance-policy tests so SHA-256 verification, content-signature verification and dimension-policy verification each fail independently when absent.
- Added a regression case for an unknown asset-state enum value paired with otherwise valid scanner and integrity evidence.
- These tests protect the fail-closed policy contract; they do not replace provider integration tests or a real scanner/storage security assessment.

### Quarantine storage adapter result validation

- Added `QuarantinedRecorderObjectPolicy` as a mandatory application-boundary check for metadata returned by a quarantine-storage adapter.
- It verifies the returned asset ID matches the requested asset, the stored length is positive and no greater than the 20 MiB limit, the SHA-256 is exactly 64 lowercase hexadecimal characters, and the detected media type is one of JPEG, PNG or TIFF.
- Added tests for missing/mismatched IDs, missing adapter results, invalid and oversized lengths, the exact maximum-size boundary, malformed/noncanonical hashes and unsupported/noncanonical media types.
- This validates adapter-reported metadata only. The adapter must still calculate the digest from stored bytes, independently detect the media type, and enforce private quarantine semantics; this policy does not itself write, read, scan or promote files.

### Bounded streaming intake primitive

- Added `RecordImageBoundedStreamReader` to consume non-seekable upload streams without trusting a declared content length or buffering beyond the configured maximum plus one detection byte.
- It rejects unreadable streams, invalid limits, empty content and any stream exceeding the configured limit; oversized results never return partial bytes as accepted content.
- Cancellation is propagated to the underlying asynchronous read. Tests cover non-seekable streams, exact-limit input, one-byte overflow, empty/unreadable streams, invalid limits and cancellation.
- This primitive only performs bounded in-memory intake. It is not an HTTP upload endpoint, malware scanner, durable quarantine store or authorization boundary; callers must pass the resulting bytes through the existing signature, filename and digest validator before storage.


### Authorized recorder image quarantine intake orchestration

- Added `RecorderImageUploadIntakeService` to define the application-level order for an upload: server-derived actor → capture/asset/station-scope authorization → authoritative asset-state lookup → bounded stream read → filename/signature/MIME/SHA-256 validation → private quarantine write → adapter-result and stored-digest verification → conditional state update with append-only audit event.
- Authorization is evaluated before reading asset state, preventing unauthorized callers from probing asset existence or lifecycle.
- Only `AwaitingUpload → UploadedQuarantined` can be recorded by the intake store. The store contract requires the expected-state compare-and-set and audit insert to be atomic.
- If storage metadata or digest verification fails, or the state compare-and-set loses a race, the service requests deletion of the just-written quarantined object. Expiry cleanup remains a separate lifecycle operation.
- Added an explicit `DeleteQuarantinedAsync` rollback port distinct from scheduled expired-object cleanup.
- Intake also requires the stored byte length to equal the exact bounded input length and the storage-detected media type to equal the independently validated signature-derived type; mismatch paths trigger quarantine rollback. Regression tests cover length, digest and media-type mismatches.
- Added service tests for authorization ordering, successful quarantine handoff with audit attribution, stored-digest mismatch cleanup and lifecycle compare-and-set conflict cleanup.
- Runtime boundary: this service is not registered in dependency injection and has no HTTP endpoint, storage adapter, scanner, database provider or deployment configuration. Provider implementations must enforce private storage, bounded I/O/timeouts, atomic state+audit persistence, cleanup retries and expiry handling before production activation.

- Added preflight regression coverage proving a missing authenticated actor is rejected without invoking any dependency, invalid correlation metadata is rejected before authorization, and an asset outside `AwaitingUpload` is rejected before reading the request stream or writing to quarantine.
- Storage-provider contract clarification: implementations must stage writes privately and atomically (no partially written object may be visible to readers/workers); the adapter must enforce byte limits while streaming and verify the digest of bytes actually persisted. A failure after an ambiguous database commit must be reconciled by asset ID/state and must not blindly delete an object that may already be referenced by a committed row.

- The upload state-store commit result is explicit: `Committed`, `StateConflict`, or `OutcomeUnknown`. Quarantine rollback is allowed only after a confirmed state conflict or a failed pre-commit storage-integrity check. On an unknown commit outcome, the object remains private and is reconciled against durable asset state; it must not be deleted speculatively.
- Provider implementations must distinguish a confirmed compare-and-set miss from transport/transaction ambiguity. Exceptions or timeouts after commit submission must not be translated into a definite conflict.

- Each intake invocation generates a server-side `uploadAttemptId`. Quarantine storage writes, returned object metadata, validation and rollback are bound to both `assetId` and this attempt ID. The storage adapter must use an immutable attempt-scoped object key; it must never overwrite another concurrent upload attempt for the same asset.
- Rollback deletes only the exact attempt object, never every quarantined object associated with the asset. The persisted asset record must retain the committed attempt/object reference so retries and reconciliation cannot confuse concurrent uploads.
- Tests reject storage metadata carrying a different attempt ID and assert rollback is scoped to a non-empty attempt identifier.

- The attempt identifier is required for every object-specific quarantine operation, including write, open/read, promotion and rollback deletion. Asset-level expiry cleanup is a separate enumerated lifecycle operation and must not be callable as an ordinary upload rollback.
