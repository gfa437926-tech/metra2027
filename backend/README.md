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

## Independence
- No Node.js or Flutter SDK is required.
- The API starts and answers its health endpoint without either client running.
- Database integration, authentication, climate-record models, validation, and audit trails will be added in planned stages. No database schema or Supabase settings are changed by this scaffold.
