# METRA 2027 Backend

The shared backend is ASP.NET Core Web API on .NET 10 (C#).

## Projects

- `Metra.Api`: HTTP API entry point. All Angular and Flutter clients will use this API.
- Future application/domain/infrastructure projects will be introduced when the approved climate-record model and workflows are defined.

## Current endpoint

- `GET /api/v1/health`: service health only.

## Local run

```bash
dotnet run --project backend/Metra.Api
```

OpenAPI is exposed in Development at `/openapi/v1.json`.

## Data and security

No database schema, credentials, authentication provider, or RLS policies are changed by this scaffold. Do not put secrets in appsettings files. PostgreSQL/Supabase integration, identity, roles, audit history, and record validation will be designed before implementation.
