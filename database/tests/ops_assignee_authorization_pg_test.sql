-- Permission/assignee authorization proof against data-driven fixture permissions.
-- Runs only inside ops_station_isolation_pg_test.sql outer transaction.
DO $test$
DECLARE
  s_a constant uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  s_b constant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  actor constant uuid := '11111111-1111-1111-1111-111111111111';
  tech_ok constant uuid := '22222222-2222-2222-2222-222222222222';
  tech_no_permission constant uuid := '33333333-3333-3333-3333-333333333333';
  tech_other_station constant uuid := '44444444-4444-4444-4444-444444444444';
  actor_no_assign constant uuid := '55555555-5555-5555-5555-555555555555';
  fault_bad uuid := 'aaaaaaaa-0000-0000-0000-000000000001';
  fault_good uuid := 'aaaaaaaa-0000-0000-0000-000000000002';
  fault_actor_denied uuid := 'aaaaaaaa-0000-0000-0000-000000000003';
  incident_bad uuid := 'bbbbbbbb-0000-0000-0000-000000000001';
  incident_good uuid := 'bbbbbbbb-0000-0000-0000-000000000002';
  incident_actor_denied uuid := 'bbbbbbbb-0000-0000-0000-000000000003';
  v_state text;
  v_status text;
  v_assignee uuid;
  v_audit_before bigint;
  v_audit_after bigint;
