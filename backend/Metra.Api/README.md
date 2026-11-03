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


## Station-scoped authorization

Operational endpoints must apply `RequireStationPermission("permission.code")`
and include a `{stationId:guid}` route parameter. The filter reads the authenticated
Supabase JWT `sub` claim and never accepts a user ID, role, or station scope from
the request body as proof of authority.

The API calls the narrowly scoped
`public.metra_user_has_station_permission(uuid, uuid, text)` RPC using the
server-only Supabase service-role key. Configure these hosting secrets:

- `Supabase__Url`: project URL.
- `Supabase__ServiceRoleKey`: service-role secret, stored only in the API host's
  secret manager/environment. Never add it to source control, Angular, or Flutter.

The RPC requires an active METRA account, an approved and current authority
membership, an approved and current assignment to the exact station, an active
catalogue role, an approved explicit permission grant, an active authority and
country, and an approved active non-demo station. It returns false for any
missing, expired, revoked, pending, or mismatched record. The function is
SECURITY DEFINER with a fixed search_path; execution is revoked from PUBLIC,
anon, and authenticated and granted only to service_role.

A missing API secret or failed RPC is fail-closed. Do not expose operational
routes until the host secret is configured and integration tests cover pending
accounts, expired memberships/assignments/grants, cross-station access,
self-elevation, and demo/unapproved stations. Generic observation validation
routes are not station-scoped operational write routes.


## Station directory

`GET /api/v1/stations?limit=250&offset=0&stationType=classic` returns the authenticated
read-only station directory. It exposes only the catalogue's non-demo station
projection: station identifiers/codes, bilingual names, station type, operational
and approval states, elevation, and current coordinate records. It does not expose
account, membership, assignment, grant, or audit fields.

The `stationType` filter accepts `classic`, `automatic`, or `synoptic`.
Pagination is bounded to 500 rows. Both classic and automatic records are included
when no type filter is supplied. Pending or unverified records remain visibly
labelled in the response; consumers must not treat them as approved/operational.
The server-side service-role key is used only by the API host. The mobile client
must send a valid Supabase access token and must never call the database directly.
