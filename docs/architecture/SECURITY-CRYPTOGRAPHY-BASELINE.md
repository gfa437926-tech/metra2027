# METRA 2027 — Security, Cybersecurity and Cryptography Baseline

Status: mandatory target baseline for design and implementation. This document defines security requirements; it is not a certification, penetration-test report, or claim that the current application already satisfies them.

## 1. Security objective

METRA must be designed using defence in depth and secure-by-default principles. Security is a release requirement across Angular, Flutter, ASP.NET Core, identity services, infrastructure, PostgreSQL/Supabase, integrations, backups and operational processes.

No system can honestly be described as absolutely secure. The target is to reduce attack surface, prevent common and high-impact attacks, detect abuse, limit blast radius, recover safely and continuously verify controls against a documented threat model.

## 2. Mandatory architecture principles

1. Zero trust: authenticate every protected request; authorize every operation against current server-side account state, permission, station assignment, resource scope and workflow state.
2. Least privilege: separate human roles, application permissions, service identities, database roles and deployment identities. Deny by default.
3. Defence in depth: do not rely on a single perimeter, UI guard, token, database policy or encryption layer.
4. Secure by default: production configuration must fail closed when security-critical settings, keys, origins, identity validation or required controls are absent.
5. Minimize data: collect, return, log and retain only information necessary for an approved operational purpose.
6. No client trust: never accept actor identity, role grants, station assignment, approval state or effective permissions from Angular/Flutter payloads or browser storage.
7. Security review before release: security requirements are acceptance criteria, not a final-stage optional task.

## 3. Identity, authentication and sessions

- Select and approve a standards-based OIDC identity provider before enabling sign-in. Use Authorization Code Flow with PKCE for public clients; do not embed client secrets in Angular or Flutter.
- Validate issuer, audience, signature, allowed algorithms, expiry, not-before, nonce/state where applicable, and signing-key rotation using supported libraries. Reject unsigned, malformed, wrong-issuer and wrong-audience tokens.
- Require MFA for privileged accounts and administrators; prefer phishing-resistant authenticators (passkeys/FIDO2 or equivalent) where supported. Define step-up authentication for high-impact actions.
- Define session lifetime, idle timeout, refresh-token rotation/reuse detection, revocation, sign-out, lost-device handling and emergency account suspension.
- Do not store access or refresh tokens in browser localStorage. Prefer a Backend-for-Frontend with Secure, HttpOnly, SameSite cookies for browser sessions where feasible; if cookies are used, implement CSRF protection and strict origin checks. Mobile token storage must use OS-protected Keychain/Keystore facilities.
- Never implement a parallel METRA password store. Password policy, password hashing, credential recovery and breached-password checks belong to the selected identity provider. If a future approved component must store passwords, require a separately reviewed modern password-hashing design (Argon2id preferred) with unique salts and calibrated parameters; never use fast hashes or reversible encryption.
- Recovery must use provider-managed, short-lived, single-use proofs; responses must not reveal whether an account exists. Rate-limit and monitor recovery attempts.

## 4. Authorization and workflow integrity

- Enforce authorization in the API for every read and write, including exports, bulk actions, downloads and background jobs.
- Resolve immutable identity subject to an internal METRA account; derive current active assignments and permissions from authoritative server-side records.
- Separate requested role from granted permission. A role name alone does not grant access to a station or resource.
- Enforce station scope, ownership, account status, assignment validity and workflow-state transitions on the server.
- Use explicit permission checks and deny-by-default policies. Prevent self-approval and separation-of-duties conflicts for sensitive approvals.
- Use optimistic concurrency/compare-and-set or database constraints for state transitions. Commit state changes, audit events and dependent activation/assignment changes in one transaction.
- Protect against IDOR/BOLA by checking object-level authorization after loading each target resource. Do not rely on unguessable IDs as authorization.
- Require idempotency controls for retryable high-impact commands and prevent duplicate account/assignment creation.

