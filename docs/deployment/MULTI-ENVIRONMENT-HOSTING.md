# METRA 2027 — Multi-environment deployment matrix

This runbook describes one codebase with separate configuration for local development, LAN testing, government-hosted production, and optional cloud hosting. It does not provision hosts, create databases, or apply migrations.

## Architecture boundary
- Angular and Flutter are clients only. They call the ASP.NET Core API. HTTP is for local development only; deployed clients use HTTPS.
- The ASP.NET Core API is the sole holder of the Supabase service-role credential and performs privileged database operations.
- Client publishable/anon keys are public configuration and never substitute for API authorization or RLS.
- Never put service-role credentials in client bundles, mobile build arguments, source control, Docker layers, logs, or support tickets.
- The legacy Supabase project is out of scope and must remain unchanged. New environment work targets only the new project.

## Environment matrix
| Environment | API host | Client API base | Database target | Purpose |
|---|---|---|---|---|
| Local developer | ASP.NET Core localhost | localhost API URL | isolated development project/schema | development |
| LAN integration | private server behind firewall | private HTTPS or temporary LAN URL | isolated development project/schema | web/mobile device testing |
| Government data center | authority-managed IIS or approved container platform | official HTTPS API hostname | authority-approved production DB/project | production |
| Cloud/VPS option | approved container host | provider HTTPS hostname | isolated cloud test or approved production project | optional hosting |
| CI/test | ephemeral runner | test-only URL | test-only database/project | automated tests |

Never point development, CI, or cloud previews at production. Create distinct development, test, and production Supabase projects or authority-approved isolated DB instances. The legacy project is not an environment target.

## API server configuration
ASP.NET Core reads appsettings.json, appsettings.{Environment}.json, and environment variables. Environment variables use double underscore separators.

Required server settings:
- Supabase__Url: URL of this environment's new Supabase project.
- Supabase__ServiceRoleKey: server-only secret from the provider secret store.
- Authentication__Authority: matching Supabase Auth issuer, normally project URL plus /auth/v1.
- Authentication__Audience: normally authenticated, unless JWT configuration explicitly differs.
- Cors__AllowedOrigins__0: exact deployed Angular origin (scheme + hostname; no wildcard).
- ASPNETCORE_ENVIRONMENT: Development, Staging, or Production.
- ASPNETCORE_HTTP_PORTS: provider/container port when required.

Example local PowerShell (use a development project and local secret; never paste secrets into chat):
```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ASPNETCORE_HTTP_PORTS = "5080"
$env:Supabase__Url = "https://YOUR-DEV-PROJECT.supabase.co"
$env:Supabase__ServiceRoleKey = "<DEV-ONLY-SECRET>"
$env:Authentication__Authority = "$($env:Supabase__Url)/auth/v1"
$env:Authentication__Audience = "authenticated"
$env:Cors__AllowedOrigins__0 = "http://localhost:4200"
dotnet run --project backend/Metra.Api
```

Do not commit real .env files, user secrets, publish-settings files, or provider secrets. Use .NET User Secrets locally or process environment variables. Shared hosting must use protected secret/configuration storage.

## Client configuration
### Angular
- Set runtime API base to the matching environment HTTPS API URL ending in /api/v1.
- GitHub Pages origin is https://gfa437926-tech.github.io; allow it only when Pages is the client for that environment.
- Local web origin: http://localhost:4200.
- Client publishable/anon key may be visible to browsers. Never inject the service-role key.
- A client configured for one environment must not silently fall back to production.

### Flutter
- Supply METRA_API_BASE_URL with --dart-define at build/run time.
- The current Flutter URL validator accepts HTTPS only. For Android emulator testing, use an HTTPS development reverse proxy; `http://10.0.2.2:<port>` is valid only after a deliberate development-only HTTP policy is implemented (it is not accepted by the current app). Physical devices likewise need a reachable HTTPS LAN endpoint, not localhost.
- Production builds use the official HTTPS API host and production-safe client configuration.
- Never embed server credentials in Dart constants or build defines.

