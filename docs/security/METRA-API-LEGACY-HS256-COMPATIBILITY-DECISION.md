# METRA API — Legacy HS256 Compatibility Decision and Database Authorization Boundary

**Date:** 2026-11-08  
**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `work/equipment-fault-domain`  
**Target database:** Supabase project `tbdnklyxjvbrilvnwgmq` only.

## 1. Decision: preserve legacy HS256 sessions through Auth-side verification

The dashboard metadata supplied by the project operator establishes:
- current signing key: ECC P-256 / ES256;
- previously used signing key: HS256 shared secret.

The API must not try to verify HS256 locally using the asymmetric JWKS. The HS256 shared secret is not present in the public JWKS, and exporting or copying it into the API would unnecessarily expand the secret-exposure boundary.

Supabase's current JWT verification guidance explicitly recommends validating shared-secret HS256 user access tokens against the Auth user endpoint:

`GET /auth/v1/user` with the project's publishable API key and the presented user access token as Bearer token. A successful authenticated user response indicates a valid token; a failed response is denial. This keeps the HS256 secret inside Supabase Auth.

**Chosen compatibility policy:** use local JWKS validation for ES256 tokens; for legacy HS256 tokens only, use a bounded, server-side Auth `/user` verification fallback. Do not trust the JWT header's `alg` value as proof of validity: it may select which verifier is attempted, but the selected verifier must independently authenticate the token. Any unknown algorithm, malformed token, missing subject, issuer/audience mismatch, expired token, Auth timeout, or non-success Auth response fails closed.

This policy avoids forcing all still-valid HS256 users to sign in again solely because the API uses asymmetric local validation. It does not extend token lifetime and does not accept expired tokens.

## 2. Implementation requirements before enabling fallback

The fallback is not yet implemented. The implementation must:
1. Require HTTPS and a fixed configured Supabase Auth base URL; never derive a host from token claims.
2. Send the token only to the configured project's `/auth/v1/user` endpoint, with the project's publishable key in `apikey`.
3. Never log, trace, persist, or include the bearer token in exceptions.
4. Use a strict short timeout, bounded concurrency/rate, and cancellation propagation. Auth outage or timeout means 401/503 according to the API's established error contract, never anonymous success.
5. Build the authenticated principal from the verified Auth response, using its returned user UUID as `sub`; do not copy unverified claims from the raw token.
6. Confirm any additional claims required by API authorization are loaded from trusted server-side sources. The API must not rely on unverified role/metadata claims.
7. Keep ES256 local validation as the fast path. An HS256 fallback must not broaden ES256 validation or permit algorithm confusion.
8. Add tests for ES256 success, legacy HS256 success via a mocked Auth verifier, invalid/expired tokens, malformed tokens, wrong issuer/audience, missing user ID, Auth 401/403, Auth timeout, cancellation, and assurance that tokens never appear in logs.
9. Add operational metrics containing only algorithm category/outcome/latency; never include raw token, signature, or secret.

The API currently uses ASP.NET Core JwtBearer with authority metadata and ES256-capable JWKS validation, but the current source has no Auth `/user` compatibility handler and no publishable-key configuration shown for this purpose. This is an implementation gap, not a verified dual-algorithm capability.

## 3. Key lifecycle restrictions

- Do not rotate, revoke, import, delete, or otherwise modify either signing key as part of this work.
- Do not retrieve the HS256 secret or any private key.
- Do not ask the operator to paste a JWT or refresh token into chat.
- Do not disable signature or lifetime validation.
- The previous key remains a verification concern until the project operator independently confirms its expiry/revocation state.

## 4. Scope of database authorization granted by the operator

The operator has explicitly authorized work in the new METRA Supabase project `tbdnklyxjvbrilvnwgmq`, with a strict prohibition on deleting the old database.

Interpretation and guardrails:
- This authorization applies only to the new METRA project identified above.
- It does not authorize access to, alteration of, or deletion of any legacy database or unrelated Supabase project.
- No database deletion, project deletion, destructive reset, `DROP DATABASE`, schema wipe, or broad truncate operation is permitted.
- Preserve existing data and objects. Any future migration must be additive or narrowly scoped and must include a rollback/restore plan.
- Before applying production DDL, inspect the live schema and produce the exact SQL plus impact/rollback notes. Keep the SQL review checkpoint; this is especially important because the earlier user instruction required SQL to be prepared for review before execution.
- Never expose credentials or secrets in chat or repository files.
- This document itself makes no database change and does not execute SQL.

## 5. Immediate next actions

1. Implement and test the dual verification design in the API without changing Supabase settings.
2. Inspect the current new-station catalogue schema and Equipment Faults proposal against the live target project's metadata, read-only.
3. Produce an additive, non-destructive SQL migration proposal with exact object names, grants, RLS policies, indexes, and rollback/forward-repair notes.
4. Only after the SQL review checkpoint, apply approved changes to the new target project. Never touch the old database.