## 5. Cryptography and key management

### Data in transit
- Require HTTPS for all production client/API and service-to-service traffic. Disable plaintext HTTP except controlled local development; redirect to HTTPS and enable HSTS after domain/TLS validation.
- Require TLS 1.2 minimum, prefer TLS 1.3, disable obsolete protocol versions and weak cipher suites. Validate certificates; never disable certificate validation in production.
- Use secure transport for database, object storage, message and external-service connections.

### Data at rest
- Require managed encryption at rest for database volumes, object/file storage, backups, snapshots and log storage.
- Identify sensitive fields and assess field-level/application-level encryption where database operators or broad infrastructure access should not reveal plaintext.
- Use authenticated encryption such as AES-256-GCM or an approved modern equivalent for application-level encryption. Use a unique nonce/IV per encryption under a given key; never reuse GCM nonces. Store algorithm/version/key identifier with ciphertext; authenticate relevant metadata as associated data.
- Do not invent custom cryptographic algorithms or protocols. Use vetted platform libraries and managed key services.
- Passwords are hashed by the identity provider, not encrypted or stored by METRA. Encryption is not a substitute for password hashing.

### Key lifecycle
- Keep keys, signing secrets, database credentials and provider secrets out of source control, client bundles, logs, screenshots, tickets and ordinary configuration files.
- Use a managed secret store and KMS/HSM-backed key management where available. Apply least-privilege access, environment separation, key versioning, rotation, revocation, access logging and tested recovery.
- Separate encryption keys from encrypted data and backups. Never use one key for unrelated purposes; use key derivation only through approved standard constructions.
- Establish rotation and incident procedures before production. Any exposed privileged credential must be revoked/rotated; removing it from current source does not remove it from Git history, forks, caches or deployed bundles.
- Never use production secrets in development, test fixtures or CI logs.

## 6. API, browser and mobile hardening

- Validate all input server-side with explicit length, range, format and allow-list rules. Apply output encoding and parameterized database access. Avoid dynamic SQL and unsafe deserialization.
- Use request-size limits, timeouts, pagination caps, upload validation, malware scanning for supported file uploads and safe file names/content types.
- Apply rate limits and abuse controls to sign-in callbacks, registration, recovery, OTP/MFA, search, exports and expensive endpoints. Add account/IP/device risk signals without using them as sole authorization.
- Configure CORS with exact approved origins; never combine wildcard origins with credentials. CORS is not authentication.
- Add appropriate security headers (CSP, HSTS, frame restrictions, nosniff, referrer policy and permissions policy) and test compatibility. Avoid unsafe-inline/eval in CSP; use nonces/hashes when necessary.
- Prevent XSS, CSRF, SSRF, injection, path traversal, open redirects, request smuggling and mass assignment. Treat uploaded files and external content as untrusted.
- Protect against BOLA/IDOR, privilege escalation, replay, race conditions and business-logic abuse.
- Mobile builds must protect local sensitive data, disable verbose production logging, validate deep links/app links and use platform secure storage. Do not rely on obfuscation as a security boundary.
- Error responses must not expose stack traces, secrets, SQL, internal hostnames or personal data.

## 7. Database and data governance

- API-only access for authoritative business data. No privileged database key or direct database write path in browser/mobile clients.
- Use separate least-privilege database roles for runtime, migrations, read-only reporting and operations. Runtime must not have schema-owner or superuser rights.
- Use parameterized queries, constraints and transactions. Add row-level security as defence in depth where appropriate, but do not treat RLS as a substitute for API authorization.
- Require explicit review and approval before any Supabase schema, RLS, policy, Auth-user or data migration change. Keep migrations versioned, reviewed, reversible where feasible and tested against a non-production environment.
- Define data classification, purpose, retention, deletion, residency and access rules. Mask or pseudonymize non-production data; do not copy production personal data into developer environments by default.
- Encrypt backups and test restoration, integrity and recovery objectives. Limit backup access independently from production access.

