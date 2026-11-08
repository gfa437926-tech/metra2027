-- Non-destructive rollback / disable plan for the METRA Equipment Faults feature.
-- This script intentionally preserves all fault and audit data and leaves all
-- newly-created tables, indexes, constraints, and triggers in place.
-- It removes runtime access only. Do not DROP tables as part of routine rollback.

begin;
revoke metra_equipment_faults_runtime from metra_equipment_faults_login;
alter role metra_equipment_faults_login nologin;
revoke all on public.equipment_faults, public.equipment_fault_audit
  from metra_equipment_faults_runtime, metra_equipment_faults_login;
revoke all on sequence public.equipment_fault_audit_id_seq
  from metra_equipment_faults_runtime, metra_equipment_faults_login;
commit;

-- Re-enable procedure:
-- 1) restore the exact grants from the reviewed migration;
-- 2) restore role membership with INHERIT FALSE, SET TRUE, then ALTER ROLE metra_equipment_faults_login LOGIN;
-- 3) verify the externally managed login password and secret reference;
-- 4) run RLS/permission smoke tests before routing traffic.
--
-- Data-retention / eventual full removal:
-- Only after an explicit retention decision and a verified backup, export both
-- tables, verify the export, and request separate approval for destructive DROP.
