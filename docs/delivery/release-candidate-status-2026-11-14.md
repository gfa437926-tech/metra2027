# METRA 2027 — Release Candidate Status (2026-11-14)

Branch: `work/execution-master-2026-11-14`  
Latest SHA at write time: see branch tip.

## What is delivered and working in code

### Flutter (`mobile/metra_mobile`)
- Full RTL Arabic shell with adaptive navigation.
- Auth gate via Supabase Auth (publishable key only).
- Station directory (paged + full load), station selection required for scoped operations.
- Hourly and daily observation entry forms with structural validation.
- Observation review queue + decide (`approve` / `return_for_correction`) against real API.
- Observation archive list/detail client (station-scoped).
- Station audit log client.
- Reports hub, AI workspace, Climatol workspace, forecast centres — UI present and **explicitly gated** (no fake live data).
- User management screen shell.
- API client: stations, queue, decide, submit, archive, audit.
- Widget/unit tests present for API client, review, archive, forecast, readiness, etc.

### Backend (.NET `backend/Metra.Api`)
- JWT from validated `sub` (never trusts client-supplied user id).
- Station-scoped observation submit, review queue, decision endpoints.
- Station directory, audit, archive endpoints.
- Feature gates (fail-closed):
  - `ObservationSubmission:ScientificContractApproved`
  - `ObservationDecision:AtomicAuthorizationApproved`
- Rate limiting, CORS config surface, health/ready endpoints.
- Domain + API tests in `Metra.Api.Tests`.

### Database (PostgreSQL / Supabase migrations in repo)
- Operational observation tables + audit append-only design.
- Authority / membership / permission grant lifecycle migrations.
- Proposed (not applied) fix: event_type vocabulary unify to `approved`/`returned`.
- Isolated PostgreSQL test harness for archive authz, atomic reads, observation writes, grant uniqueness, and the new decision event_type regression.

## Explicit remaining blockers (owner action required)

| Blocker | Why it blocks “complete production” | Owner action |
|---------|-------------------------------------|--------------|
| Apply proposed `event_type` migration | Live decide RPC still inserts illegal tokens into CHECK | Approve apply to **staging** first, then production |
| Scientific contract | Submit stays 409 until flag true | Approve official field/range/psychrometric rules |
| Decision atomic authorization flag | Decide stays 409 until flag true | Confirm isolated tests green + set flag on host |
| Archive RPC applied to hosted DB | Archive endpoints fail-closed without RPC + grants | Approve staging apply of archive proposals |
| AI / Climatol / Forecast providers | External keys + licenses missing | Supply secrets out of Git + contracts |
| Production host secrets | Service-role key, CORS, API URL | Configure host only; never commit secrets |
| Merge to `main` + public release | Explicitly forbidden without final approval | Final sign-off |

## What will **not** be claimed

- Live production DB already has the fixed decide function.
- Scientific formulas were invented or operational submission is open.
- AI/Climatol/Forecast return real provider data without keys.
- Angular is part of the delivery target (Flutter only).

## Safe next sequence after this status

1. Open PR from this branch → wait for exact-head CI green.
2. Owner approves staging apply of event_type proposal only.
3. Owner supplies / approves scientific contract → flip submission gate.
4. Owner confirms decision authorization tests → flip decision gate.
5. Staging E2E with real accounts → then production apply under controlled change window.
6. Final approval to merge `main` and cut a release tag.
