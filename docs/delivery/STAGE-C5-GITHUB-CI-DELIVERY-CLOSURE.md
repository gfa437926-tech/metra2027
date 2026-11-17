# Stage C5 — GitHub CI Delivery Closure (local preparation)

**Branch:** `work/backend-db-integration-phase`  
**Constraint:** No push/PR executed in this stage without separate explicit approval.

## C4 closure deltas (this delivery)
- Rate limiting applied across remaining write/read/sensitive feature endpoints (observations, validation, queue, stations, registration, assignments, audit, users).
- JWT: `ValidAlgorithms = RS256, ES256`; `RequireExpirationTime` retained.
- OpenAPI: Development **or** `OpenApi:Enabled=true` (not silent production exposure).
- HTTP pipeline contract tests: 401 on protected routes, health/ready, malformed bearer.

## CI jobs already defined in `backend-ci.yml`
- build + `dotnet test`
- `isolated-archive-authz`
- `path-n-empty-db`
- `grant-uniqueness-isolation`

## Delivery checklist before push (operator)
1. Explicit approval to push `work/backend-db-integration-phase`.
2. `git push -u origin work/backend-db-integration-phase`
3. Open **Draft** PR; do not merge.
4. Capture Actions run URLs for Backend build jobs.
5. Confirm no workflow writes to hosted Supabase.

## Not done here
- Actual `git push` / PR creation
- Hosted R4 / unique index apply
- Archive 503 removal
