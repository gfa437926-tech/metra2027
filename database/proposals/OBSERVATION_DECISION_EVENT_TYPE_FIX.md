# Proposal: Align metra_decide_observation event_type with CHECK constraint

## Defect
Active migration `supabase/migrations/20261103220500_harden_observation_decision_null_validation.sql`
inserts `p_decision` (`approve` | `return_for_correction`) into
`metra_observation_audit_events.event_type`, while the table CHECK allows only
`created_draft`, `submitted`, `returned`, `approved`, `resubmitted`.

Any approve/return decision that reaches the audit INSERT will fail the CHECK and
roll back the transaction — blocking observation review in a clean schema.

## Proposed fix (not applied to hosted)
In the INSERT, use the mapped status token already computed as `v_status`:
- `approve` → `approved`
- `return_for_correction` → `returned`

## Hosted policy
Do **not** apply until owner approves and isolated PostgreSQL regression passes.
