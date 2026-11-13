# METRA API Security Architecture (C4)

## Authentication
- JWT Bearer validated against Supabase Auth authority.
- `ValidateIssuer`, `ValidateAudience`, `ValidateLifetime`, `RequireExpirationTime`, `ValidateIssuerSigningKey`.
- `ClockSkew` = 60 seconds.
- `MapInboundClaims = false`; name claim = `sub`.
- Fallback authorization policy: authenticated user for all endpoints except explicit anonymous.

## Authorization
- Station operations: server-side RPC + Domain policies; never client roles.
- ArchiveRead: explicit station-scoped grant; endpoint remains **503** without archive service.
- Grant uniqueness conflicts: HTTP **409** (`authority_permission_grant_conflict`).

## Transport & headers
- HTTPS redirection.
- CORS only when `Cors:AllowedOrigins` configured.
- Security headers: nosniff, DENY frame, no-referrer, restricted permissions policy.

## Rate limiting
See `RATE-LIMITING-POLICY.md`.

## Secrets
- Service role key only from configuration/environment — never committed.
- Error responses must not echo secrets (readiness tests assert placeholder absence).

## Audit
- Authority grant lifecycle writes append-only audit events in database (triggers block UPDATE/DELETE).
- API does not expose mutation of audit tables.
