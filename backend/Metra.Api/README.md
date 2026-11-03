# METRA API — Authentication

## Supabase access tokens

The API validates Supabase Auth access tokens using ASP.NET Core JWT Bearer authentication.

- Issuer: `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1`
- Audience: `authenticated`
- Signature, issuer, audience, and expiration are validated.
- All endpoints require an authenticated user by default. Only the health endpoint is anonymous.
- JWT claims are kept in their original names; `sub` is the user identifier.

## Deployment configuration

Set these values in the API hosting environment (not in source control):

| Variable | Purpose |
|---|---|
| `Supabase__Url` | Supabase project URL |
| `Authentication__Authority` | Optional override; defaults to `{Supabase__Url}/auth/v1` |
| `Authentication__Audience` | Optional override; defaults to `authenticated` |
| `Cors__AllowedOrigins__0` | First permitted browser origin |
| `Cors__AllowedOrigins__1` | Additional browser origin, if needed |

Do not put the Supabase service-role/secret key or JWT signing secret in Angular, Flutter, Git, or ordinary application settings.

## Signing-key prerequisite

This JWT Bearer configuration obtains public signing keys from the Supabase Auth OpenID/JWKS discovery endpoints. Confirm that the project uses an asymmetric signing key (for example ES256 or RS256) and that its JWKS endpoint publishes the active public key before enabling authenticated production traffic.

Supabase does not publish symmetric HS256 secrets through JWKS. If the project still uses legacy HS256 signing, this verifier will fail closed; do not work around that by committing or exposing the JWT secret. Migrate the project to asymmetric signing keys or implement a separately reviewed server-side verification strategy first.

## Authorization boundary

A valid JWT proves identity only. It does not establish METRA job role, account approval, authority membership, station assignment, or station scope. Those checks must be implemented server-side against METRA's trusted records before exposing operational data or mutations. Never authorize using user-editable `user_metadata`, client-supplied role codes, or client-supplied station ownership.
