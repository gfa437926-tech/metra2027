# Legacy INSERT observation import — 2026-11-03

## Safety boundary

- Source project: legacy INSERT, Supabase project `vktcvkwqszehgmhqjrkb`.
- Destination project: METRA 2027, Supabase project `tbdnklyxjvbrilvnwgmq`.
- The legacy project was accessed with SELECT-only queries. No write, DDL, policy, trigger, or configuration operation was issued against it.
- Imported rows are stored in `public.metra_observation_records` with `source_system='INSERT'`; original source table and record identifier are retained.
- Imports use `ON CONFLICT (source_system, source_table, source_record_id) DO NOTHING`, making repeated transfers safe.
- User IDs, user names, email addresses, role labels, observer names/roles, user-agent strings, browser language, observer IDs, and free-text observer notes are excluded from imported JSON payloads.
- Records with uncertain station-name matches remain unlinked. Exact matches and the explicitly reviewed aliases below are linked to the new station catalogue.
- Source timestamps are preserved as provided; local-hour fields remain inside payload and are not silently interpreted as UTC.

## Verified source-to-destination counts

| Source table | Destination observation type | Source rows | Destination rows |
|---|---:|---:|---:|
| `daily_reports` | daily | 3,760 | 3,760 |
| `hourly_reports` | hourly | 32,084 | 32,084 |
| `climate_reports` | climate | 1,420 | 1,420 |
| `agricultural_reports` | agricultural | 176 | 176 |
| `fieldclimate` | fieldclimate | 19,764 | 19,764 |
| `soil_temperatures` | soil | 801 | 801 |
| `weather_phenomena` | phenomenon | 54 | 54 |
| **Total** | | **58,059** | **58,059** |

The one row in legacy `weather_records` is a `connection_test` fixture, not a meteorological observation, and was intentionally not imported. `rainfall_reports` contained zero rows at inspection.

## Station linkage and reconciliation

- 56,808 of 58,059 observations currently link to a station; 1,251 remain unlinked rather than being attached to an incorrect station.
- Exact source station names were matched against the imported station catalogue.
- Reviewed aliases applied: `محطة حمص → حمص`, `مطار دمشق → مطار دمشق الدولي`, `محطة اللاذقية → اللاذقية`, `محطة السويداء → السويداء`, and `محطة طرطوس → طرطوس`.
- Unresolved labels include `مطار اللاذقية`, `غير محدد`, `محطة حلب`, `الكريم`, and one daily row with no station name. These require owner review; they were not guessed.
- All 54 weather-phenomena records now preserve their original station label and link to the catalogue where the name is deterministically matched.

## Validation snapshot

- Source counts and destination counts agree for all seven migrated tables.
- Destination count: 58,059.
- Duplicate source identities: 0 (enforced by the source identity unique index).
- Payloads containing user identity, observer identity, or free-text observer-note keys: 0.
- Imported records marked as demo: 0.
- Security advisor on the METRA destination: zero findings.
- The destination observation table denies direct `anon` and `authenticated` client access; access is intended through the trusted backend.

## Security note about the legacy source

Supabase's security advisor reports 22 legacy public tables with RLS disabled. Per the user's explicit instruction, no changes were made to INSERT. Keep this project isolated and do not expose its client API or anon key to untrusted clients. This warning is documented here without changing the legacy database.

## Remaining data-quality work

- Review the 1,251 unlinked observations and add station aliases only after authoritative owner confirmation.
- Validate measurement units/ranges and define retention rules for any remaining descriptive text.
- Run this report's integrity test after each future import.
- This import is a data migration milestone, not a claim that the whole METRA application is production complete.

### Unlinked-label breakdown verified on destination — 2026-11-03

A read-only grouped query over the 1,251 currently unlinked rows returned:

| Source table | Original station label | Rows |
|---|---|---:|
| hourly_reports | مطار اللاذقية | 999 |
| daily_reports | مطار اللاذقية | 102 |
| hourly_reports | غير محدد | 105 |
| hourly_reports | محطة حلب | 38 |
| hourly_reports | الكريم | 4 |
| climate_reports | دمشق | 1 |
| climate_reports | مطار اللاذقية | 1 |
| daily_reports | (missing) | 1 |

The catalogue currently contains a classic station named `اللاذقية`, but `مطار اللاذقية` is not among the five previously reviewed aliases. I deliberately did not equate an airport label with a city-station label without authoritative confirmation. Likewise, `محطة حلب` and `الكريم` remain unresolved. The unlinked records are preserved unchanged.
