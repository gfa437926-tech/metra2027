# Legacy INSERT observation import — 2026-11-02

## Safety boundary

- Source project: legacy INSERT, Supabase project `vktcvkwqszehgmhqjrkb`.
- Destination project: METRA 2027, Supabase project `tbdnklyxjvbrilvnwgmq`.
- The legacy project was accessed with SELECT-only queries. No write, DDL, policy, trigger, or configuration operation was issued against it.
- Imported rows are stored in `public.metra_observation_records` with `source_system='INSERT'`; the original table and record identifier are retained.
- Imports use `ON CONFLICT (source_system, source_table, source_record_id) DO NOTHING`, making the operation repeatable and non-destructive.
- User IDs, user names, email addresses, role labels, observer names/roles, user-agent strings, browser language, and observer IDs are excluded from imported JSON payloads.
- Source free-text meteorological notes and measurement fields are preserved as source payload. Review those notes under the application's privacy and retention policy before exposing them to users.
- Records with uncertain station-name matches remain unlinked. Only exact unique station-name matches are linked to the new station catalogue.

## Verified source-to-destination counts

| Source table | Destination observation type | Source rows | Destination rows |
|---|---:|---:|---:|
| `daily_reports` | daily | 3,759 | 3,759 |
| `hourly_reports` | hourly | 32,069 | 32,069 |
| `climate_reports` | climate | 1,420 | 1,420 |
| `agricultural_reports` | agricultural | 176 | 176 |
| `fieldclimate` | fieldclimate | 19,764 | 19,764 |
| `soil_temperatures` | soil | 801 | 801 |
| `weather_phenomena` | phenomenon | 54 | 54 |
| **Total** | | **58,043** | **58,043** |

The one row in legacy `weather_records` was inspected and identified as a `connection_test` fixture, not a meteorological observation, and was intentionally not imported. `rainfall_reports` contained zero rows at the time of inspection.

## Validation snapshot

- Source IDs were compared against destination source IDs for all seven migrated tables; the final comparison found no missing or extra IDs.
- Destination count: 58,043.
- Duplicate source identities: 0.
- Payloads containing the excluded identity keys: 0.
- Imported records marked as demo: 0.
- Security advisor: zero findings.
- The destination observation table denies direct `anon` and `authenticated` client access; access is intended through the trusted backend.

## Remaining data-quality work

- 13 records were linked to a station using exact, unique name equality. Ambiguous and unmatched names were deliberately left unlinked.
- The source observation date/time fields are retained in each JSON payload. Do not infer a UTC timestamp from local or free-text fields without a documented source timezone and parser.
- Before operational use, run a station alias reconciliation process with human review, validate measurement units/ranges, and define retention rules for observer notes.
- This import is a data migration milestone, not a claim that the whole METRA application is production complete.
