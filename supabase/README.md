# METRA 2027 station catalogue database

This directory contains the migration history for the independent station catalogue and identity model in Supabase project `tbdnklyxjvbrilvnwgmq`.

## Migration sequence

1. `20261102154652_create_independent_station_catalogue.sql` — countries, meteorological authorities, station catalogue, verified/effective-dated coordinates, authority access grants, audit log, constraints and baseline RLS.
2. `20261102155101_index_station_catalogue_foreign_keys.sql` — indexes for foreign-key access paths.
3. `20261102155110_add_catalogue_integrity_triggers.sql` — maintained `updated_at` timestamps and append-only audit records.
4. `20261102155200_lock_station_catalogue_client_access.sql` — explicit deny-all policies for browser-facing roles until the reviewed authorization model is implemented.

## Identity schema

The database also stores METRA user profile names, account lifecycle state, authority memberships, exact station assignments and time-bounded permission grants. Account states align with the backend lifecycle contract. Reviewers must differ from requesters, and database exclusion constraints prevent overlapping pending/approved grants or assignments.

Nine migrations are recorded remotely and mirrored in this directory. The latest migrations add the identity model, explicit deny-all client policies, user profiles, account-state consistency and requester indexes.

## Security posture

- The station catalogue is the only intended operational source for station directory, map, search and filters.
- Historical/legacy station datasets are not imported, joined, or used as fallbacks.
- No public or authenticated browser role currently has table privileges. RLS is enabled and deny-all policies are installed.
- The Supabase `service_role` key must never be shipped to Angular, Flutter, or any public client.
- Do not grant client access until explicit account lifecycle, authority membership, station assignment, approval, and self-approval prevention rules have been implemented and tested.
- Backend database access must use a dedicated least-privilege runtime role, not a project owner or migration credential.
- Coordinates must be backed by an identified source; unknown coordinates remain null/unrecorded, never guessed.
- Do not seed invented country/authority/station records into production.

## Applying and verifying

Use the Supabase CLI linked to the intended project and inspect `supabase migration --help` before selecting commands. Compare remote migration history with these files before applying anything; the remote project was initially migrated through the Supabase management migration API. Never blindly replay migrations against an already-migrated database.

Temporal integrity uses PostgreSQL exclusion constraints backed by `btree_gist`: a station cannot have overlapping coordinate validity periods, and an authority cannot hold overlapping pending/approved access periods for the same station. Official-record coordinates require a source reference. Review timestamp and reviewer must be set together; non-pending decisions require a review reason.

After changes, verify table definitions, RLS and policies, indexes, triggers, exclusion constraints, migration history, and run Supabase security/performance advisors. The security advisor should report no missing RLS policy for all eleven tables.

## Current delivery boundary

The database schema and restrictive access posture are deployed. The API's station routes intentionally remain unavailable (503) until a trusted authorization-aware repository is registered. This prevents a superficially working but unauthorized station directory.