## Government Windows/IIS deployment
1. Obtain the authority-approved server, DNS name, certificate, firewall rules, database endpoint, and deployment account through its IT team.
2. Publish the API for the supported runtime; install the matching ASP.NET Core Hosting Bundle on IIS.
3. Deploy the published API folder to a dedicated IIS site/application. Configure its app pool as No Managed Code and use the generated web.config.
4. Terminate HTTPS at IIS or the approved reverse proxy. Trust forwarded headers only from known proxy addresses.
5. Set production environment variables/secrets in protected host configuration. Do not commit secrets in web.config.
6. Set exact production CORS origins and the authority-approved Supabase URL/issuer. Confirm outbound HTTPS or approve a different database architecture.
7. Verify /api/v1/health and /api/v1/ready. Readiness requires configured dependencies and an authenticated catalogue probe.
8. Run station-scoped smoke tests with a dedicated test account and non-operational test record; verify audit and idempotency.
9. Document backup/restore, monitoring, incident contact, certificate renewal, and rollback before launch.

If policy requires the database inside the government network, this Supabase-backed implementation cannot be assumed compliant. Obtain architecture/security approval before migrating to government-managed PostgreSQL or a compatible service; that is a separate integration, not merely a URL change.

## Optional cloud/VPS deployment
The repository Render Blueprint is an optional cloud path. Review region, pricing, data residency, access controls, and contract before provisioning. Supply the service-role key only in the provider secret field. Any VPS/container host also requires HTTPS, exact CORS, secret storage, restricted network access, backups, monitoring, and verified readiness.

A published image or Blueprint does not mean a cloud service exists. Record a provider URL only after it is assigned and health/readiness pass.

## Release promotion and rollback
1. Build/test in development and CI against isolated data.
2. Review migration SQL and backup plan; do not auto-apply production migrations without approval.
3. Deploy the exact immutable artifact to staging; verify health, readiness, auth, station authorization, observation idempotency, review permissions, and audit.
4. Promote the same artifact digest to production with production-only configuration/secrets.
5. Keep the prior artifact and rollback procedure. Database rollback requires reviewed backup/migration plan.
6. Verify client API base, CORS, HTTPS, no secret leakage, and monitoring after release.

## Current limitations / gates
- No government host, DNS name, credentials, firewall approval, or production database environment has been supplied or verified here.
- API readiness returns 503 until server-side Supabase dependencies are configured and the catalogue probe succeeds.
- Local build/tests or image publishing do not mean production is deployed.
- Do not generate operational fake observations; use dedicated clearly marked test data only.

## GitHub Pages deployment prerequisites

The Pages workflow fails closed before publishing if its runtime configuration is missing or unsafe. Configure these repository Actions secrets before expecting a Pages deployment to succeed:

| Secret | Required value |
|---|---|
| `METRA_API_BASE_URL` | The deployed API's HTTPS base URL ending in `/api/v1`, for example `https://api.example.gov.sy/api/v1`. Do not use the Pages URL, a Supabase URL, localhost, or an unprovisioned example hostname. |
| `METRA_SUPABASE_ANON_KEY` | The new Supabase project's public publishable/anon key. This key is designed for client use; it is not the service-role key. |
| `METRA_SUPABASE_URL` | Optional override for the new environment's clean HTTPS Supabase origin. If omitted, the workflow uses the configured new-project URL in the workflow file. |

Add them under **GitHub repository → Settings → Secrets and variables → Actions → Repository secrets**. Never store the Supabase service-role key in GitHub Pages secrets or any browser/mobile configuration.

Current repository verification (2026-11-04): the post-merge Pages run failed at runtime-config validation because `METRA_API_BASE_URL` was empty. The API host has not yet been provisioned, so do not substitute a placeholder. Once a real HTTPS API host exists and the public client key is configured, rerun **Deploy Angular app to GitHub Pages** and verify `/api/v1/health` and `/api/v1/ready` against that host before calling the site integrated.
