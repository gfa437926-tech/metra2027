# Stage C9 — Release Candidate Readiness

## Decision
**Release Candidate for technical review: PARTIAL / CONDITIONAL**  
**Not Production Ready.**

### Ready for review
- .NET API with authz, rate limits, JWT constraints, security headers
- Isolated DB Path N + proposal packages (R4, unique grants) tested offline
- Flutter client archive path aligned; error code mapping; service readiness classification
- Documentation trail C2–C9

### Blockers before any production release
1. Hosted DB changes need explicit approval (R4 RPC + unique indexes)
2. Real archive service not enabled (503 by design)
3. Flutter full test suite not evidenced in CI/this sandbox
4. Branch not pushed; no green GitHub Actions URLs
5. Mock remains for AI/Climatol/forecast
6. Staging deployment never executed

## Environments
| Env | Config | Secrets |
|-----|--------|---------|
| Dev/Local | user-secrets / env for Supabase URL + service role (server only) | Never in Flutter |
| Flutter | `METRA_API_BASE_URL` HTTPS dart-define | No service role |
| Prod prep | same patterns; OpenApi:Enabled false unless gated | External secret store |
