grant select on public.registration_requests to metra_api_runtime;
create policy registration_requests_api_runtime_read
  on public.registration_requests for select to metra_api_runtime using (true);