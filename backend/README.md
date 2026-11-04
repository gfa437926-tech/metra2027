# METRA 2027 — Backend (.NET)

The backend is a standalone ASP.NET Core 10 Web API. It runs independently of Angular and Flutter and is the only application service intended to hold privileged database credentials.

## Requirements

- .NET 10 SDK

## Run independently

```bash
dotnet restore backend/Metra.Api/Metra.Api.csproj
dotnet run --project backend/Metra.Api/Metra.Api.csproj
```

The launch profile listens on `http://localhost:5000`. Health: `GET /api/v1/health`. Dependency readiness: `GET /api/v1/ready`. In Development, OpenAPI is exposed at `/openapi/v1.json`.

## Implemented API areas

- Supabase JWT bearer authentication and authenticated-by-default authorization.
- Station-scoped permission checks for operational observation creation and review.
- Read-only, paginated station directory (classic, automatic, and synoptic station types).
- Idempotent observation submission and observation review/decision routes.
- Request validation and separate liveness/readiness endpoints.

The readiness endpoint verifies that required Supabase-backed services have their server-side configuration. It does not prove that credentials are valid or that every database object is reachable; authenticated smoke tests are still required.

## Configuration

Use environment variables or a managed secret store. ASP.NET Core maps double underscores to configuration sections:

| Environment variable | Purpose |
|---|---|
| `Supabase__Url` | HTTPS URL of the new Supabase project |
| `Supabase__ServiceRoleKey` | Server-only service-role key; never expose to clients |
| `Authentication__Authority` | Optional issuer authority; defaults to the Supabase Auth authority |
| `Authentication__Audience` | JWT audience; defaults to `authenticated` |
| `Cors__AllowedOrigins__0` | First exact browser origin allowed by CORS |
| `Cors__AllowedOrigins__1` | Optional second exact browser origin |

Do not commit these values or place service-role credentials in Angular/Flutter configuration.

## Container

Build from the repository root:

```bash
docker build -f backend/Metra.Api/Dockerfile -t metra-api:local .
docker run --rm -p 8080:8080 \
  -e Supabase__Url=https://tbdnklyxjvbrilvnwgmq.supabase.co \
  -e Supabase__ServiceRoleKey=<server-secret> \
  -e Cors__AllowedOrigins__0=https://gfa437926-tech.github.io \
  metra-api:local
```

The container listens on port `8080`. Do not use a real secret in shell history or shared logs; inject it through the hosting platform's secret manager. The example origin is the GitHub Pages origin, not a guarantee that runtime secrets have been configured.

See [DEPLOYMENT.md](DEPLOYMENT.md) for the production checklist.
