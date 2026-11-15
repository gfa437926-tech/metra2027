
revoke all on function private.decide_metra_registration(
  uuid,text,uuid,text,text,timestamptz
) from public,anon,authenticated,service_role;
grant usage on schema private to metra_api_runtime;
grant execute on function private.decide_metra_registration(
  uuid,text,uuid,text,text,timestamptz
) to metra_api_runtime;
