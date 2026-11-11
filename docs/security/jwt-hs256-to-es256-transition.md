# METRA JWT transition: HS256 → ES256

## Current dual path (API)

1. **Primary:** JWT Bearer validation using Supabase Auth Authority / JWKS (asymmetric, typically ES256).
2. **Optional parallel:** `Authentication:JwtSecret` for local HS256 verification during rotation.
3. **Fallback:** `GET {SupabaseUrl}/auth/v1/user` with the bearer token; identity taken only from Auth response `id` → claim `sub`.

## Transition steps

1. Keep `Authentication:JwtSecret` only in server secret stores.
2. Enable Supabase asymmetric JWT signing and confirm JWKS is reachable over HTTPS.
3. Deploy API build that includes dual validation.
4. Monitor 401 rates and Auth fallback hits for at least one access-token lifetime.
5. Remove `Authentication:JwtSecret` after HS256 tokens expire.
6. Never embed JWT secrets in Angular or Flutter.

## Fail-closed rules

- Missing/invalid `sub` UUID after validation → authentication failure.
- Auth service timeout or non-success → no principal.
- Roles/permissions for station operations are never taken from client-modifiable claims; they are resolved server-side via station permission RPCs.
