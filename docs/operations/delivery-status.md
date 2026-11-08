# METRA 2027 — delivery status (honest)

## Code branch status (`work/legacy-ui-migration-audit`)

Implemented in repository (not proof of hosted production by itself):

- JWT dual validation path (JWKS + optional HS256 + Auth user fallback)
- Station-scoped authorization for observations, faults, support
- Observation lifecycle APIs (submit, queue, decide, return, resubmit)
- Equipment faults + support incidents APIs including detail GET
- Npgsql ops path with constrained role + transaction-local station context
- Angular/Flutter clients wired for core operational flows
- Isolated SQL tests for fault/support station isolation and audit immutability
- Backend + Client CI green on recent tips

## Explicitly NOT complete without operator environment

- Hosted Supabase migration apply (requires `METRA_OPS_DATABASE_URL` in secret store)
- Staging/production publish of API + Angular + Flutter distribution
- Live E2E with real accounts/stations
- Merge of PR #11 to `main` (human decision)
- Legacy INSERT database remains untouched by design

## Policy

- Never touch the legacy INSERT database
- Never put service-role or DB passwords in Angular/Flutter
- Do not declare production readiness solely from green CI
