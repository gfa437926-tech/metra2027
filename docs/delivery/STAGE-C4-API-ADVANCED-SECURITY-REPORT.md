# METRA 2027 — Stage C4 API Completion & Advanced Security

**Branch:** `work/backend-db-integration-phase`  
**Base:** `8da86c87f9467d7bf4af7281cd7ab03cbf2e55a3`

## Executed

### Rate limiting
- `backend/Metra.Api/Security/MetraRateLimiting.cs` — fixed-window policies:
  - anonymous probe 60/min (health, ready)
  - read 120/min (archive list)
  - write 40/min (reserved)
  - sensitive 15/min (authority membership/grants, registration)
- Partition: `sub` then IP (no trusted forwarded headers by default)
- HTTP **429** JSON `rate_limit_exceeded`
- Disable flag `RateLimiting:Disabled=true` for non-rate-limit test suites

### JWT
- `RequireExpirationTime = true` added alongside existing issuer/audience/lifetime/signing validation and 60s clock skew

### Endpoint annotations
- Rate limits on health/ready, archive, authority grant lifecycle, registration

### Tests
- `SecurityRegressionTests`: headers, 429 burst, unauthenticated archive → 401
- ApiAuthenticationTests disable rate limiting to avoid cross-test 429

### Docs
- `docs/backend/RATE-LIMITING-POLICY.md`
- `docs/backend/SECURITY-ARCHITECTURE.md`

## Results
| Suite | Result |
|-------|--------|
| `dotnet build` Release | Success |
| Full tests | **256 passed / 0 failed / 0 skipped** |

## Not claimed
- GitHub Actions green (branch not pushed)
- Hosted apply / Stage E / archive 503 removal / Flutter / Angular

## Residual
- Not every mutation route yet annotated with write/sensitive policies
- OpenAPI still Development-only MapOpenApi
- Full HTTP integration against real Supabase not in scope (isolated)