## 8. Audit, monitoring and incident response

- Record security-relevant events: authentication outcomes, MFA changes, authorization denials, privileged actions, approval decisions, role/assignment changes, secret/key operations, exports and administrative changes.
- Audit entries should include trusted actor ID, action, target, timestamp, outcome, correlation ID and minimal before/after context. Never log passwords, tokens, recovery proofs, private keys or full sensitive payloads.
- Protect audit storage against alteration and deletion by ordinary application operators; restrict access and monitor audit pipeline failure.
- Centralize structured logs, metrics and security alerts. Monitor anomalous login/recovery patterns, privilege changes, bulk exports, repeated denials, unusual station access and service-account activity.
- Synchronize clocks and retain sufficient forensic metadata under an approved retention policy.
- Maintain incident playbooks for credential exposure, account takeover, data leakage, ransomware, service compromise and lost devices. Exercise revocation, key rotation, containment, notification and restoration procedures.

## 9. Secure software supply chain and delivery

- Pin and regularly update dependencies; run SAST, dependency/SCA and secret scanning on every pull request and default branch.
- Generate an SBOM for release artifacts; scan container images and infrastructure definitions where used.
- Protect CI/CD with least-privilege short-lived identities, protected branches, required reviews, environment approvals and isolated secrets. Never expose deployment credentials to untrusted pull-request code.
- Build reproducibly where practical; sign release artifacts and verify provenance/integrity before deployment.
- Separate development, test, staging and production environments and credentials. No production data or secrets in CI.
- Add DAST/API security tests and infrastructure/configuration scanning in staging. Conduct independent penetration testing before production and after material changes.
- Track vulnerabilities by severity, owner, remediation deadline and verified closure. Block release on unresolved critical/high findings unless a formally approved exception includes compensating controls and expiry.

## 10. Required verification gates before production

Production identity, approvals or sensitive data workflows must not be enabled until all applicable gates pass:

- [ ] Approved threat model and data classification.
- [ ] Approved identity provider, MFA policy and session/revocation design.
- [ ] Complete authorization matrix and negative tests for every role, station and resource scope.
- [ ] API integration tests for unauthenticated, inactive, wrong-station, wrong-owner and insufficient-permission actors.
- [ ] Concurrency, replay, idempotency and transaction/audit atomicity tests.
- [ ] TLS configuration and encryption-at-rest evidence for data, files, backups and logs.
- [ ] Managed secret/key storage, rotation, revocation and recovery evidence.
- [ ] Secret scanning, SAST, dependency scanning and SBOM generation in CI.
- [ ] DAST and independent penetration test with critical/high findings resolved.
- [ ] Centralized monitoring, alerting, incident playbooks and tested backup restoration.
- [ ] Privacy, retention and access review.
- [ ] Security sign-off and documented risk acceptance for any remaining exceptions.

## 11. Current status and scope boundaries

The current repository is not yet production-secure and must not be represented as certified or fully hardened. The ASP.NET Core API currently has no configured authentication middleware/provider or production persistence adapter. The registration approval application service is provider-neutral and not registered or exposed as an endpoint.

This baseline does not itself enable encryption or configure infrastructure. Actual controls require approved hosting, identity, database, key-management and deployment decisions. Until approved, do not change Supabase Auth, schema, RLS, policies or existing records.

## 12. Implementation sequence

1. Threat model, data classification and security architecture decisions.
2. Identity provider, MFA, secure browser/mobile session and server-side authorization.
3. Managed secrets, key lifecycle, TLS and encryption-at-rest configuration.
4. Least-privilege database adapter, transactional workflows and tamper-resistant audit.
5. API/client hardening, rate limits, secure headers and abuse controls.
6. CI security gates, SBOM, DAST, penetration testing and remediation.
7. Monitoring, incident response, backup restoration and operational security sign-off.

Security work is continuous: repeat relevant threat modelling and verification after changes to identity, permissions, data flows, dependencies or infrastructure.