BEGIN
  INSERT INTO public.station_catalogue(id,code,name)
  VALUES (s_a,'AUTH-A','Authorization Station A'),(s_b,'AUTH-B','Authorization Station B');
  INSERT INTO auth.users(id,email) VALUES
    (actor,'actor@test.invalid'),(tech_ok,'tech-ok@test.invalid'),
    (tech_no_permission,'tech-denied@test.invalid'),
    (tech_other_station,'tech-other@test.invalid'),
    (actor_no_assign,'actor-no-assign@test.invalid');

  INSERT INTO public.metra_test_station_permissions(user_id,station_id,permission_code) VALUES
    (actor,s_a,'equipment_fault.review'),
    (actor,s_a,'equipment_fault.assign'),
    (actor,s_a,'support_incident.review'),
    (actor,s_a,'support_incident.assign'),
    (tech_ok,s_a,'equipment_fault.update'),
    (tech_ok,s_a,'support_incident.update'),
    (tech_other_station,s_b,'equipment_fault.update'),
    (tech_other_station,s_b,'support_incident.update'),
    (actor_no_assign,s_a,'equipment_fault.review'),
    (actor_no_assign,s_a,'support_incident.review');

  INSERT INTO public.metra_equipment_faults(
    id,station_id,reporter_user_id,equipment_category,equipment_name,description,
    severity,status,occurred_at
  ) VALUES
    (fault_bad,s_a,actor,'Sensors','Bad target','Authorization test fault for rejected target', 'High','UnderReview',now()),
    (fault_good,s_a,actor,'Sensors','Valid target','Authorization test fault for valid target', 'High','UnderReview',now()),
    (fault_actor_denied,s_a,actor,'Sensors','Denied actor','Authorization test fault for denied actor', 'High','UnderReview',now());

  INSERT INTO public.metra_support_incidents(
    id,station_id,reporter_user_id,kind,category,title,description,severity,status,occurred_at
  ) VALUES
    (incident_bad,s_a,actor,'InformationTechnology','Network','Bad target support','Authorization test incident with denied assignee','High','UnderReview',now()),
    (incident_good,s_a,actor,'InformationTechnology','Network','Valid target support','Authorization test incident with valid assignee','High','UnderReview',now()),
    (incident_actor_denied,s_a,actor,'InformationTechnology','Network','Denied actor support','Authorization test incident with denied actor','High','UnderReview',now());

  -- Equipment fault: target without same-station update permission is rejected.
  SELECT count(*) INTO v_audit_before FROM public.metra_equipment_fault_audit_events WHERE fault_id=fault_bad;
  BEGIN
    PERFORM public.metra_transition_equipment_fault(actor,s_a,fault_bad,'Assigned',null,null,tech_no_permission);
    RAISE EXCEPTION 'TEST_FAIL: equipment fault accepted assignee without permission';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_equipment_faults WHERE id=fault_bad;
  SELECT count(*) INTO v_audit_after FROM public.metra_equipment_fault_audit_events WHERE fault_id=fault_bad;
  IF v_status <> 'UnderReview' OR v_assignee IS NOT NULL OR v_audit_after <> v_audit_before THEN
    RAISE EXCEPTION 'TEST_FAIL: rejected equipment assignee changed row or audit';
  END IF;

  -- A user with update permission only on another station is also rejected.
  BEGIN
    PERFORM public.metra_transition_equipment_fault(actor,s_a,fault_bad,'Assigned',null,null,tech_other_station);
    RAISE EXCEPTION 'TEST_FAIL: equipment fault accepted cross-station assignee';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;

  -- Authorized same-station technician is accepted.
  PERFORM public.metra_transition_equipment_fault(actor,s_a,fault_good,'Assigned',null,null,tech_ok);
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_equipment_faults WHERE id=fault_good;
  IF v_status <> 'Assigned' OR v_assignee <> tech_ok THEN
    RAISE EXCEPTION 'TEST_FAIL: valid equipment assignee was not persisted';
  END IF;

  -- Actor lacking equipment_fault.assign cannot assign even a valid technician.
  BEGIN
    PERFORM public.metra_transition_equipment_fault(actor_no_assign,s_a,fault_actor_denied,'Assigned',null,null,tech_ok);
    RAISE EXCEPTION 'TEST_FAIL: equipment assignment accepted actor without assign permission';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_equipment_faults WHERE id=fault_actor_denied;
  IF v_status <> 'UnderReview' OR v_assignee IS NOT NULL THEN
    RAISE EXCEPTION 'TEST_FAIL: denied equipment actor changed fault';
  END IF;

  -- Support incident: reject target without support update permission.
  SELECT count(*) INTO v_audit_before FROM public.metra_support_incident_audit_events WHERE incident_id=incident_bad;
  BEGIN
    PERFORM public.metra_transition_support_incident(actor,s_a,incident_bad,'Assigned',null,tech_no_permission);
    RAISE EXCEPTION 'TEST_FAIL: support incident accepted assignee without permission';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_support_incidents WHERE id=incident_bad;
  SELECT count(*) INTO v_audit_after FROM public.metra_support_incident_audit_events WHERE incident_id=incident_bad;
  IF v_status <> 'UnderReview' OR v_assignee IS NOT NULL OR v_audit_after <> v_audit_before THEN
    RAISE EXCEPTION 'TEST_FAIL: rejected support assignee changed row or audit';
  END IF;

  -- Cross-station support assignee is rejected.
  BEGIN
    PERFORM public.metra_transition_support_incident(actor,s_a,incident_bad,'Assigned',null,tech_other_station);
    RAISE EXCEPTION 'TEST_FAIL: support incident accepted cross-station assignee';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;

  -- Valid same-station support technician is accepted.
  PERFORM public.metra_transition_support_incident(actor,s_a,incident_good,'Assigned',null,tech_ok);
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_support_incidents WHERE id=incident_good;
  IF v_status <> 'Assigned' OR v_assignee <> tech_ok THEN
    RAISE EXCEPTION 'TEST_FAIL: valid support assignee was not persisted';
  END IF;

  -- Actor lacking support_incident.assign is rejected with no side effects.
  BEGIN
    PERFORM public.metra_transition_support_incident(actor_no_assign,s_a,incident_actor_denied,'Assigned',null,tech_ok);
    RAISE EXCEPTION 'TEST_FAIL: support assignment accepted actor without assign permission';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state <> '42501' THEN RAISE; END IF;
  END;
  SELECT status,assigned_to INTO v_status,v_assignee FROM public.metra_support_incidents WHERE id=incident_actor_denied;
  IF v_status <> 'UnderReview' OR v_assignee IS NOT NULL THEN
    RAISE EXCEPTION 'TEST_FAIL: denied support actor changed incident';
  END IF;

  RAISE NOTICE 'ops_assignee_authorization_pg_test: PASS';
END
$test$;
