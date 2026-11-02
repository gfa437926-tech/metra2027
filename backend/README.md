# METRA 2027 — Backend (.NET)

The backend is a standalone ASP.NET Core Web API. It runs independently of Angular and Flutter and exposes shared HTTP endpoints to both clients.

## Requirements
- .NET 10 SDK

## Run independently
```bash
dotnet restore backend/Metra.Api/Metra.Api.csproj
dotnet run --project backend/Metra.Api/Metra.Api.csproj
```

The actual listening address is printed by ASP.NET Core. Health endpoint: `GET /api/v1/health`. In Development, OpenAPI is exposed at `/openapi/v1.json`.

## Configuration
- Browser origins are configured under `Cors:AllowedOrigins` in `Metra.Api/appsettings.json`.
- Use environment variables or a secret store for deployment secrets. Do not commit credentials.
- Flutter native requests are not subject to browser CORS; configure network access and HTTPS appropriately for deployment.

## PostgreSQL connection

The API uses Npgsql through a singleton `NpgsqlDataSource`. Configure the connection only in the API hosting environment:

- Environment variable: `ConnectionStrings__MetraDatabase`.
- Supply the host, database, runtime username and password through a managed secret store.
- The API enforces TLS certificate and hostname verification (`SSL Mode=VerifyFull`), connection pooling, bounded connection/command timeouts and disabled detailed database errors.
- Production/staging startup fails when the connection string is missing or incomplete. Development can start without it so domain-only work remains possible.
- Never put a PostgreSQL connection string in Angular/Flutter configuration, commit it, or log it.
- Use a dedicated least-privilege runtime database role; do not use an owner/migration credential for the API.

`GET /api/v1/health` is a liveness check. `GET /api/v1/ready` verifies database connectivity and returns 503 when no database is configured or the database cannot be reached. It does not expose connection details.

No schema migration, table, RLS policy, database role or Supabase Auth configuration is created by this increment.

## Independence
- No Node.js or Flutter SDK is required.
- The API starts and answers its health endpoint without either client running.
- Database integration, authentication, climate-record models, validation, and audit trails will be added in planned stages. No database schema or Supabase settings are changed by this scaffold.
