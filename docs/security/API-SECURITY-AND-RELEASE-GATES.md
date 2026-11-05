# METRA 2027 — API Security and Release Gates

**Review target:** `main` at `8094da69ac5e9ee210ec08532e49eebc1ba4e3fb`  
**Review date:** 2026-11-05  
**Status:** Source-level review; no runtime secrets or live database credentials were inspected.

## Confirmed API security controls

The current ASP.NET Core startup code confirms:

- JWT bearer authentication is the default authentication scheme.
- Issuer, audience, token lifetime, and signing key are validated; HTTPS metadata is required.
- The authorization fallback policy requires an authenticated user unless an endpoint explicitly opts out.
- Supabase HTTP clients have an eight-second timeout.
- CORS origins are read from `Cors:AllowedOrigins`; no wildcard origin is configured.
- Exception handling, HTTPS redirection, authentication, and authorization middleware are registered.
- Health and readiness endpoints are explicitly anonymous. Health returns only a basic liveness payload. Readiness returns a generic ready/unavailable result and probes the station directory; it does not return database rows or credentials.

These controls are useful foundations, but do not by themselves establish production readiness.

## Release gates requiring verification

| Gate | Required evidence before production |
|---|---|
| Runtime database identity | Dedicated non-superuser login inherits only the intended `metra_api_runtime` privileges; no service-role credential is used as the API's ordinary database identity |
| Configuration | Supabase URL, JWT authority/audience, database connection, and allowed CORS origins are supplied through the deployment secret/configuration mechanism; no secrets are committed |
| Data Protection | Persistent protected key ring is configured for the deployment topology, access is restricted, and key backup/rotation is documented |
| Authorization | Every operational endpoint has a server-side permission and station-scope test; client-side route/menu guards are treated only as UX |
| Readiness | All required feature dependencies are included in readiness as features are added; readiness must fail closed when a required dependency is missing or unavailable |
| Observability | Structured logs redact bearer tokens, passwords, connection strings, personal data, and provider credentials; privileged actions emit audit events |
| Transport | Production HTTPS, trusted proxy/forwarded-header behavior, HSTS policy, and exact CORS origins are verified in the real hosting environment |
| Resilience | Bounded timeouts, cancellation propagation, safe retry policy, and concurrency behavior are tested against disposable integration dependencies |
| Supply chain | Locked dependencies, CI tests, dependency/security review, SBOM and provenance artifacts are retained for each release |

## Specific source-level follow-ups

1. **Anonymous readiness endpoint:** retain only if the hosting platform requires an unauthenticated readiness probe. Keep its response generic and rate-limit or network-restrict it at the edge if the hosting environment supports that safely. Do not expose diagnostic exception details.
2. **CORS configuration:** define the exact Angular and Flutter web origins for each environment. An empty origin list intentionally does not grant browser cross-origin access; confirm this is configured before diagnosing browser API failures.
3. **Dashboard route:** Angular's empty-path dashboard currently has no client authentication guard while feature routes do. Decide whether it is a public landing page or a protected dashboard, then align navigation and route behavior. Regardless, keep API authorization authoritative.
4. **New feature readiness:** when fault, maintenance, analytics, management, or reminder services are implemented, register their health/configuration checks in readiness and cover missing-dependency behavior with tests.
5. **Privileged workflows:** password resets, user deactivation/deletion, registration decisions, station reassignment, bulk reminders, exports, backup access, and attachment downloads require explicit permissions, audit records, and abuse/rate controls.

## Verification boundaries

- This review read source code only. It did not execute tests, contact the live Supabase project, change a schema, provision credentials, deploy an API, or verify hosting configuration.
- No legacy database was accessed.
- No station catalogue records were changed.
- No source HTML files were modified.
- No production readiness claim is made by this document.

## Next implementation sequence

1. Finish archive recovery and source inventory so the feature contracts are complete.
2. Agree the role/permission matrix and station-scope rules.
3. Implement one backend feature slice at a time with API contract tests and audit behavior.
4. Connect the Angular screen to the verified contract, then port the same approved workflow into Flutter.
5. Run CI and authenticated role/station isolation tests before accepting each slice.
