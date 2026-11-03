# METRA 2027 — Station catalogue and identity foundation

**Updated:** 2026-11-03  
**Supabase project:** `tbdnklyxjvbrilvnwgmq` (eu-west-2)

## Completed and remotely verified

- The independent operational catalogue exists in PostgreSQL: countries, meteorological authorities, station catalogue, effective-dated station coordinates, authority station-access grants and append-only station audit log.
- Added METRA user profiles, account lifecycle state, authority memberships, exact station assignments and time-bounded permission grants, all linked to Supabase Auth users.
- Added composite station/authority ownership integrity for assignments.
- Added database checks for account/membership/assignment/permission states, validity windows, reviewer consistency, reason requirements and prohibition of self-approval.
- Added exclusion constraints to prevent overlapping pending/approved membership, station-assignment and permission periods for the same subject/resource.
- Added indexes for foreign-key and authorization lookup paths.
- Enabled RLS on all 15 public tables. Read-only audit confirms zero direct table grants to `anon` or `authenticated`; browser clients remain API-only.
- Added update timestamp triggers to mutable identity records.
- Expanded the append-only audit entity taxonomy for account state, authority membership, station assignment and permission grant events.
- All 28 applied remote migrations are mirrored under `supabase/migrations/` with matching version prefixes.
- Supabase security advisor now returns **zero findings**.
- The performance advisor reports unused-index notices on empty tables only; the one remaining requester foreign-key index was added in the ninth migration.
- Existing rollback-only station integrity checks remain in `supabase/tests/station_catalogue_integrity.sql`. Read-only identity schema contract checks are in `supabase/tests/identity_schema_contract.sql` and passed against the remote project.
- Rechecked all 15 public tables: RLS is enabled. The destination now contains 65 station catalogue rows (62 imported source rows plus 3 explicitly marked demo rows) and 58,059 imported observations. Identity lifecycle, membership, assignment, permission, registration request and audit tables remain empty; no synthetic active users, roles, permission grants or approvals were inserted.

## Operational data rule

`station_catalogue` is the sole intended operational source for station directory, search, filters and map markers. Coordinates are separately stored with provenance and effective dates. A station without verified coordinates must remain visible in lists but must not be plotted at a fabricated location.

The legacy project is not an operational runtime dependency and is never queried by the application. A one-time, privacy-filtered import from the user-authorized legacy source was performed using read-only source access and writes only to the new METRA destination. No ongoing fallback, live join, or guessed identity mapping is permitted.

## Security and authorization boundary

The new tables provide persistence for user profile names, account state, authority membership, station assignment and action permission facts. Account-state values now align with the backend lifecycle contract (`pending_station_approval`, `pending_system_approval`, `active`, `suspended`, `rejected`, `disabled`), and approved transitions require a distinct reviewer from the requester. Their existence does **not** mean that authorization is complete. The backend must still load account state, permission, membership, station assignment and any station-level authority grant from one consistent database snapshot, validate all validity/revocation windows, enforce two-person review and emit an audit event in the same trusted transaction.

Browser clients remain denied. Never expose Supabase `service_role` or secret keys to Angular/Flutter. Do not enable the station API until a dedicated least-privilege backend database identity and a tested authorization-aware repository are configured.

## Remaining work before production handover

1. Register the trusted Npgsql station catalogue/detail read store and enforce the owner-approved explicit catalogue-read permission plus station scope on every page. Until then, station endpoints remain 503.
2. Inspect Supabase Auth settings and signing-key mode, verify issuer/audience/JWKS using a real non-production access token, and only then activate the configured JWT bearer handler. No provider settings or signing keys were changed.
3. Provision the dedicated non-superuser, non-BYPASSRLS LOGIN for the API runtime role and a shared persistent ASP.NET Data Protection key ring; configure secrets only in the deployment environment.
4. Review the 62 imported station records and 3 demo rows. All 65 remain pending/unverified. Twelve imported classic stations have no coordinates; all 50 existing coordinate rows lack accuracy_m. No station can be promoted without authoritative owner review.
5. Reconcile 1,251 unlinked observations using owner-confirmed station aliases only. In particular, do not assume مطار اللاذقية is the same physical station as اللاذقية.
6. Select and approve a production basemap/tile provider. The Angular page currently offers a coordinate plot, explicitly not a geographic basemap; actual tile rendering and provider attribution remain pending.
7. Complete Flutter sign-in/token storage and wire the tested station client to the authenticated UI only after the API permission and repository gates are met. Its station feature flag remains false by default.
8. Add disposable PostgreSQL integration tests for both registration approval stages, transaction rollback, revocation races and audit append-only behavior; add authenticated end-to-end and map/pagination tests.
9. Complete staging deployment, backup/restore rehearsal, observability, performance tests and operational acceptance.

## Release status

- **Database/security foundation:** 15 public tables, all RLS-enabled; zero direct browser table grants; Supabase Security Advisor reports zero findings.
- **Identity persistence and approval:** database RPCs, least-privilege runtime role, registration submission and two-stage approval persistence are implemented. Runtime credentials and real identity-provider configuration remain deployment gates.
- **Station records:** 65 catalogue rows (29 imported classic, 33 imported automatic, 3 demo); all pending/unverified. Fifty coordinate rows exist; 12 imported classic rows lack coordinates.
- **Backend API:** identity registration/approval routes and authorization adapters exist. Station list/detail contracts are protected but intentionally return 503 until the trusted station read store and explicit read permission are approved and registered.
- **Angular:** unified classic/automatic directory, paged query client, filters and coordinate-only preview exist. The preview is not a basemap; production API access and map-provider integration are not complete.
- **Flutter:** current-user context and station catalogue client foundations exist; formatting, static analysis and 13 tests are being verified in CI. No real sign-in/token provider is wired.
- **Production release:** not ready. PR #1 remains a draft; no production deployment or public preview is claimed.

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
- The workflow now pins Flutter 3.47.9, enforces the committed pubspec.lock, checks Dart formatting, runs flutter analyze, and executes the Flutter tests.
- The lockfile is committed and enforced. The station API client foundation is tested, but no production token provider or enabled station feature flag exists.
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
