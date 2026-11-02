# METRA 2027 — Station catalogue and identity foundation

**Updated:** 2026-11-02  
**Supabase project:** `tbdnklyxjvbrilvnwgmq` (eu-west-2)

## Completed and remotely verified

- The independent operational catalogue exists in PostgreSQL: countries, meteorological authorities, station catalogue, effective-dated station coordinates, authority station-access grants and append-only station audit log.
- Added METRA user profiles, account lifecycle state, authority memberships, exact station assignments and time-bounded permission grants, all linked to Supabase Auth users.
- Added composite station/authority ownership integrity for assignments.
- Added database checks for account/membership/assignment/permission states, validity windows, reviewer consistency, reason requirements and prohibition of self-approval.
- Added exclusion constraints to prevent overlapping pending/approved membership, station-assignment and permission periods for the same subject/resource.
- Added indexes for foreign-key and authorization lookup paths.
- Enabled RLS on all eleven public tables. Browser roles `anon` and `authenticated` have no table privileges and explicit deny-all policies on the new identity tables; existing catalogue tables remain similarly locked.
- Added update timestamp triggers to mutable identity records.
- Expanded the append-only audit entity taxonomy for account state, authority membership, station assignment and permission grant events.
- All nine remote migrations are mirrored under `supabase/migrations/` with matching version prefixes.
- Supabase security advisor now returns **zero findings**.
- The performance advisor reports unused-index notices on empty tables only; the one remaining requester foreign-key index was added in the ninth migration.
- Existing rollback-only station integrity checks remain in `supabase/tests/station_catalogue_integrity.sql`. Read-only identity schema contract checks are in `supabase/tests/identity_schema_contract.sql` and passed against the remote project.
- Rechecked all eleven tables: they exist, RLS is enabled and the catalogue/identity tables contain zero rows. This is intentional; no invented or legacy station data was loaded.

## Operational data rule

`station_catalogue` is the sole intended operational source for station directory, search, filters and map markers. Coordinates are separately stored with provenance and effective dates. A station without verified coordinates must remain visible in lists but must not be plotted at a fabricated location.

Historical/legacy station datasets are not an operational source. No legacy import, transformation, join, fallback or inferred identity mapping is authorized.

## Security and authorization boundary

The new tables provide persistence for user profile names, account state, authority membership, station assignment and action permission facts. Account-state values now align with the backend lifecycle contract (`pending_station_approval`, `pending_system_approval`, `active`, `suspended`, `rejected`, `disabled`), and approved transitions require a distinct reviewer from the requester. Their existence does **not** mean that authorization is complete. The backend must still load account state, permission, membership, station assignment and any station-level authority grant from one consistent database snapshot, validate all validity/revocation windows, enforce two-person review and emit an audit event in the same trusted transaction.

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
- `20261102165724_add_user_profile_and_align_account_lifecycle`
- `20261102165758_index_account_state_requester`

Compare local files and remote history before any CLI push/pull. Never blindly replay or reset the project database.


## Follow-up engineering increment — 2026-11-02

- Added `.github/workflows/flutter-ci.yml` on the delivery branch. It installs Flutter stable, resolves dependencies, checks Dart formatting, runs `flutter analyze`, and executes the committed Flutter tests.
- The workflow was observed entering the GitHub Actions queue on commit `a97a07686d5e986e58f234ff429d57b866dfc2dd`; its final result must be checked before release.
- This adds automated mobile validation but does not complete mobile feature integration or establish a committed dependency lockfile.
- The current station HTTP endpoints remain intentionally fail-closed: `IStationCatalogueReadStore` and trusted identity context are not yet registered, so the endpoints return 503 rather than bypass authorization.
- Remaining release gates in this document are unchanged. Do not mark production complete until the trusted PostgreSQL repositories, transactional authorization/audit, verified station data, end-to-end tests, Flutter feature workflows, deployment and restore rehearsal are complete.


## Legacy INSERT read-only import — 2026-11-02

### Non-destructive boundary
- The legacy Supabase project `vktcvkwqszehgmhqjrkb` (INSERT) was queried using SELECT statements only.
- No DDL, INSERT, UPDATE, DELETE, TRUNCATE, policy, trigger, or settings change was issued against the legacy project.
- Destination was the independent METRA project `tbdnklyxjvbrilvnwgmq`.

### Imported station inventory
- 29 classic records from `public.stations`.
- 33 automatic records from `public.fieldclimate_stations`.
- 50 coordinate records were copied from source rows with both latitude and longitude present.
- 15 imported catalogue records have no current coordinate because the source did not contain a complete coordinate pair. No coordinates were guessed.
- 3 clearly synthetic demo catalogue records were added with `is_demo=true`.
- All 65 records are `approval_status=pending` and `operational_status=unverified`; no imported station was silently approved or marked operational.
- Classic and automatic station records remain separate and preserve their original source identifiers.

### Provenance and repeatability
- Added `source_system`, `source_table`, `source_record_id`, and `is_demo` to `public.station_catalogue`.
- Added a partial unique index over source identity so repeated seed execution cannot duplicate imported records.
- Added `unverified` as a station operational status to avoid falsely asserting live operational state.
- The committed repeatable seed is `supabase/seeds/20261102_station_catalogue_import.sql`.
- Matching schema migrations are committed under `supabase/migrations/` with versions `20261102171030` and `20261102171037`.

### Verification snapshot
- Destination catalogue: 62 imported + 3 demo = 65 records.
- Destination coordinates: 50.
- Supabase security advisors returned zero findings after these changes.
- Performance advisor returned informational unused-index notices; no indexes were removed.
- Legacy read-only count verification after import returned unchanged station counts: 29 classic and 33 automatic. The legacy weather/report data remained untouched.
- The full weather/report history has not yet been migrated. It requires dedicated table mappings, privacy/identity handling, data-quality validation, and explicit retention rules before bulk transfer.
