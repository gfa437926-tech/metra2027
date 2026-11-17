-- METRA baseline 002 — identity STUB for isolated PostgreSQL tests only.
-- DO NOT use as a replacement for Supabase Auth on hosted projects.
-- Hosted projects must keep the real auth.users from Supabase Auth.

CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY,
  email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE auth.users IS
  'ISOLATED TEST STUB only. Hosted Supabase uses Auth-managed auth.users. Never seed production identities here.';
