# METRA 2027 — Initial Security Audit

**Date:** 2026-11-11  
**Reviewer role:** Assistant 7 — Security  
**Repository:** `gfa437926-tech/metra2027`  
**Base reviewed:** `main` at audit start  
**Scope:** ASP.NET Core API, Supabase authorization/migrations, Angular authentication and API integration, Flutter authentication/session storage, CI/deployment configuration.

## Executive summary

The current architecture has several sound security controls: Supabase JWT validation, a fallback authenticated-user policy, station- and authority-scoped database authorization, server-only service-role access, RLS and client-deny policies for operational observation tables, idempotent observation submission, append-only audit records, HTTPS-only client configuration, and bounded Supabase HTTP client timeouts.

This is a **static repository review**, not a penetration test or a live production assessment. The repository documentation states that no production API host has yet been supplied/verified and that the new Supabase project has no real users or authority assignments. Production readiness therefore remains **blocked** pending environment setup and real-identity authorization tests.

## Findings

| ID | Severity | Finding | Evidence / impact | Recommended action |
|---|---|---|---|---|
| SEC-001 | High / release blocker | Production identity, deployment, and real-user authorization are not verified | `README.md`, `docs/security/authority-scope-authorization.md`, and `docs/deployment/MULTI-ENVIRONMENT-HOSTING.md` state that production hosting/secret configuration and real-user/cross-authority tests remain outstanding. The project currently has no live identity population. | Do not treat CI or image publication as production readiness. Before launch, provision the approved host, configure secrets in its secret manager, verify readiness, onboard the first administrator through a controlled owner-approved process, and run positive/negative tests with dedicated accounts in at least two authorities and multiple stations. |
| SEC-002 | Medium | No API rate limiting is configured | `backend/Metra.Api/Program.cs` does not register or apply ASP.NET Core rate-limiting middleware. Authentication protects endpoints, but authenticated or unauthenticated traffic can still consume API and Supabase capacity. | Add configurable per-client/per-IP limits after the hosting proxy and trusted forwarded-header topology are explicitly configured. Apply tighter limits to login-adjacent, registration, decision, and expensive read operations. Add 429 tests and operational monitoring. |
| SEC-003 | Medium | API security response headers and HSTS are not explicitly configured | `Program.cs` currently configures HTTPS redirection, but no explicit HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options` or CSP/frame-ancestors policy is present. This is a defense-in-depth gap, particularly if API responses are ever served from a browser origin. | Add production-aware HSTS and response headers; verify proxy TLS termination and forwarded-header trust before changing redirect behavior. |
| SEC-004 | Medium | No explicit API request-body ceiling is visible | Observation payloads are checked for a 64 KiB JSON object after model binding, but the host does not configure a global request-body limit in the reviewed startup. Large bodies can be buffered/parsed before endpoint guards execute. | Configure an appropriate Kestrel/reverse-proxy maximum body size, then test oversized JSON and multipart requests. Keep endpoint-specific payload limits and return 413. |
| SEC-005 | Medium | Browser auth session persistence increases XSS impact | `angular-app/src/app/core/supabase/supabase-auth.service.ts` configures `persistSession: true`; the Supabase browser client uses browser storage by default. A successful script injection could potentially access a bearer session. Angular's template sanitization helps, but it is not a substitute for CSP and safe DOM practices. | Avoid unsafe DOM APIs and untrusted HTML; add a restrictive CSP compatible with the application; review any `innerHTML`, direct DOM, third-party script, and markdown rendering use. Consider an HttpOnly, Secure, SameSite cookie/BFF architecture if the threat model requires stronger token isolation. |
| SEC-006 | Low / Medium | Host filtering is broad | `backend/Metra.Api/appsettings.json` sets `AllowedHosts` to `*`. | Set an explicit production host allow-list once the real API hostname is known. Keep local development configuration separate. |
| SEC-007 | Medium | Secret-file ignore rules were incomplete | The original root `.gitignore` excluded build artifacts but did not exclude `.env*`, local secret settings, private keys, or a secrets directory. This creates an avoidable accidental-commit risk. | **Addressed on this branch:** added ignore patterns for environment files (with example/template exceptions), local secret settings, secrets directories, and private key/certificate files. This does not remove or rotate any already committed secret; historical secret scanning and credential rotation are still required if a secret is ever discovered. |
| SEC-008 | Medium | Angular dependency advisories were not checked in client CI | `.github/workflows/client-ci.yml` previously ran `npm install --no-audit` and built the client. A lockfile exists, but client CI did not run npm advisory checks. Backend CI already enables NuGet audit at high severity. | **Addressed on this branch:** client CI now uses `npm ci` and `npm audit --audit-level=high`. The PR CI result must pass before merge. Review Flutter transitive dependency advisories separately as part of scheduled dependency maintenance. |
| SEC-009 | Low | No explicit security-event alerting policy is defined | Database audit tables record important workflow decisions and access lifecycle events, but repository review did not identify a central alerting/retention/incident-response policy for repeated authentication failures, authorization denials, anomalous request volume, or service-role misuse. | Define structured security event fields, redaction rules, retention, alert thresholds, and incident ownership. Never log bearer tokens, passwords, service-role keys, or full sensitive payloads. |

## Controls verified in source

### Authentication and authorization

- `backend/Metra.Api/Program.cs` validates JWT issuer, audience, lifetime, signing key, and HTTPS metadata; clock skew is 60 seconds.
- A fallback authorization policy requires an authenticated user unless an endpoint explicitly opts into anonymous access.
- Only the health and readiness probes are explicitly anonymous in the reviewed startup.
- `StationAuthorizationService.cs` uses server-side Supabase RPC calls and fails closed on missing configuration, non-success responses, malformed responses, transport errors, and timeouts.
- `StationAuthorizationEndpointExtensions.cs` derives the actor from the verified `sub` claim and binds station scope from the route.
- `database/migrations/003_station_permission_rpc.sql` requires active account, active authority/country, approved current membership, approved current station assignment, active role mapping, role allow-list permission, and an approved current unrevoked individual grant for the exact station.
- `database/migrations/023_bind_authority_access_decisions_to_route_scope.sql` binds membership/grant decision and revocation RPCs to the authority ID supplied in the route and rejects cross-authority IDs.
- `docs/security/role-permission-matrix.md` documents an allow-list; it does not create a global administrator bypass.
- Angular route guards are explicitly documented in source as navigation guards only. API/database authorization remains the security boundary.

### Database and injection review

- Operational observation tables are RLS-enabled and forced; client roles are denied access by the reviewed Supabase migrations.
- Operational writes and decisions are performed through narrow server-side RPCs, with direct execution restricted to `service_role`.
- Observation submission uses a composite idempotency key and compares replayed payloads before returning a replay result.
- Observation review locks the target row, checks the exact station and permission, and writes an append-only audit event.
- Reviewed API calls use typed values and JSON request bodies for PostgREST/RPC operations. Station type is allow-listed and escaped before being added to the directory query. No clear SQL-injection path was identified in the reviewed files.
- No cookie-based API authentication was identified; API calls use bearer tokens in the Authorization header. Traditional cross-site form CSRF is therefore not the primary risk; XSS/token theft is more relevant.

### Secrets and transport

- The Supabase service-role key is read from server configuration and used only by backend services in the reviewed code. Deployment documentation explicitly prohibits putting it in clients, build arguments, image layers, logs, or source control.
- The Angular runtime configuration contains only the public publishable/anon key, which is intentionally client-visible and is **not** a service-role credential.
- Flutter uses publishable client configuration and a secure-storage adapter for the Supabase session.
- Backend Supabase service URLs are required to be HTTPS by the service configuration checks. Flutter API configuration also requires HTTPS.
- The container runs as a non-root application user.

## Validation and limits

- Reviewed source and configuration files directly from the repository's default branch.
- Confirmed a lockfile exists for Angular and Flutter.
- Existing backend CI includes NuGet high/critical advisory checks, SQL contract scripts, API build/tests, and container build.
- Existing API tests cover unauthenticated/malformed bearer-token rejection, dependency timeouts, and fail-closed authorization service behavior.
- This session did not run a live penetration test, authenticate against a production API, query the Supabase project, apply migrations, inspect private repository secrets, or run local builds/tests. The new CI audit/build/test results must be checked on the draft PR.
- No database migrations, RLS policies, Supabase project settings, or live accounts were changed.

## Release gates

1. Complete SEC-001 through SEC-006 or document an explicit, approved risk acceptance.
2. Verify the actual production hostname, TLS termination, forwarded-header trust, HSTS, and exact CORS origin.
3. Verify a normal observer can access only their assigned station; a station manager cannot cross stations; a reviewer cannot cross authorities; inactive/expired/revoked users and grants are denied.
4. Verify self-approval, replay/idempotency, race conditions, malformed JWTs, expired JWTs, wrong issuer/audience, and oversized requests.
5. Run dependency audit checks for .NET, npm, and Flutter; review any advisories before release.
6. Confirm no service-role key or other secret exists in Git history, artifacts, logs, or client bundles. Rotate any exposed credential immediately.
7. Obtain the user's approval before any database schema, data, or RLS change.

## Branch changes

- Added environment/private-key ignore rules to `.gitignore`.
- Changed Angular client CI to use the lockfile deterministically and fail on high/critical npm advisories.
- No application runtime code or database migration was changed in this initial security pass.
