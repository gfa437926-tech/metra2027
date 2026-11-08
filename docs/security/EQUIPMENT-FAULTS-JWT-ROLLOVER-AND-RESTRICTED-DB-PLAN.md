# Equipment Faults — JWT Rollover and Restricted PostgreSQL Runtime Plan

**Status:** design-only addendum. It does not authorize database, Auth, signing-key, network, or deployment changes.

**Repository:** `gfa437926-tech/metra2027`  
**Branch at review:** `work/equipment-fault-domain`  
**Reviewed HEAD:** `dfd9bae870427feca69f4c824604e7587c01ccb1`  
**Supabase project:** `tbdnklyxjvbrilvnwgmq`

## 1. Newly confirmed signing-key state

The operator inspected Authentication → JWT Signing Keys and reported:

| State | Key ID | Type | Interpretation |
|---|---|---|---|
| Current / In use | `7c608d23-94fa-4af3-908a-ceaddb5900b4` | ECC (P-256) | ES256 |
| Previously used | `e22be7ae-c34c-42c1-8867-243edd3283d8` | HS256 (Shared Secret) | Legacy tokens may still be accepted for verification until expiry/revocation |

Only public key metadata was shared. No JWT, signing secret, private key, database password, or API secret was requested or received.

Supabase documents that asymmetric public keys are discoverable through JWKS, that signing-key rotations can leave previously issued tokens valid, and that JWKS responses are cached. Therefore, the existence of a current ES256 key does **not** prove that every still-valid access token is ES256.

## 2. Required correction to API JWT assumptions

The current API configures ASP.NET Core JwtBearer with the Supabase Auth authority, audience `authenticated`, issuer/lifetime/signature validation, and authority metadata discovery.

That configuration is evidence of intended JWT validation, but it is **not yet evidence that the deployed API accepts both the current ES256 tokens and previously issued HS256 tokens**. An asymmetric JWKS publishes public verification keys; it does not publish the secret required to locally verify an HS256 signature.

Before changing authentication code, run a safe compatibility test in a non-production test environment covering:

1. A newly issued ES256 user access token is accepted.
2. An unexpired previously issued HS256 token is either accepted through an explicitly designed compatibility path or deliberately rejected with a documented re-authentication experience.
3. An expired token is rejected.
4. Wrong issuer, wrong audience, invalid signature, missing subject, and malformed token are rejected.
5. Unknown `kid` causes a bounded metadata refresh; it must not disable signature validation or create an unbounded outbound request path.

Do not obtain or export the legacy HS256 secret merely to make local validation work. If legacy-token continuity is required, evaluate a server-side Auth user-validation fallback using the presented bearer token and the project's public API key, or require session refresh/re-authentication after confirming the user impact. The chosen path must fail closed and must never log bearer tokens.

Do not add a permissive "accept either algorithm" switch without a cryptographically correct key source for each algorithm. Pin accepted algorithms to the intended key types and issuer.

## 3. Option A design baseline — trusted API + restricted PostgreSQL access

The Equipment Faults API should use a dedicated database principal, not `postgres`, `service_role`, or a role with `BYPASSRLS`.

### Connection and credential boundary

- Store the dedicated database credential only in the API host's secret manager.
- Never place it in appsettings committed to Git, browser/mobile configuration, logs, telemetry, or exception messages.
- Prefer a persistent-backend-compatible direct connection where network/IP support permits; otherwise evaluate the project's **session pooler** connection string. Do not guess the pooler hostname or username; copy the exact values from the project's Connect panel.
- Require TLS with certificate-chain and hostname verification (`verify-full` equivalent), using the Supabase database CA certificate.
- Set bounded connection/open/command timeouts, pool size limits, and rotation procedures.
- Do not choose transaction-mode pooling for this long-running API without proving compatibility with the driver's prepared-statement and session-state behavior.

### Runtime privilege boundary

The proposed application principal must be:
- non-superuser, `NOBYPASSRLS`, and unable to create roles, databases, schemas, or extensions;
- not a member of `postgres`, `service_role`, or any broad inherited role;
- unable to own application tables or security-sensitive routines;
- restricted to the Equipment Faults schema objects and operations that are explicitly approved.

The preferred write boundary is a single narrowly scoped database transition routine that performs the conditional fault-state transition and audit append atomically. The API login should not receive unrestricted direct table mutation rights if those rights would let it bypass the transition state machine. The routine owner, security mode, fixed search path, object ownership, grants, and RLS interaction require a separate complete SQL review. No runnable SQL is approved by this document.

