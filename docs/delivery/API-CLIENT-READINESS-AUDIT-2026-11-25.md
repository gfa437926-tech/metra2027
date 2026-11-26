# METRA 2027 — API Client Readiness Audit
Date: 2026-11-25
Reviewed branch: `fix/flutter-quality-gates-2026-11-23`
Reviewed file: `mobile/metra_mobile/lib/core/api/metra_api_client.dart`

## Scope and limits

This is a static review of the published Flutter API client source. It is not a server-contract verification, runtime test, security certification, or CI result. No endpoint, DTO, database object, migration, RLS policy, RPC, or permission rule was changed. The legacy repository and database remain out of scope.

## Confirmed positive controls

1. The API client rejects an unconfigured base URL before sending a request.
2. Requests require a non-empty access token and attach it as a bearer token.
3. Request/token operations have bounded timeouts.
4. Station and observation path identifiers are validated and URL-encoded before interpolation.
5. Station type filters are restricted to a fixed allow-list.
6. Observation submission is locally restricted to the currently supported server types: `hourly`, `daily`, and `phenomenon`.
7. The access context is loaded from the server endpoint rather than treating a client-selected role as authoritative.
8. The station directory pagination cap probes for overflow instead of silently truncating at exactly 10,000 rows.

## Robustness findings requiring follow-up

These are concrete parser behaviors in the reviewed source. Whether each is a defect depends on the actual .NET response contract, which was not available in this review.

| Area | Current behavior | Risk to address |
|---|---|---|
| Observation queue item | Missing/non-string status becomes `submitted`; non-map payload becomes an empty map | Malformed server data can look like a valid submitted item or an empty observation |
| Generic station records | Non-map list entries are silently discarded | A partially malformed response can appear complete |
| Registration roles | Unexpected response shapes become an empty list | Contract drift can look identical to “no requestable roles” |
| Registration status | Several response shapes are accepted, including a raw fallback map | Callers may receive an untyped payload and mistake it for a valid status |
| Validation response | A non-list `issues` value becomes an empty issue list; missing issue fields are tolerated | Malformed validation output may be presented as a clean result with no field details |

## Required follow-up before changing parser behavior

1. Obtain the current .NET response DTOs and endpoint implementations for each listed route.
2. Add fixture-based tests for valid, empty, malformed, and contract-drift responses.
3. Decide explicitly which responses should fail closed with a typed format/contract exception.
4. Preserve legitimate server response compatibility; do not infer new field names or response shapes.
5. Run Flutter format, analyze, focused tests, full tests, and the repository CI after changes. Record exact command results and commit SHA.

## Contract and authorization boundary

- Client-side validation is usability support only; the .NET server remains authoritative.
- UI role labels or local permission maps must not grant server actions.
- Do not add unsupported observation types such as rainfall or soil until the required M1–M4 decisions and server contracts are approved.
- No database/schema/RLS/RPC/migration change is authorized by this audit.

## Status

Static source review completed for the published API client file. No code changes were made from this audit. Runtime behavior, endpoint compatibility, .NET authorization, and test status remain unverified.
