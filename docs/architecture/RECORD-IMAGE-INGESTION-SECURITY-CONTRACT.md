# Recorder image intake contract - initial secure validation slice

This change adds a pure .NET validation boundary for scanned recorder images. It is not an upload endpoint and does not write to Supabase, object storage, or the local filesystem.

## Accepted formats
- JPEG (image/jpeg, .jpg / .jpeg)
- PNG (image/png, .png)
- TIFF (image/tiff, .tif / .tiff), little- and big-endian classic TIFF signatures

## Enforced checks
- Safe leaf filename only; path separators and traversal-like names are rejected.
- Non-empty content and a 20 MiB maximum.
- File type is detected from byte signatures, not trusted from the browser-supplied MIME type.
- Declared MIME type and filename extension must agree with the detected format.
- A caller-supplied SHA-256 digest is mandatory and compared in constant time.
- A normalized digest is returned for later provenance and audit records.

## Explicitly out of scope
- No upload route, storage bucket, persistence, malware scanning, image decoding, EXIF stripping, OCR, chart digitization, or authorization decision is implemented here.
- No hosted database or legacy database was accessed or modified.
- Before enabling persistence, define and review the new record-image schema, private storage policy, quarantine and scanning workflow, retention rules, actor/station authorization, and audit event contract.
- Successful validation is not proof that an image is safe to render. Downstream services must decode and re-encode in an isolated process and serve only through an authorized path.

## Validation
Unit tests cover supported signatures, MIME and extension mismatch, traversal names, empty and oversized payloads, missing/invalid/tampered digests, and forged signatures.
