# Equipment Faults — JWT Runtime Identity vs Direct PostgreSQL Decision

**Status:** design assessment only; no database, Auth, signing-key, role, grant, or application configuration changes were made.

**Repository branch reviewed:** `work/equipment-fault-domain`  
**Reviewed HEAD:** `e8b0dd8e9ec5143a202e4775714c56dcf38a7b9e`  
**Supabase target:** `tbdnklyxjvbrilvnwgmq`

## 1. Executive finding

The active JWT signing algorithm for the target project is **not yet proven**. The project metadata endpoint returned project identity, region, Postgres version, and health only; it did not expose Auth signing-key state or algorithm. The public JWKS endpoint could not be retrieved in this review session. No JWT signing secret, private key, API secret, or database credential was requested or inspected.

The project was created on 2026-10-31. Supabase documentation says new projects have used asymmetric signing keys by default since 2025-10-01. This is useful evidence of the expected default, but it is not proof of this project's currently active key or algorithm. The Dashboard's **Authentication → JWT Signing Keys** page, or a successful read of the public JWKS endpoint, is required to confirm the active key type and `alg`.

The API currently validates inbound user JWTs through ASP.NET Core JwtBearer using the Supabase Auth authority and audience `authenticated`. Its existing outbound PostgREST services instead send the configured `Supabase:ServiceRoleKey` as both `apikey` and Bearer token. Equipment Faults has no dedicated storage adapter or runtime credential provider yet.

The existing `metra_api_runtime` database role is `NOLOGIN`, `NOBYPASSRLS`, and is not currently a member of `authenticator`. Therefore, a JWT containing `role: metra_api_runtime` cannot be assumed to work until the PostgREST role-switching membership and the role's narrowly scoped object privileges are deliberately configured and verified.

## 2. Evidence and gaps

### Repository evidence

- `backend/Metra.Api/Program.cs` configures inbound JWT Bearer validation with authority `{SupabaseUrl}/auth/v1`, audience `authenticated`, issuer/lifetime/signature validation, and JWKS-based authority metadata.
- `backend/Metra.Api/Security/StationAuthorizationService.cs` sends the service-role credential as the PostgREST Bearer token and API key.
- `backend/DEPLOYMENT.md` and `backend/Metra.Api/README.md` currently document `Supabase__ServiceRoleKey` as a server-side required setting.
- No Equipment Faults PostgREST writer or dedicated runtime identity provider is registered in `Program.cs`.

### Supabase project evidence

- Read-only project metadata identifies project `tbdnklyxjvbrilvnwgmq`, created 2026-10-31, active/healthy, region `eu-west-2`, Postgres 17.11.
- Earlier read-only role/catalogue review established that `metra_api_runtime` exists with `NOLOGIN`, `NOBYPASSRLS`, and no superuser or role-creation capability.
- Earlier review established that `authenticator` is not a member of `metra_api_runtime`.
- No key configuration, signing secret, private key, or Auth dashboard setting was read.

### What is still unknown

1. Active signing-key algorithm (`ES256`, `RS256`, or legacy `HS256`).
2. Whether the project has migrated its legacy JWT secret into the Signing Keys system and which key is currently active.
3. Whether the project's current public JWKS endpoint returns one or more asymmetric signing keys.
4. Whether the operator is willing to create and import a separately generated asymmetric key pair for a backend-issued runtime JWT.
5. Whether a narrowly-scoped PostgREST membership/grant design can be approved after the exact target tables and functions are reviewed.

## 3. Option B1 — short-lived custom JWT for PostgREST

### Corrected feasibility statement

B1 is technically possible without extracting Supabase's existing private signing key, but it is **not currently deployable** from the evidence available.

The safe variant is not to retrieve or reuse Supabase's active private key. Instead:

1. Generate a new asymmetric key pair under controlled backend operations (prefer ES256/P-256).
2. Import its public/private signing-key material into Supabase using the supported Signing Keys workflow, keeping the private signing material under the application's secret-management boundary. The import and activation are explicit Auth configuration changes and must be reviewed separately.
3. Confirm Supabase accepts JWTs signed by that key and that the matching public key is discoverable.
4. Configure the API to mint a separate, very short-lived downstream JWT for each validated request, with:
   - `role: metra_api_runtime`
   - `sub: <verified Supabase user UUID>`
   - `exp`: a short expiry (target 30–60 seconds, subject to clock-skew and request-duration design)
   - required issuer/audience claims only as required by the project's accepted JWT configuration.
5. Send that token as the PostgREST Bearer token and use a publishable API key in `apikey`. Never send the runtime JWT to a browser/mobile client.
6. Establish and verify the PostgREST `authenticator` → `metra_api_runtime` role-switching membership, then grant only the exact Equipment Faults tables/functions and required schema usage.
7. Ensure the database authorization model uses the verified `sub` identity (for example `auth.uid()`) for station scoping; a shared service identity or a client-supplied station ID must not become the authorization source.

### Advantages

- Retains PostgREST as the data transport and avoids opening a direct PostgreSQL connection from the API host.
- Can provide a dedicated role without `BYPASSRLS`, with short-lived per-user identity propagated to database policies.
- Asymmetric signing avoids sharing Supabase's legacy HMAC secret and allows public-key verification.
- Runtime tokens can be restricted to a specific database role and user subject.

### Risks and operational costs

