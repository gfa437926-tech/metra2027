-- Path N compatibility for migration 022
-- Target: database/migrations/022_harden_authority_access_revocation_and_audit_index.sql
-- Conflict: original DROP CONSTRAINT permission_grants_revocation_check fails when constraint absent (Path N baseline).
-- Business rule preserved: revoked_at IS NULL OR revoked_at >= created_at
-- Path H: apply original 022 when upgrading schemas that already had the constraint.

CREATE INDEX IF NOT EXISTS authority_access_audit_actor_time_idx
  ON public.authority_access_audit_events(actor_user_id, occurred_at DESC, id DESC);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'permission_grants_revocation_check'
      AND conrelid = 'public.permission_grants'::regclass
  ) THEN
    ALTER TABLE public.permission_grants
      ADD CONSTRAINT permission_grants_revocation_check
      CHECK (revoked_at IS NULL OR revoked_at >= created_at);
  END IF;
END $$;
