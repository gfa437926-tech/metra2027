# METRA 2027 — Station catalogue delivery status

**Delivery date:** 2026-11-02  
**Scope:** independent operational station catalogue on Supabase project `tbdnklyxjvbrilvnwgmq`.

## Completed and remotely verified

- Created six PostgreSQL tables: `countries`, `meteorological_authorities`, `station_catalogue`, `station_coordinates`, `station_access_grants`, and `station_audit_log`.
- Added primary/foreign keys, uniqueness rules, validation checks, station approval states, effective-dated coordinate history, and time-bounded authority grants.
- Enabled RLS on all six public tables.
- Added explicit deny-all RLS policies for both `anon` and `authenticated` roles. No browser-role table grants are provided.
- Added foreign-key indexes.
- Added `updated_at` triggers to mutable catalogue/authority records.
- Added an append-only trigger to the audit log.
- Recorded four remote migrations and mirrored their SQL under `supabase/migrations/`.
- Supabase security advisor returned zero security findings after the RLS policies were installed.
- Re-queried the project: all six tables exist, RLS is enabled, and all six contain zero rows. No legacy station records were copied or joined.

## Data model and operating rules

`station_catalogue` is the intended sole operational source for station directory, search, filters, and map markers. Each station belongs to one country and one meteorological authority. Coordinates are separate, source-attributed, and effective-dated. A station without verified coordinates must not be plotted at an invented location.

The schema intentionally contains no classic/automatic legacy import, no legacy fallback, and no automatic station identity crosswalk. The station type is an extensible classification value, not a licence to infer coordinates or source provenance.

## Security boundary

Browser roles are denied access by both SQL grants and RLS policies. This is a deliberate fail-closed posture, not a temporary public-read configuration. Do not add permissive policies until the full identity model is implemented: active account lifecycle, explicit permission, authority membership, exact station assignment, validity windows, approval state, and prohibition of self-approval.

The audit log rejects UPDATE and DELETE. Server-side access must use a dedicated least-privilege runtime database identity. Never put a Supabase service-role or secret key in Angular or Flutter.

## Remaining work before production handover

1. Provision and verify a dedicated backend database role and secret-store connection; do not use the database owner credential at runtime.
2. Implement the Npgsql station read/write repositories against this exact schema, with actor context and authorization checks in the same trusted transaction boundary.
3. Implement station create/edit/submit/review/approve/reject and coordinate versioning workflows, including mandatory audit entries.
4. Implement authority membership and station assignment persistence, time-bound grant validation, two-person approval, and self-approval prevention.
5. Implement API pagination, filtering, search, map projection and detail endpoints using only `station_catalogue` and `station_coordinates`.
6. Connect the Angular catalogue screen to the protected API; do not query Supabase directly from the browser.
7. Add integration tests against a disposable PostgreSQL/Supabase test project for RLS, grants, approval transitions, audit immutability, concurrency and pagination.
8. Add authenticated end-to-end tests, then enable the station API feature flag only after all trusted dependencies are present.
9. Import only owner-approved station data with documented source, provenance, coordinates and validation report. Do not use the old station database.
10. Run .NET and Angular builds/tests, security/performance advisors, deployment smoke tests, backup/restore rehearsal and operational acceptance review.

## Current release status

**Database foundation: deployed and security-verified.**  
**Station records: empty by design.**  
**Backend API: protected route contracts exist, but the trusted data adapter is not yet registered; routes must remain unavailable (503) rather than returning untrusted or unauthorized data.**  
**Angular: station screen and query client exist, but production API integration is not yet verified.**  
**Production release: not ready.** No production deployment, PR merge, or public preview URL is claimed by this delivery.

## Migration reconciliation

The remote migration history is:

- `20261102154652_create_independent_station_catalogue`
- `20261102155101_index_station_catalogue_foreign_keys`
- `20261102155110_add_catalogue_integrity_triggers`
- `20261102155119_lock_station_catalogue_client_access`

Before using CLI push/pull, compare the local migration files and linked remote history; the remote project was migrated through the Supabase management migration interface. Never blindly replay or reset the production database.
