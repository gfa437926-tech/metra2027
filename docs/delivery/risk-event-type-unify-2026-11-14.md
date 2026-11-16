# Risk note — observation decision event_type unification

**Date:** 2026-11-14  
**Branch:** `work/execution-master-2026-11-14`  
**Proposal:** `database/proposals/20261114010000_unify_observation_decision_event_type.sql`

## Problem

Active function `metra_decide_observation` (from `supabase/migrations/20261103220500_...`) inserts the **command** token (`approve` / `return_for_correction`) into `metra_observation_audit_events.event_type`.

The table CHECK constraint only allows:
`created_draft | submitted | returned | approved | resubmitted`.

Any successful decision therefore fails the INSERT inside the same transaction, rolling back the status change. This is a release-blocking defect.

## Fix (owner-approved)

- Keep API/UI command vocabulary: `approve` | `return_for_correction`.
- Write both `status` and audit `event_type` as `approved` | `returned`.
- Permission keys unchanged (`observation.approve`, `observation.return_for_correction`).

## Change type

- `CREATE OR REPLACE FUNCTION` only.
- No table DDL, no data rewrite, no RLS change, no grant expansion.
- Rollback = re-apply the previous function body from the active migration.

## Testing

- Isolated SQL regression: `database/isolated/10_test_observation_decision_event_type.sql`
- Wired into the disposable PostgreSQL CI job (self-skips when bootstrap lacks observation tables).

## Production impact if applied later

- Requires the function to be replaced on the live project (explicit owner approval required).
- No existing audit rows use the illegal tokens (they could never have been inserted), so no backfill is needed.
- Downstream readers that expected the old command tokens in `event_type` would need a one-line mapping; none are present in the inspected Flutter/Angular clients.

## Explicit non-actions

- Not applied to any hosted Supabase project.
- Not merged to `main`.
- Scientific validation and operational submission gates remain closed.
