# METRA 2027 — Authentication and Session Security Design

Status: provider-neutral implementation contract. No identity provider, production token validator, session store, or sign-in endpoint is enabled by this document.

## 1. Current verified state

- ASP.NET Core has authorization policies and deny-all authorization data-source defaults, but no authentication scheme/provider is configured in `Program.cs`.
- The currently mapped observation endpoints only validate request payloads; they do not persist observations or authorize a business operation.
- The legacy browser login directly queries user tables, verifies a browser-side password hash, and stores a profile/role snapshot in `localStorage`. The legacy recovery flow exposes a generated temporary password. These are migration blockers, not acceptable fallback behavior.
- The Angular Supabase client configuration is blank and must not be populated with a privileged key. The final identity provider remains undecided.
- No production session persistence or revocation service exists.

## 2. API default-deny authentication boundary\n\nThe API registers a fallback authorization policy requiring an authenticated principal. New endpoints inherit this requirement unless they explicitly use anonymous metadata. The current health endpoint and pure observation-validation endpoints are explicitly anonymous because they do not expose or mutate user data. Keep data access, persistence, mutation, export, approval and administration endpoints protected by default.\n\nUntil an identity provider is approved, the API uses a named unconfigured authentication handler that always returns no authentication result. It does not parse or accept bearer tokens and does not manufacture a test identity. This allows unauthenticated protected requests to be challenged rather than silently treating authorization registration as authentication. Replace the placeholder with the approved maintained OIDC/JWT adapter before protected production operations are enabled. Test principals are permitted only in isolated automated tests.\n\n## 3. Identity-provider boundary

The API must accept identities only from one explicitly approved OIDC trust configuration. The adapter must use a maintained platform/library implementation for protocol and cryptographic validation; METRA must not implement JWT signature verification, JWK parsing, OIDC discovery, password verification, or token issuance itself.

Required validation for API access tokens:
- Exact configured issuer and API audience.
- Signature verified against issuer-published signing keys with safe key rollover.
- Explicit allow-list of approved asymmetric signing algorithms; reject `none`, algorithm confusion and unexpected symmetric algorithms.
- Required expiry and not-before validation with small, explicit clock skew.
- A non-empty immutable subject (`sub`); reject malformed or oversized identity values.
- Reject malformed, unsigned, expired, not-yet-valid, wrong-issuer and wrong-audience tokens.
- Never treat role, permission, station, account status or approval claims as authoritative METRA grants. Those are resolved from server-controlled state.
- Do not log raw access/refresh tokens, authorization codes, cookies or recovery proofs.

Configuration must fail closed in production if issuer, audience, trusted metadata/JWKS location, HTTPS transport or approved algorithm policy is missing or invalid. Do not hard-code issuer URLs or keys before the provider decision. Do not disable certificate validation or fetch arbitrary metadata/JWKS URLs from request data.

## 4. Client session architecture decision

### Browser (Angular)

Preferred option: Backend-for-Frontend (BFF).
- Browser receives only a session cookie marked `Secure`, `HttpOnly`, and an explicitly selected `SameSite` policy.
- Cookie scope is host-only where feasible, with narrow path and lifetime.
- Unsafe HTTP methods require CSRF protection (anti-forgery token and origin validation); CORS is not CSRF protection.
- Session identifiers are opaque, random, rotated after authentication/privilege changes, stored hashed server-side, and never accepted from URLs.
- Logout and administrative revocation invalidate the server-side session.
- No access or refresh token is exposed to browser JavaScript or stored in localStorage/sessionStorage.

Alternative only after explicit risk review: an OIDC public SPA using Authorization Code + PKCE. No client secret. Keep short-lived access tokens in memory; never persist refresh tokens or access tokens in browser storage. This still has greater XSS token-theft exposure than a BFF.

### Mobile (Flutter)

- Use OIDC Authorization Code + PKCE through the platform browser/system authentication session.
- Use the provider's supported secure token storage backed by iOS Keychain / Android Keystore; never plain preferences, files, logs or embedded secrets.
- Rotate refresh tokens where supported; detect refresh-token reuse and revoke the affected token family/session.
- Validate redirect URI/app links, state and nonce through a maintained OIDC library.
- Logout clears local secure storage and invokes provider/API revocation where supported. Lost-device and account-compromise flows must support server-side revocation.

### API

- Validate bearer access tokens on every protected request using the approved issuer/audience policy.
- Resolve the immutable provider subject to the METRA account and current account status.
- Do not infer METRA authorization from a signed role claim.
- Immediate revocation requires an explicitly selected mechanism (short-lived access tokens plus session/token-version checks, provider introspection, or another reviewed revocation design). A self-contained JWT remains usable until expiry unless the API checks revocation state.
- Public health and pure, non-sensitive validation endpoints may remain anonymous by explicit endpoint classification. All data access, mutation, exports, approvals and administration endpoints must require authentication and operation/resource authorization.

## 5. Session lifecycle requirements

The selected provider/session adapter must define and test:
- Creation only after successful provider authentication and required MFA/step-up.
- Absolute lifetime and idle timeout; server time is authoritative.
- Refresh rotation and reuse/replay detection.
- Session identifier rotation after sign-in and privilege elevation to prevent fixation.
- Single-session logout and global/account-wide revocation.
- Revocation on account suspension, credential compromise and material security changes.
- Lost-device handling and administrator-triggered revocation.
- Concurrent refresh behavior and atomic single-use semantics.
- Bounded clock skew, safe handling of clock rollback, and auditable lifecycle events.
- Minimal session metadata: opaque session reference, subject, created/last-seen/expiry times, revocation state/reason and correlation metadata. Never store raw refresh tokens in the METRA session database; if token lookup is needed, use a keyed digest and managed key lifecycle.
- Rate limits and generic responses for login, callback, MFA, refresh, logout and recovery operations.

Do not invent a parallel METRA password database. Password reset, credential policy, breached-password checks and recovery proofs remain with the approved identity provider.

## 6. Identity-to-METRA actor resolution

A validated OIDC subject is only an identity proof. For each protected request:
1. Validate token/session using the approved identity adapter.
2. Resolve the immutable subject to exactly one METRA account.
3. Require the account to be active and not suspended/rejected.
4. Load current permissions and effective station assignments from authoritative persistence.
5. Load the target resource and its canonical station from the same consistent authorization snapshot where the operation requires station scope.
6. Evaluate operation permission, workflow state and object-level access.
7. Audit sensitive outcomes without recording credentials or tokens.

A client-provided user ID, email, role, station, approval flag, or local profile object must never override these facts.

## 7. Fail-closed release gates

Before enabling sign-in or protected business endpoints:
- Approve the identity provider, issuer, audience, client registrations and redirect URIs.
- Approve browser BFF versus SPA session architecture and Flutter secure-storage library.
- Configure and test token signature, issuer, audience, expiry, not-before and key rotation validation.
- Test invalid/missing tokens, inactive accounts, wrong subject mapping, revoked sessions, expired sessions and refresh replay.
- Test CSRF, XSS-sensitive token exposure, open redirects, deep-link validation and CORS boundaries.
- Test account suspension and global revocation against active sessions.
- Configure production secrets in a managed secret store; no client secret in Angular/Flutter.
- Add rate limits and monitoring for identity endpoints.
- Complete data classification, retention and incident-response requirements.

Until these decisions and adapters are approved, do not configure production authentication, add a default permissive scheme, expose sign-in/recovery endpoints, modify Supabase Auth, or migrate account records. The API must not claim authenticated operation merely because an authorization policy or test principal exists.
