# Staging smoke test (read-only)

Run this after an approved staging API host has been provisioned and configured.
The script sends only GET requests to:

- /api/v1/health — process liveness
- /api/v1/ready — server configuration and dependency readiness

It sends no SQL, migrations, observations, or other writes.

## Run

PowerShell:

```powershell
$env:METRA_STAGING_API_BASE_URL = "https://approved-staging-host.example/api/v1"
bash scripts/deployment/staging-smoke-test.sh
```

Use the real HTTPS hostname issued by the hosting/IT owner; the example
hostname is deliberately non-operational and must not be used.

The readiness endpoint is expected to return HTTP 200 with status=ready only
after server-side Supabase configuration and the station-catalogue probe succeed.
A 503 is a failed release gate, not a reason to bypass readiness.

## Current state

- No approved staging host, DNS name, deployment credentials, or test identity
  has been provided or verified in the repository.
- This script has not been run against a live staging environment.
- Docker image build and local/CI tests do not constitute deployment.
- After read-only health/readiness pass, run separate authenticated smoke tests
  using dedicated test accounts and a clearly identified non-operational test
  station/record. Confirm station isolation, review permissions, idempotency,
  audit behavior, CORS, and secret non-disclosure.
- Any hosted database migration still requires a separate review and explicit
  approval. The legacy database remains out of scope and untouched.
