# myASP.NET Windows/IIS deployment checklist

This is a provider-specific deployment checklist for the METRA API. It supplements, and does not replace, the container-host deployment path in [DEPLOYMENT.md](../DEPLOYMENT.md).

## Safety boundaries

- Deploy only to the new METRA site (currently identified in the hosting panel as `admin2027-001-site1`). Confirm the destination before syncing.
- Never upload a `.publishsettings` file, publish profile containing credentials, service-role key, or hosting password to GitHub or chat.
- Keep the legacy Supabase project untouched. The API must use the new project configured in this repository.
- Do not place `Supabase__ServiceRoleKey` in Angular, Flutter, public app settings, a checked-in file, or a deployment command/history.

## Confirm host support before upload

Ask the hosting provider to confirm all of the following for this Windows site:

1. ASP.NET Core 10 runtime and the matching ASP.NET Core Module (ANCM) are available.
2. The site supports an ASP.NET Core application deployed with the framework-dependent publish output.
3. The Web Deploy endpoint and site name supplied by the provider are valid for this site.
4. The application can receive environment variables through the hosting control panel (or an equivalent protected configuration facility).

The repository's published API targets `.NET 10`. A successful local publish or a reachable Web Deploy port does not prove that the hosting plan has the runtime/module required to start it.

## Publish artifact

From the repository root on Windows, the tested output directory is:

```text
artifacts\\metra-api
```

Deploy the **contents** of that directory to the provider's configured ASP.NET Core application root. Do not deploy the repository root, source tree, test project, or local secrets. Preserve the generated `web.config` from the publish output.

Use the provider's Web Deploy publishing profile or its documented deployment client. Do not copy a password into a PowerShell command, shell history, source file, or GitHub Actions log. If the provider's profile includes credentials, store it outside the repository and restrict access to the local Windows account.

## Required server configuration

Set these values using the hosting provider's protected environment/configuration interface:

| Key | Value |
| --- | --- |
| `Supabase__Url` | `https://tbdnklyxjvbrilvnwgmq.supabase.co` |
| `Supabase__ServiceRoleKey` | Secret service-role key for the **new** project; server only |
| `Authentication__Authority` | `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1` |
| `Authentication__Audience` | `authenticated` |
| `Cors__AllowedOrigins__0` | `https://gfa437926-tech.github.io` |

The existing `appsettings.json` lists local development origins only. Configure the exact production Angular origin above in the host environment. Add another origin only if an independently deployed client actually needs it.

## Verify after deployment

Use the real HTTPS hostname assigned by the provider; do not infer it from the site name.

1. `GET /api/v1/health` must return HTTP 200 and `status: healthy`.
2. `GET /api/v1/ready` must return HTTP 200 only when the API is configured and its server-authenticated Supabase station-catalogue probe succeeds. A 503 means configuration, connectivity, credentials, or catalogue access still needs attention.
3. Verify protected endpoints reject missing/invalid bearer tokens.
4. Verify CORS from the exact GitHub Pages origin.
5. Confirm service-role credentials never appear in browser responses, client bundles, logs, or public files.

Do not mark deployment complete until these checks have been run against the actual deployed URL.
