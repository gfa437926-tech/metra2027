# METRA recorder image quarantine lifecycle

## Purpose

Define a provider-neutral security state contract for paper and mechanical recorder images. This is a lifecycle model only; it does not implement upload endpoints, object storage, malware scanning, OCR, chart digitization, persistence, or user authorization.

## States

| State | Meaning | May be served as evidence? |
|---|---|---:|
| `AwaitingUpload` | An authorized upload intent exists; bytes are not yet accepted | No |
| `UploadedQuarantined` | Bytes arrived in an isolated quarantine area and await inspection | No |
| `Scanning` | Integrity and security inspection is running | No |
| `Accepted` | All required checks passed; immutable evidence may be made available under authorization | Yes |
| `Rejected` | Security, integrity, or policy checks failed | No |
| `Expired` | The upload intent expired before completion | No |
| `Cancelled` | The upload intent was cancelled | No |

## Allowed transitions

```text
AwaitingUpload -> UploadedQuarantined
AwaitingUpload -> Expired | Cancelled
UploadedQuarantined -> Scanning
UploadedQuarantined -> Expired | Cancelled
Scanning -> Accepted | Rejected
```

Terminal states are immutable. A replacement upload must create a new asset/intent rather than reopen a terminal record. Skipped transitions are rejected.

## Security invariants

1. Quarantined and scanning objects must not be exposed through normal download or preview paths.
2. Acceptance requires server-side authorization, size/type/signature validation, checksum verification, malware/content inspection, and policy checks.
3. Client-provided actor, authority, storage key, object URL, scan result, and acceptance decision are never trusted.
4. Preserve original bytes and a server-computed SHA-256 digest; derived previews and OCR/digitization outputs are separate versioned artifacts.
5. Rejection retains an auditable reason code while preventing public access; retention and deletion schedules require the approved data-governance policy.
6. Every transition must be performed by a trusted server-side service and recorded in an append-only audit trail.
7. A scanner timeout or infrastructure error must not be interpreted as acceptance.

## Deferred implementation decisions

- Private object-storage provider, bucket layout, encryption/key ownership, and signed upload protocol.
- Malware scanner and file-disarm/reconstruction strategy.
- Maximum object size, allowed image dimensions, retention period, and legal hold policy.
- Upload-intent authorization and station/instrument deployment checks.
- Idempotency, retry, expiry, cleanup, and scanner-failure recovery.
- Database schema and migrations, which remain blocked on scientific ERD/data-dictionary review and approval.

## Scope boundary

The C# and Dart state models are deterministic local contracts. They do not claim to enforce storage isolation or security controls until integrated into an authenticated backend workflow.
