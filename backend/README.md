# METRA 2027 — Backend (.NET 10)

The backend is the trusted application boundary shared by Angular and Flutter. Public clients must never connect directly to protected catalogue, identity or authorization tables.

## Requirements and local run

- .NET 10 SDK

```bash
dotnet restore backend/Metra.Api/Metra.Api.csproj
dotnet run --project backend/Metra.Api/Metra.Api.csproj
```

Health: `GET /api/v1/health`. Readiness: `GET /api/v1/ready`. In Development, OpenAPI is exposed at `/openapi/v1.json`.

## Database configuration

Configure `ConnectionStrings__MetraDatabase` only in the API hosting environment, using a managed secret store. The connection must use a dedicated least-privilege runtime database identity, TLS hostname/certificate verification (`SSL Mode=VerifyFull`), bounded timeouts and connection pooling. Never use a project-owner or migration credential as the application runtime identity. Never put a PostgreSQL connection string or Supabase service-role/secret key in Angular or Flutter.

Production/staging startup fails if the database connection is missing or incomplete. The readiness endpoint checks connectivity without returning credentials or connection details.

## Identity and authorization

The database contains authoritative records for account lifecycle state, authority membership, station assignment and time-bounded permission grants. The API must resolve the authenticated subject from the validated JWT only. It must not trust user metadata, request-supplied actor IDs, role names, station IDs or permission claims.

Before enabling protected station routes, implement a repository that reads account state, permission grant, authority membership, exact station assignment and station-level access grant from one consistent transaction snapshot. Validate UTC validity windows and revocation boundaries; reject inactive accounts, malformed facts, cross-authority assignments and self-approval. Write audit events in the same transaction as successful mutations.

Station routes intentionally fail closed (503) while their trusted repository is not registered. Do not remove this guard to make the UI appear connected.

## Station catalogue rules

The independent `station_catalogue` and `station_coordinates` tables are the sole operational source for directory, map, search and filters. The older Classic/Automatic read projection is prototype/compatibility code and must not be wired to the operational catalogue. Do not import, join or fall back to the legacy station dataset. Do not synthesize coordinates or deduplicate stations by display name.

## Clients

- Angular uses the API over HTTPS with credentialed authentication; it must not query protected Supabase tables directly.
- Flutter uses the same API and identity/authorization contracts.
- Configure browser origins under `Cors:AllowedOrigins`. Native Flutter calls are not subject to browser CORS.

## Release gates

The service is not production-ready until repositories, account/membership/assignment workflows, station lifecycle endpoints, authenticated integration tests, staging smoke tests, observability and backup/restore rehearsal are complete. Keep feature flags disabled until these gates pass.
