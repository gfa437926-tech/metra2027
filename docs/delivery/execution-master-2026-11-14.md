# Execution Master — 2026-11-14

Branch: `work/execution-master-2026-11-14`  
Base: `work/backend-db-integration-full-2026-11-13` @ `3c8ab32a004c135c523a4c3361dc7a3efcdbd3eb`

## Owner decisions applied

1. **event_type vocabulary** — final: `approved` | `returned` for audit + status.  
   API/UI commands remain `approve` | `return_for_correction`.
2. **Migrations** — proposed + isolated PostgreSQL tests only. No application to live Supabase.
3. **Scientific contract** — operational observation submission stays gated (`ObservationSubmission:ScientificContractApproved`). No invented formulas.
4. **Client** — Flutter only; Angular is not a delivery target for this execution stream.
5. **AI / Climatol / Forecast** — remain gated pending external keys and specs.

## Delivered in this commit

- Proposed migration: `database/proposals/20261114010000_unify_observation_decision_event_type.sql`
- Isolated regression: `database/isolated/10_test_observation_decision_event_type.sql`
- This progress note.

## Not done (and not claimed)

- Application of any migration to hosted Supabase.
- Merge to `main`.
- Scientific field validation beyond structural checks.
- Live AI / Climatol / forecast execution.

## Next safe steps

1. Wire the proposed migration into the disposable PostgreSQL CI job (when the job is present on this branch).
2. Complete Flutter decision UI wiring to the existing `/decision` endpoint (command tokens unchanged).
3. Continue non-scientific Flutter screens and API contract tests.
