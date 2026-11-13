# METRA Backend — Local Development

## Prerequisites
- .NET SDK **10.0.x**
- Optional: Docker (API container build in CI)
- Optional: PostgreSQL 16 for Path N / isolated SQL suites

## Build and test
```bash
dotnet restore backend/Metra.Api/Metra.Api.csproj
dotnet build backend/Metra.Api/Metra.Api.csproj -c Release
dotnet test backend/Metra.Api.Tests/Metra.Api.Tests.csproj -c Release
```

## Configuration
Do **not** commit service role keys. Local overrides via user-secrets or environment:
- `Supabase:Url`
- `Supabase:ServiceRoleKey`
- `Authentication:Authority`
- `Authentication:Audience` (default `authenticated`)

Without Supabase configuration, authority/registration RPC endpoints return unavailable; JWT auth still validates against configured authority.

## Isolated PostgreSQL
```bash
export PATH_N_DATABASE_URL=postgres://metra_test:metra_test_isolated@127.0.0.1:5432/metra_path_n
bash database/baseline/path_n_apply.sh
# Optional proposals (local only):
psql "$PATH_N_DATABASE_URL" -f database/proposals/c25_readiness/02_r4_apply.sql
psql "$PATH_N_DATABASE_URL" -f database/proposals/c25_readiness/04_grant_unique_apply.sql
psql "$PATH_N_DATABASE_URL" -f database/isolated/05_grant_uniqueness_concurrency.sql
```

Archive HTTP remains **503** until a real archive service is approved.
