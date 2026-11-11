# METRA 2027 — delivery status (honest)

**Latest delivery package:** `docs/operations/phase-h-delivery-package.md`  
**Branch tip reference at package authorship:** `work/legacy-ui-migration-audit` (see git log)  
**PR #11:** remains Draft until owner merge approval.

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


## Phase H
- Delivery package published: `docs/operations/phase-h-delivery-package.md`
- No production deploy performed in-repo
- No PR merge performed


## Operator path to production
See `docs/operations/OPERATOR-NEXT-STEPS-END-TO-END.md` (O1–O7).
Repository phases A–H are closed at the code/docs level; live cutover remains operator-gated.
