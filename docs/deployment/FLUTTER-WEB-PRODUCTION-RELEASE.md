# METRA Flutter Web production release

This workflow creates a **configured** Flutter Web release. The normal client CI
build intentionally uses empty compile-time configuration and is only a build
verification artifact; it is not a production deployment.

## Required GitHub Actions secrets

Configure these repository or environment secrets before running
`.github/workflows/flutter-web-release.yml`:

- `METRA_API_BASE_URL`: HTTPS origin of the deployed .NET API, without
  `/api/v1`, path, query, or trailing route.
- `METRA_SUPABASE_URL`: HTTPS origin of the approved new METRA Supabase project.
- `METRA_SUPABASE_PUBLISHABLE_KEY`: Supabase publishable/anon key only.

Never provide `Supabase:ServiceRoleKey` to Flutter or expose it as a build
secret. The .NET API receives its service-role credential only from the
hosting platform's server-side secret store.

## Build and download

1. Configure the three secrets above.
2. Run **Actions → Build configured METRA Flutter Web release → Run workflow**,
   or create a tag matching `metra-web-v*` after the reviewed code is merged.
3. Wait for dependency resolution, static analysis, tests, and the production
   Web build to pass.
4. Download the `metra-flutter-web-release` artifact from the successful run.
5. Extract the ZIP and publish the contents of `build/web` to an HTTPS static
   host. Configure the host to serve `index.html` for application routes.

The workflow validates the URLs and rejects a service-role key pattern. It
does not deploy the API, apply database migrations, provision users, or verify
that Supabase migrations have been applied. Those are separate release gates.

## Required server-side release gates

- Deploy the .NET container from the reviewed API image.
- Set `Supabase:Url` and `Supabase:ServiceRoleKey` in the API host's secret
  manager; never in source control or client configuration.
- Configure JWT issuer/audience, CORS allowed origins, HTTPS, logging, backups,
  and monitoring for the target environment.
- Verify `GET /api/v1/health` and `GET /api/v1/ready` from the deployed host.
- Apply only the reviewed database migrations to the **new** METRA project
  after explicit schema approval. Do not apply them to the legacy database.
- Run end-to-end tests using approved test accounts and station assignments
  before opening access to operational users.

A successful Flutter release build is not proof that unimplemented modules
(CLIMATOL, OCR/AI, image comparison, maintenance, network operations, and
reporting) are production-ready. Their completion must be verified separately.
