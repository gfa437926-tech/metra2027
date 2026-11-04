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
| `Authentication__Authority` | Recommended | `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1` |
| `Authentication__Audience` | No | Defaults to `authenticated` |
| `Cors__AllowedOrigins__0` | Yes for browser | Exact deployed Angular origin |
| `Cors__AllowedOrigins__1` | Optional | Additional exact origin, if needed |
| `ASPNETCORE_HTTP_PORTS` | No | Image defaults to `8080` |

Do not expose `Supabase__ServiceRoleKey` to GitHub Pages, Angular, Flutter, or end users. Do not add it to a Docker build argument or image layer.

For GitHub Pages, the browser origin is `https://gfa437926-tech.github.io`. Add other origins only when they are actually used. CORS is not an authentication mechanism.

## Host requirements

1. Run the published container image on a supported container host.
2. Expose HTTPS publicly and forward traffic to container port `8080`.
3. Configure all required variables above using the provider's secret/configuration interface.
4. Configure a persistent, stable API base URL ending in `/api/v1`.
5. Configure the Angular Pages workflow secrets `METRA_API_BASE_URL`, `METRA_SUPABASE_URL`, and `METRA_SUPABASE_ANON_KEY`. The anon/publishable key is client-visible by design and must be protected by correct Supabase RLS; it is not a service-role key.
6. Configure Flutter with the same HTTPS API base URL and the appropriate Supabase publishable/anon client key through the mobile build configuration.

No production host is currently specified in this repository. Do not infer one or report deployment as complete until a real host URL is supplied and verified.

## Render Blueprint setup

A repository-root `render.yaml` is provided for the API service. It uses the existing Dockerfile and build context, selects the Frankfurt region, binds the container to Render's public HTTP port, configures the exact GitHub Pages CORS origin, and uses the anonymous liveness endpoint for platform health checks.

To create the host:

1. Sign in to Render and choose **New → Blueprint**.
2. Connect `gfa437926-tech/metra2027` on branch `main` and select the repository-root `render.yaml`.
3. Review the service and pricing/plan shown by Render before creating it.
4. When prompted, provide the value for `Supabase__ServiceRoleKey` directly in Render's secret field. Never commit this value or paste it into chat.
5. Create the Blueprint and wait for the first deployment to finish.
6. Copy the actual `https://...` service URL assigned by Render. Do not assume a hostname from the service name.
7. Verify `/api/v1/health` and then `/api/v1/ready`. The health check only proves the process is responding; readiness must prove the server can reach the new Supabase station catalogue.
8. Add the real API base URL (ending in `/api/v1`) to the GitHub Pages repository secret `METRA_API_BASE_URL`, and configure the matching mobile build setting. Keep the Supabase publishable key separate from the server-only service-role key.

The Blueprint deliberately does not contain a service-role key. Render's `sync: false` prompts for it during initial Blueprint creation; if the Blueprint already exists, add or update the secret in the Render service's Environment settings. Creating this file in GitHub does not create a Render account, service, hostname, or deployment.

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
