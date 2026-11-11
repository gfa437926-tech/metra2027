# METRA API — Production deployment guide

## Published image

The GitHub Actions workflow publishes the API container to:

- `ghcr.io/gfa437926-tech/metra2027-api:latest` (main branch)
- `ghcr.io/gfa437926-tech/metra2027-api:sha-<full-commit-sha>` (immutable commit tag)

Use the immutable SHA tag for controlled releases. The image listens on TCP port `8080` and runs as the non-root ASP.NET container user.

Publishing the image does not deploy it. A hosting provider/service and its deployment credentials must be configured separately.

## Required host configuration

Set these variables in the API host's environment/secret manager:

| Variable | Required | Notes |
|---|---:|---|
| `Supabase__Url` | Yes | `https://tbdnklyxjvbrilvnwgmq.supabase.co` |
| `Supabase__ServiceRoleKey` | Yes | Secret; API server only |
| `ConnectionStrings__MetraOps` | Optional for Npgsql operations path | Use a dedicated non-superuser login; it must be a member of the NOLOGIN `metra_api_runtime` group. Never use a superuser or `service_role` connection for this constrained path. |
| `Authentication__Authority` | Recommended | `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1` |
| `Authentication__Audience` | No | Defaults to `authenticated` |
| `Cors__AllowedOrigins__0` | Yes for browser | Exact deployed Angular origin |
| `Cors__AllowedOrigins__1` | Optional | Additional exact origin, if needed |
| `ASPNETCORE_HTTP_PORTS` | No | Image defaults to `8080` |

Do not expose `Supabase__ServiceRoleKey` to GitHub Pages, Angular, Flutter, or end users. Do not add it to a Docker build argument or image layer.

For GitHub Pages, the browser origin is `https://gfa437926-tech.github.io`. Add other origins only when they are actually used. CORS is not an authentication mechanism.

## Host requirements

1. Run the published container image on a supported container host, or use a separately verified ASP.NET Core/IIS publishing procedure when the selected host requires it.
2. Expose HTTPS publicly and forward traffic to the API process/container using the port and hosting model required by that host.
3. Configure all required variables above using the provider's secret/configuration interface.
4. Configure a persistent, stable API base URL ending in `/api/v1`.
5. Configure the Angular Pages workflow secrets `METRA_API_BASE_URL`, `METRA_SUPABASE_URL`, and `METRA_SUPABASE_ANON_KEY`. The anon/publishable key is client-visible by design and must be protected by correct Supabase RLS; it is not a service-role key.
6. Configure Flutter with the same HTTPS API base URL and the appropriate Supabase publishable/anon client key through the mobile build configuration.

## Hosting selection status

No production host or deployment target has been approved in this repository. Do not create a hosting service, assume a provider, infer a hostname, or report deployment as complete until the target and its supported ASP.NET Core hosting model have been confirmed. Review any trial period, renewal cost, resource limits, persistent storage, secret management, HTTPS support, and deployment restrictions before committing to a provider.

The repository's previous Render-specific walkthrough has intentionally been removed from this guide. The presence of a container image or deployment workflow does not require using Render and does not mean a service has been created.

## Post-deployment verification

Run these checks against the real HTTPS host:

- `GET /api/v1/health` returns HTTP 200 and `status: healthy`.
- `GET /api/v1/ready` returns HTTP 200 and `status: ready` only after a live server-authenticated read from the station catalogue succeeds. Missing/invalid credentials, unreachable Supabase, or an unavailable catalogue projection must return HTTP 503.
- An invalid/missing bearer token cannot access protected station/observation routes.
- A valid authenticated user can read only the station directory allowed by the API policy.
- A user without station permission cannot submit or review an observation.
- An authorized test user can submit a clearly identified test observation; retrying the same idempotency key does not create a duplicate.
- Review/decision paths enforce the expected reviewer permission and audit trail.
- Browser requests from the configured origin succeed; unconfigured origins are rejected by CORS.
- Confirm no service-role key appears in client bundles, browser network responses, logs, or public repository files.

Use a dedicated test station/user and clearly marked test payload. Do not create fake meteorological observations in operational records.

## Database safety

The new Supabase project is the target for this application. Keep the legacy database untouched. Review each migration before applying it, take a backup/restore point as appropriate, and never use destructive SQL as part of routine deployment. This guide does not apply migrations or alter database contents.
