# METRA 2027 — Initial Threat Model and Security Register

Status: initial design artifact. Revisit this model when hosting, network topology, identity provider, database and integrations are approved. This document is not a completed security assessment or certification.

## Protected assets
- Identity credentials, MFA factors, sessions and recovery proofs.
- User profiles, role grants, station assignments and approval decisions.
- Weather observations, station metadata, operational reports and attachments.
- Audit records, exports, backups, encryption keys, signing keys and service credentials.
- Availability and integrity of the API and operational workflows.

## Security objectives
Confidentiality, integrity, availability and accountability. Access must be limited to authorized users and services; sensitive state changes must be attributable and transactionally consistent; service recovery must be tested.

## Trust boundaries
1. Browser/mobile device to API: all client input is untrusted.
2. API edge to application services: identity is accepted only after full session/token validation.
3. Application services to domain: commands are validated and domain invariants enforced.
4. Application services to persistence: least-privilege service identity, parameterized access and transactional integrity.
5. API to identity provider: issuer, audience, signing keys, protocol state and token lifetime validated.
6. Backend to integrations: outbound destinations and payloads constrained; credentials isolated.
7. Production to CI/CD/operators: deployments require protected, audited identities.
8. Production to backups/logging: copies encrypted, access-controlled and independently recoverable.

## Initial threat register

| Threat | Abuse scenario | Required controls | Verification |
|---|---|---|---|
| Account takeover | Stolen password/session | MFA, secure sessions, revocation, risk monitoring | Identity/session tests |
| Token substitution | Wrong issuer/audience accepted | Strict OIDC signature, issuer, audience, expiry and nonce/state validation | Negative token tests |
| Privilege escalation | Client changes role or station | Server-derived permissions, deny-by-default | Authorization matrix and tampering tests |
| BOLA/IDOR | User reads another station's report by changing ID | Object-level authorization on every operation | Cross-user/cross-station API tests |
| Approval fraud | Applicant self-approves or skips stage | Separation of duties, state machine, trusted actor context | Self-approval and transition tests |
| Race condition | Conflicting approvers overwrite state | Atomic compare-and-set and transactional audit | Concurrent integration tests |
| Secret exposure | Privileged key committed or bundled | Secret manager, scanning, revocation and rotation | Secret scan and rotation evidence |
| Storage theft | Database or backup copied | Encryption at rest, least privilege, key separation | Config review and restore test |
| Injection/XSS/CSRF | Untrusted input executes or changes session | Parameterization, output encoding, CSP, CSRF protection | SAST, DAST and targeted tests |
| Abuse/DoS | Registration, recovery or exports flooded | Rate limits, quotas, timeouts, monitoring | Load/abuse tests and alerts |
| Supply-chain compromise | Vulnerable/malicious dependency | Dependency scanning, pinned versions, SBOM, protected CI | CI scan evidence |
| Audit tampering | Privileged operator alters evidence | Append-only/tamper-evident storage, separate access | Access review and tamper test |
| Recovery failure | Backup or key cannot be restored | Encrypted backups, key recovery, runbooks | Timed restoration exercise |
| SSRF/integration abuse | API calls internal destinations | Egress allowlists, URL validation, network segmentation | DAST and integration tests |

## Feature security contract
Every endpoint must declare authentication, permission, resource/station scope, data classification, rate limit and audit requirement. Every write use case must define validation, idempotency, concurrency and transaction boundaries. Every sensitive field needs a purpose, exposure path, retention rule and encryption decision. Every integration needs documented data sharing, authentication, outbound destinations, timeout and failure behavior. Security exceptions require an owner, compensating control, expiry and approving authority.

## Release-blocking decisions
1. Approve the authoritative OIDC provider and issuer.
2. Decide browser session architecture (prefer BFF with HttpOnly Secure SameSite cookies where feasible).
3. Approve hosting, managed secret store and KMS/HSM.
4. Approve database roles, network boundaries and backup controls.
5. Approve data classification, retention and recovery objectives.
6. Assign an independent pre-production penetration tester.

## Initial status
- Threat categories and trust boundaries documented.
- Provider-neutral object-level authorization requirement/handler is registered; it requires an authenticated subject and delegates every resource decision to an authoritative evaluator. No production evaluator or endpoint-level resource policy invocation exists yet.
- A provider-neutral fail-closed evaluator now requires active actor, existing resource, canonical persisted station scope and active assignment facts from one authoritative data-source result; it ignores request-supplied station IDs and denies missing facts or data-source errors. It is not wired as the production evaluator because no authoritative persistence adapter exists. The default deny-all registration remains in effect. Endpoint invocation, endpoint-specific permission checks and production cross-station integration tests remain pending.
- The reusable evaluator now receives time-bounded assignment records and an injected `TimeProvider`; it requires exact canonical station matching, `ValidFromUtc <= now`, and `ValidToUtc`/`RevokedAtUtc` to be absent or strictly later than now. This makes expired and revoked assignments deny immediately at evaluation time. Unit tests use a fixed clock; persistence-backed integration tests remain pending.
- Action permission authorization now delegates to `IMetraPermissionGrantEvaluator` rather than trusting permission or role claims. The authoritative evaluator checks active account state and the requested grant's start/end/revocation instants on each authorization evaluation. Its production data source is not configured; the registered default denies all action permissions. This separates operation permission from object/station scope and supports prompt grant revocation without relying on stale token claims.
- Added a combined `metra:daily-observation-create-in-station` policy that requires both the `observations.daily.create` permission requirement and the independent resource-access requirement. `IAuthorizationService` integration tests verify allow only when both evaluators allow, deny when either denies, and deny anonymous actors. The policy is not yet attached to a production endpoint; deny-all defaults remain in place.
- Deployment topology and full attack-surface inventory: pending.
- Data classification and privacy review: pending.
- Identity, hosting, KMS and database controls: pending approval.
- Resource authorization unit tests cover evaluator allow/deny, anonymous/missing subject and malformed descriptors; production cross-station integration tests: pending authoritative data adapter.
- Security tests and penetration test: not yet run.
- No production security certification is claimed.

Related baseline: `SECURITY-CRYPTOGRAPHY-BASELINE.md`.
