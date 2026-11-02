# METRA 2027 — Station catalogue and identity foundation

**Updated:** 2026-11-02  
**Supabase project:** `tbdnklyxjvbrilvnwgmq` (eu-west-2)

## Completed and remotely verified

- The independent operational catalogue exists in PostgreSQL: countries, meteorological authorities, station catalogue, effective-dated station coordinates, authority station-access grants and append-only station audit log.
- Added account lifecycle state, authority memberships, exact station assignments and time-bounded permission grants, all linked to Supabase Auth users.
- Added composite station/authority ownership integrity for assignments.
- Added database checks for account/membership/assignment/permission states, validity windows, reviewer consistency, reason requirements and prohibition of self-approval.
- Added exclusion constraints to prevent overlapping pending/approved membership, station-assignment and permission periods for the same subject/resource.
- Added indexes for foreign-key and authorization lookup paths.
- Enabled RLS on all ten public tables. Browser roles `anon` and `authenticated` have no table privileges and explicit deny-all policies on the new identity tables; existing catalogue tables remain similarly locked.
- Added update timestamp triggers to mutable identity records.
- Expanded the append-only audit entity taxonomy for account state, authority membership, station assignment and permission grant events.
- All seven remote migrations are mirrored under `supabase/migrations/` with matching version prefixes.
- Supabase security advisor now returns **zero findings**.
- The performance advisor reports only unused-index notices on empty tables; no unindexed foreign keys remain after the latest indexes were added.
- Existing rollback-only station integrity checks remain in `supabase/tests/station_catalogue_integrity.sql`.
- Rechecked all ten tables: they exist, RLS is enabled and the catalogue/identity tables contain zero rows. This is intentional; no invented or legacy station data was loaded.

## Operational data rule

`station_catalogue` is the sole intended operational source for station directory, search, filters and map markers. Coordinates are separately stored with provenance and effective dates. A station without verified coordinates must remain visible in lists but must not be plotted at a fabricated location.

Historical/legacy station datasets are not an operational source. No legacy import, transformation, join, fallback or inferred identity mapping is authorized.

## Security and authorization boundary

The new tables provide persistence for account state, authority membership, station assignment and action permission facts. Their existence does **not** mean that authorization is complete. The backend must still load account state, permission, membership, station assignment and any station-level authority grant from one consistent database snapshot, validate all validity/revocation windows, enforce two-person review and emit an audit event in the same trusted transaction.

Browser clients remain denied. Never expose Supabase `service_role` or secret keys to Angular/Flutter. Do not enable the station API until a dedicated least-privilege backend database identity and a tested authorization-aware repository are configured.

## Remaining work before production handover

1. Build the Npgsql repositories and transaction-scoped authorization context against the new tables.
2. Implement account registration/review/suspension/recovery and identity-linking persistence.
3. Implement authority membership request/review, station assignment request/review, permission grant/revoke and self-approval prevention in application workflows.
4. Implement station create/edit/submit/review/approve/reject and coordinate versioning with immutable audit events.
5. Replace the Classic/Automatic prototype projection with the independent operational station model in API contracts and Angular screens.
6. Add the actual API endpoints for station catalogue, detail, map, administration and authorization-aware pagination.
7. Connect Angular to the protected API; never query the protected tables directly from the browser.
8. Complete Flutter sign-in, current-user context and feature workflows against the same API.
9. Add disposable PostgreSQL integration tests, authenticated end-to-end tests, concurrency tests and migration replay tests.
10. Load only verified country/authority/station data with source provenance after owner review. The station catalogue remains empty until that source material is approved.
11. Complete CI, dependency remediation, staging deployment, backup/restore rehearsal, monitoring and operational acceptance.

## Release status

- **Database and security foundation:** deployed and verified.
- **Identity persistence foundation:** deployed and verified structurally; application workflows and transaction-level enforcement remain.
- **Station records:** empty by design.
- **Backend API:** protected contracts exist; the trusted operational repository is not registered. Station routes must remain unavailable (503) rather than leak data or bypass authorization.
- **Angular:** station screen and query client exist; production API integration is not verified.
- **Flutter:** scaffold and identity-context client exist; full operational workflows are not complete.
- **Production release:** not ready. No merge, deployment or public preview is claimed.

## Remote migration history

- `20261102154652_create_independent_station_catalogue`
- `20261102155101_index_station_catalogue_foreign_keys`
- `20261102155110_add_catalogue_integrity_triggers`
- `20261102155119_lock_station_catalogue_client_access`
- `20261102163034_enforce_station_temporal_integrity`
- `20261102165436_add_identity_membership_and_station_assignment`
- `20261102165505_lock_identity_tables_and_index_foreign_keys`

Compare local files and remote history before any CLI push/pull. Never blindly replay or reset the project database.
