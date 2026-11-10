-- REVIEW ONLY — do not apply to hosted Supabase without explicit owner approval.
-- Manual Excel archive confirmation ledger (administrative metadata only).
-- Does NOT store observation payloads and does NOT connect to any archive database.

-- create table public.metra_manual_archive_confirmations (
--   id uuid primary key default gen_random_uuid(),
--   station_id uuid not null references public.station_catalogue(id),
--   actor_user_id uuid not null,
--   report_kind text not null,
--   period_start_utc date not null,
--   period_end_utc date not null,
--   excel_file_name text not null,
--   note text,
--   confirmed_at_utc timestamptz not null default timezone('utc', now()),
--   constraint metra_manual_archive_period_chk check (period_end_utc >= period_start_utc),
--   constraint metra_manual_archive_kind_chk check (report_kind in ('hourly','daily','monthly','rainfall','climate','other'))
-- );
-- create unique index metra_manual_archive_dedupe_idx
--   on public.metra_manual_archive_confirmations (
--     station_id, lower(report_kind), period_start_utc, period_end_utc, lower(excel_file_name)
--   );
-- revoke all on public.metra_manual_archive_confirmations from anon, authenticated;
-- -- service_role / ops role grants and RLS policies TBD with owner approval.

select 'manual_archive_ledger_review_only: placeholder — not applied' as status;
