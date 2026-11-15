\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
  v_network_role iam.roles%ROWTYPE;
  v_auditor_id uuid;
  v_network_id uuid;
  v_expected text[] := ARRAY[
    'stations.read_all',
    'observations.read_all',
    'audit.read_all',
    'forecasts.read_all',
    'alerts.read_all',
    'recorder.read_all',
    'instruments.read_all'
  ];
  v_actual text[];
BEGIN
  SELECT * INTO v_network_role FROM iam.roles WHERE role_code = 'network_department_head';
  IF NOT FOUND OR v_network_role.role_state <> 'active' OR NOT v_network_role.is_system_role
     OR v_network_role.is_assignable OR v_network_role.is_requestable THEN
    RAISE EXCEPTION 'network_department_head_role_definition_invalid';
  END IF;

  SELECT id INTO v_auditor_id FROM iam.roles WHERE role_code = 'auditor' AND role_state = 'active';
  IF v_auditor_id IS NULL THEN RAISE EXCEPTION 'auditor_role_missing'; END IF;
  v_network_id := v_network_role.id;

  SELECT array_agg(p.permission_code ORDER BY p.permission_code) INTO v_actual
  FROM iam.role_permissions rp JOIN iam.permissions p ON p.id = rp.permission_id
  WHERE rp.role_id = v_auditor_id AND p.permission_code = ANY(v_expected);
  IF v_actual IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM unnest(v_expected) x) THEN
    RAISE EXCEPTION 'auditor_global_read_permission_set_incomplete';
  END IF;

  SELECT array_agg(p.permission_code ORDER BY p.permission_code) INTO v_actual
  FROM iam.role_permissions rp JOIN iam.permissions p ON p.id = rp.permission_id
  WHERE rp.role_id = v_network_id AND p.permission_code = ANY(v_expected);
  IF v_actual IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM unnest(v_expected) x) THEN
    RAISE EXCEPTION 'network_head_global_read_permission_set_incomplete';
  END IF;

  IF EXISTS (
    SELECT 1 FROM iam.role_permissions rp
    JOIN iam.permissions p ON p.id = rp.permission_id
    WHERE rp.role_id IN (v_auditor_id, v_network_id)
      AND (p.permission_code LIKE '%.write%' OR p.permission_code LIKE '%.manage%'
        OR p.permission_code IN ('roles.assign','permissions.grant','memberships.manage'))
  ) AND EXISTS (
    SELECT 1 FROM iam.role_permissions rp
    JOIN iam.permissions p ON p.id = rp.permission_id
    WHERE rp.role_id = v_network_id
      AND p.permission_code IN ('observations.create','stations.manage','forecasts.manage','alerts.manage')
  ) THEN
    RAISE EXCEPTION 'network_head_role_contains_unapproved_mutation_permissions';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'iam' AND t.relname = 'role_assignments'
      AND pg_get_constraintdef(c.oid) LIKE '%scope_type = ''global''%'
  ) THEN
    RAISE EXCEPTION 'global_role_assignment_scope_constraint_missing';
  END IF;
END $$;

ROLLBACK;
