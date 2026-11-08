# Equipment Faults — Backend-to-PostgREST Identity Assessment

**Date:** 2026-11-08  
**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `work/equipment-fault-domain`  
**Scope:** read-only source review; no code, database, or secret changes.

## Executive finding

The current .NET API does **not** authenticate to PostgREST as `metra_api_runtime`. It authenticates every existing Supabase RPC call using the server-side `Supabase:ServiceRoleKey` as both the `apikey` header and Bearer token. PostgREST therefore executes those calls as `service_role`, not as the dedicated runtime role.

This is a decisive integration gap for the proposed Path B. The existence of `metra_api_runtime` in PostgreSQL does not cause the API to use it. The current service-role credential cannot be treated as least-privilege merely because a new RPC itself has a narrow body.

## Evidence in the current repository

### Runtime configuration
- `backend/DEPLOYMENT.md` declares `Supabase__ServiceRoleKey` required by the API host.
- `backend/Metra.Api/README.md` documents the same service-role secret as required for database RPC and directory access.
- `backend/Metra.Api/appsettings.json` contains no credential, which is appropriate; secrets are expected from the host secret manager.

### Request construction
- `backend/Metra.Api/Security/StationAuthorizationService.cs`: sends `Supabase:ServiceRoleKey` as both `apikey` and `Authorization: Bearer` to authorization RPCs.
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`: uses the same service-role key for observation submission and decision RPCs.
- The API validates the user's Supabase access token at its own HTTP boundary, but does not forward that user's JWT to PostgREST. It passes `userId` as a function parameter while the database request itself runs under `service_role`.

### DI and feature status
- `Program.cs` registers existing station/observation services and their bounded HttpClients.
- It does not register Equipment Faults storage services or a separate PostgREST credential provider.
- Equipment Faults transition writer remains an abstraction; there is no existing PostgREST implementation whose identity could be reused.

## Consequences for Path B

A PostgREST RPC request runs under the database role represented by its verified JWT role claim. Sending the current service-role token means the database sees `service_role`; it does not automatically switch to `metra_api_runtime`.

The catalog audit also found that `authenticator` is not currently a member of `metra_api_runtime`. Thus the dedicated role is not currently available through the observed PostgREST role-switch membership path.

A safe Path B implementation would need a separately designed and reviewed server-side credential flow that:
1. Produces a short-lived, cryptographically valid JWT whose role claim is `metra_api_runtime`, signed by a key accepted by the Supabase/PostgREST JWT verifier.
2. Keeps signing material exclusively in a server-side secret manager; never in Angular, Flutter, Git, container layers, or logs.
3. Limits token lifetime and audience/issuer as supported by the project's JWT configuration.
4. Establishes only the required PostgREST role-switch membership, after impact review; do not grant broad role membership or use a client-controlled role claim.
5. Verifies with integration tests that PostgREST actually executes the RPC as `metra_api_runtime`, and that requests cannot escalate to `service_role`.
6. Ensures the routine uses caller identity derived from a trusted claim or separately verified actor context; never trust arbitrary actor IDs supplied by a client.

The exact supported signing approach cannot be selected from the repository source alone. It depends on the target project's active JWT signing configuration and the host's ability to safely issue role-scoped tokens. Do not assume a legacy symmetric JWT secret is available or appropriate; do not extract or expose signing secrets in chat.

## Options

### Option B1 — Dedicated role JWT for PostgREST
Potentially preserves the existing HTTP/PostgREST architecture, but requires an approved signing-key/token-issuance design and a carefully scoped PostgREST role membership. This is **not ready** until the signing configuration and role-switch behavior are proven in a disposable test project or isolated test environment.

### Option A — Restricted direct PostgreSQL connection
A dedicated database login with only the exact required privileges can avoid dependence on PostgREST's JWT role-switch mechanism. It still requires a separately managed database connection secret, TLS, pooling/rotation, network restrictions, and transaction-level tests. It is also **not ready** until credentials and grants are designed and approved.

### Not acceptable
- Reusing `service_role` as the purported least-privilege execution identity.
- Giving the runtime role broad membership or broad table grants to make tests pass.
- Switching the whole application from service_role without auditing every existing workflow.
- Embedding signing secrets or database credentials in client applications, source files, Docker build args, or image layers.

## Recommended next gate

Before implementing Equipment Faults persistence, obtain a non-secret confirmation of the target project's active JWT signing algorithm/key type and supported custom-role JWT approach. Then validate role switching in an isolated environment with a harmless read-only probe and inspect the effective database role inside the request. If the project cannot support a safely issued role-scoped JWT, evaluate Option A. No production SQL or role changes are authorized by this assessment.

## Verification limits

This assessment is based on committed source and the earlier read-only catalog audit. It did not inspect host secret values, issue JWTs, send a test request as `metra_api_runtime`, or change any runtime configuration. No CI run is claimed for this documentation-only change.