- The backend becomes a JWT issuer and must protect a private signing key, rotate it, monitor expiry, and prevent tokens from appearing in logs.
- A role claim is not an authorization policy: role membership, object grants, RLS policies, and function execution grants must all be correct.
- Incorrect `authenticator` membership or overly broad role inheritance can widen access.
- Token issuer/audience/algorithm mismatch can fail closed and cause service outage.
- Key import/activation and role membership are configuration/database changes; they must be staged and tested, not inferred from project defaults.
- Supabase's own Auth-issued user JWT and the backend-issued PostgREST runtime JWT are different credentials with different trust purposes. They must have separate validation and lifecycle code.

### Important distinction

Supabase's existing signing private key cannot be recovered from the public JWKS endpoint. Supabase documents custom JWT minting by importing a private key or shared secret that the application itself controls. The safer proposal is an independently generated asymmetric key, not extraction or reuse of Supabase's existing secret.

## 4. Option A — restricted direct PostgreSQL connection

### Proposed shape

- Add a dedicated database login principal for the Equipment Faults API, separate from `postgres` and `service_role`.
- Give it only the exact schema/table/function privileges required by the Equipment Faults persistence adapter.
- Keep `BYPASSRLS`, superuser, database creation, role creation, and broad ownership privileges disabled.
- Connect using Npgsql over TLS from the private API host, with the credential held only in the host's secret manager.
- Execute each fault transition in a database transaction, including state change and append-only audit event.
- Propagate the verified caller subject into transaction-local request context before invoking RLS-protected operations. The implementation must ensure the application cannot accidentally reuse one user's context for another request on a pooled connection.
- Add integration tests against disposable PostgreSQL for station isolation, audit rollback, concurrent transitions, audit immutability, and connection-pool context reset.

### Advantages

- Clear database identity and transaction semantics; no custom JWT signing service is required.
- Native PostgreSQL transactions make atomic state-change-plus-audit implementation straightforward.
- Database permissions can be inspected and tested directly, independent of PostgREST role switching.

### Risks and operational costs

- The API host now holds a database login credential, increasing the impact of host compromise.
- Requires secure connection-string management, TLS verification, rotation, pooling limits, network exposure controls, and operational monitoring.
- Must explicitly implement and test transaction-local user/station context for RLS; a pooled connection must never leak prior request context.
- Direct SQL access bypasses PostgREST's API boundary, so schema/table/function privileges and SQL injection resistance become especially important.
- Npgsql adapter and its integration-test infrastructure must be added and maintained.

## 5. Side-by-side risk comparison

| Area | B1: short-lived runtime JWT | A: restricted PostgreSQL login |
|---|---|---|
| Credential held by API | Asymmetric private signing key | Database login credential |
| Data path | PostgREST | Direct PostgreSQL/Npgsql |
| RLS identity | JWT `sub` and role claim | Transaction-local verified subject context |
| Least privilege | Depends on role membership + grants + RLS | Depends on login role + grants + RLS |
| Atomic transitions | PostgreSQL functions/transactions behind PostgREST | Native Npgsql transaction |
| Main configuration risk | JWT key import, issuer/algorithm, authenticator membership | Login grants, network and pool context |
| Main compromise impact | Ability to mint tokens accepted by this project until key revoked | Direct database access within login grants |
| Operational complexity | JWT issuer, key rotation, PostgREST grants | Npgsql, connection pool, DB credential rotation |
| Current readiness | Not ready; critical configuration unknown | Not ready; adapter and login role do not exist |

Neither option is safe merely because the role is named `metra_api_runtime` or `equipment_faults_runtime`. The security boundary is the complete set of credentials, memberships, grants, RLS policies, functions, and tests.

## 6. Provisional recommendation

**Do not approve either option yet. Keep B1 as the preferred candidate only if the following conditions can be demonstrated:**

- The project has asymmetric JWT signing enabled, or a separately generated asymmetric key can be imported without exposing any existing Supabase private key.
- A short-lived backend-issued token can be verified by PostgREST with `role: metra_api_runtime`.
- The required `authenticator` membership can be narrowly configured and audited.
- `metra_api_runtime` remains `NOBYPASSRLS` and receives only the minimal Equipment Faults object privileges.
- Integration tests prove user/station scoping, audit atomicity, concurrency, and audit immutability using that exact runtime role.

If any of these cannot be met without broad grants or bypassing RLS, choose A and implement a dedicated restricted login plus Npgsql with transaction-local identity context and pool-isolation tests.

This is a conditional engineering recommendation, not authorization to change Supabase.

## 7. Safe operator verification required

The operator can confirm the following in Supabase Dashboard without sharing any secret or private key:

1. Open **Authentication → JWT Signing Keys**.
2. Report only the active key's **algorithm/type** (for example ES256 / EC P-256, RS256 / RSA, or legacy HS256) and whether its state is **In use**.
3. Open the public JWKS endpoint in a browser and report only the public JWK metadata fields `kty`, `crv`, `alg`, `kid`, and `use` if present. Do not share private JWK fields such as `d`, passwords, API secrets, or JWTs.
4. Do not click Migrate, Rotate, Revoke, Import, or Delete during this inspection.

## 8. No changes performed

- No SQL was run.
- No Supabase Auth or signing-key setting was changed.
- No role membership or grant was changed.
- No database schema, RLS policy, function, or migration was changed.
- No secret, private key, JWT, or database password was extracted.
- No production request or operational data was written.