### Caller and station context

- The API must first validate the caller's Supabase access token.
- The actor UUID must come only from the validated `sub` claim, never from a request body, route parameter, or client-supplied header.
- The station assignment/permission must be resolved by the trusted authorization service against the authoritative new METRA station catalogue and assignment data. A client-supplied station ID is only a requested resource selector, not proof of authorization.
- For a database operation, pass the verified actor and authorized station context inside the same explicit transaction using transaction-local context (for example, transaction-local `set_config(..., true)` values) before executing the transition routine.
- Never use session-level context on pooled connections. Every request must begin a transaction, establish context, execute the operation, then commit or roll back before returning the connection.
- Treat transaction-local context as an application-to-database trust assertion, not as a cryptographic identity: a compromised process holding the database credential can issue SQL and forge custom session settings. The API process and its secret boundary remain trusted components.

### Atomic transition and audit

One transaction must:
1. Match the fault by both fault ID and authorized station ID.
2. Compare the expected current state to prevent stale/concurrent transitions.
3. Apply the allowed state transition.
4. Append exactly one audit event with actor, station, previous/new state, timestamp, and correlation identifier.
5. Commit both changes together, or roll both back.

The runtime path must not update or delete audit history. Prefer an append-only audit design with no UPDATE/DELETE grant for the API principal and a separately controlled owner/maintenance path. Cross-station and unknown-fault cases should have the same external response to avoid resource enumeration.

## 4. Required integration tests before production wiring

Use a disposable PostgreSQL instance in CI (for example, a pinned Testcontainers PostgreSQL image) and execute application-path tests with the same restricted role used by the adapter. Keep fixture/schema-owner credentials separate from application configuration.

Required tests:

| Test | Required assertion |
|---|---|
| Station isolation | User A cannot list, count, read, or transition a fault belonging to station B |
| Actor spoofing | Request body/header actor IDs cannot override validated JWT `sub` |
| Station spoofing | Client-supplied station ID cannot bypass authoritative station assignment |
| Pooled connection isolation | Interleave two users on reused connections; no actor/station context leaks |
| Rollback | Force audit append failure; fault state and audit history both remain unchanged |
| Concurrency | Two sessions transition the same expected state; exactly one succeeds |
| Audit immutability | Runtime role cannot UPDATE or DELETE an existing audit event |
| Privilege boundary | Runtime role has no superuser, role creation, ownership, or RLS bypass capability |
| Error privacy | Cross-station and nonexistent fault IDs are externally indistinguishable |
| TLS/config | Production configuration rejects unverified TLS and missing credentials |

Unit tests alone do not prove PostgreSQL transaction, grants, RLS, or connection-pool behavior.

## 5. Current implementation gap

Repository review found:
- `Program.cs` registers bounded named HttpClient services for existing Supabase/PostgREST features.
- `StationAuthorizationService.cs` currently sends the configured service-role credential as both PostgREST `apikey` and Bearer token.
- No Npgsql package or Equipment Faults PostgreSQL adapter is currently registered in `Metra.Api.csproj` / `Program.cs`.
- Existing API JwtBearer configuration uses the Supabase Auth authority, but compatibility with the project's previous HS256 tokens has not been demonstrated.
- The earlier database execution decision record still describes an alternative PostgREST routine path; this addendum makes Option A the current design baseline for Equipment Faults and does not authorize implementing either path yet.

## 6. Decision gates

Before implementation:
1. Decide and document the legacy HS256 session behavior (safe compatibility validation or deliberate re-authentication).
2. Inspect the current Equipment Faults schema proposal and identify the exact fault, audit, station, and transition objects.
3. Produce a complete privilege matrix and exact SQL for role ownership, routine security mode, grants, RLS, and transaction context.
4. Review the actual Supabase Connect options, pooler mode, network/IP compatibility, and CA certificate requirements without exposing credentials.
5. Obtain explicit operator approval of the complete SQL and isolated test setup.
6. Only after approval, create the disposable test schema, implement the Npgsql adapter, and run integration tests.

## 7. Explicitly unchanged

- No SQL was executed.
- No database role, membership, grant, table, function, trigger, RLS policy, or migration was created or altered.
- No Auth setting or signing key was changed, rotated, revoked, imported, or deleted.
- No secret, private key, JWT, or database credential was accessed.
- No production or legacy database was modified.
