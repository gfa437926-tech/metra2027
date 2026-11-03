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
- 12 imported catalogue records have no current coordinate because the source did not contain a complete coordinate pair. No coordinates were guessed.
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
- The observation history was subsequently migrated in a separate, privacy-filtered milestone: 58,059 records are now in the new observation store. See `docs/delivery/LEGACY-OBSERVATION-IMPORT-2026-11-02.md` for counts, station-link coverage, and remaining reconciliation.


## Observation migration milestone — 2026-11-03

- Imported and verified 58,059 meteorological observations in `public.metra_observation_records` across daily, hourly, climate, agricultural, FieldClimate, soil-temperature, and weather-phenomena sources.
- Destination counts now match source counts for all seven migrated tables.
- 56,808 observations are linked to stations. 1,251 remain unlinked for owner-reviewed reconciliation; uncertain station aliases were not guessed.
- Applied five documented, explicit station aliases after source-label review.
- Removed user IDs, names, email addresses, role labels, observer names/roles, observer notes, user-agent, browser-language, observer IDs, and validation metadata from payloads. Verification found zero remaining identity/observer metadata keys.
- Used idempotent source identity keys; zero duplicate source identities remain.
- The one legacy `weather_records` row is a connection-test fixture and was intentionally excluded. `rainfall_reports` was empty at inspection.
- Added/updated `supabase/tests/observation_import_integrity.sql` and `docs/delivery/LEGACY-OBSERVATION-IMPORT-2026-11-02.md`.
- The legacy INSERT database was queried read-only throughout. All writes were directed only to the new METRA database.
- METRA destination security advisor returned zero findings. The legacy project's advisor reports 22 public tables with RLS disabled; no remediation was applied there under the user's no-modification instruction.

## CI verification and current operational snapshot — 2026-11-03

### Pull-request commit verification
- Verified commit: `14229274f8eea44d9dc9aa674af3507404b027ee`.
- GitHub Actions results for this exact commit:
  - Backend build: **success**.
  - ASP.NET Core 10 build and tests: **success**.
  - Angular dependency audit, test-source type check, unit tests and production bundle: **success**.
  - Flutter dependency resolution, Dart formatting, analysis and tests: **success**.
- The preceding Flutter run on `82771e15ed68c5d355ac780ef16d7879fe9e13f7` failed the formatting gate. The test file was formatted in the verified commit above; the subsequent complete Flutter workflow passed.
- Verified test totals from the workflow logs: **548 .NET tests**, **12 Angular unit tests**, and **5 Flutter tests**, all passed with zero failures. Angular production bundle also completed successfully.
- CI emitted maintenance warnings for deprecated Node.js 20-based GitHub Actions and a deprecated npm transitive package; these did not fail the build and remain dependency/toolchain cleanup items.
- PR #1 remains open and draft. These CI results do not mean the PR is merged or the system deployed.

### Live METRA database verification
Read-only verification against `tbdnklyxjvbrilvnwgmq` returned:
- Observation records: **58,059**.
- Station catalogue rows: **65** (62 imported, unverified records and 3 explicitly marked demo).
- Imported stations with current coordinate records: **50**; without current coordinate records: **12**.
- Observation records linked to stations: **56,808**; unlinked: **1,251**. No station mapping is inferred for the unresolved records.
- A fresh payload scan found **zero** observation rows containing the checked identity/contact keys (user IDs, email, names, role and observer/browser metadata).
- Security Advisor: **zero findings**.
- Browser roles `anon` and `authenticated` have no direct table grants on the protected operational and identity tables. Protected reads must remain behind the trusted backend.

### Remaining production gates
The station routes are still deliberately unavailable until the trusted PostgreSQL read adapters and actor/permission/station-scope checks are implemented and registered. The 65 station rows are not an assertion that all imported stations are approved or operational. The 12 missing coordinate records must remain unplotted until verified source coordinates are supplied. The 1,251 unlinked observations require evidence-backed reconciliation. No production deployment or 100% completion is claimed.

## Coordinate coverage audit — 2026-11-03

Read-only query against the destination catalogue and effective coordinate table found:

| Station type | Catalogue rows | Rows with coordinates | Pending review |
|---|---:|---:|---:|
| Classic | 30 | 17 | 30 |
| Automatic | 34 | 33 | 34 |
| Synoptic | 1 | 0 | 1 |
| **Total** | **65** | **50** | **65** |

The 13 classic records without coordinate rows comprise 12 imported source records plus the explicitly marked demo row. The 12 source records requiring authoritative coordinate evidence are: مركز بحوث الغاب، صحنايا، البوكمال، دير الزور، حمام واصل، الإدارة العامة، درعا، بوقا، حلب الجامعية، زاهد، عين العرب الجنوبية، ومحطة حماه.

All 65 records remain pending and unverified. A station without a complete verified coordinate pair remains in the directory/list but must not be plotted. No coordinates were guessed or inserted in this audit.

### Coordinate provenance and validity audit — 2026-11-03

All 50 stored coordinate rows currently have `coordinate_source=other`, a non-empty source reference, and an effective validity window that has started and has not expired. This confirms provenance fields and temporal shape are populated; it does **not** certify the source itself or the positional accuracy. Coordinates and their station records remain pending owner review.

The same audit found that all 50 rows have distinct source references, but `accuracy_m` is null on all 50. Do not interpret a present coordinate or provenance string as a surveyed/verified coordinate; positional accuracy still needs an authoritative value or explicit owner validation.
