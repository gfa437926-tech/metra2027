# FLT-008 — Legacy observation source audit (hourly and daily) — 2026-11-12

Repository: gfa437926-tech/metra2027  
Branch: fix/flutter-client-ci-mainline-2026-11-11  
Scope: static inspection of legacy source files only. This is a source inventory, not approval of scientific rules or a database migration specification.

## Hourly observation entry — inspected source

Sources: hourly_reports.html (form markup, inspected around lines 430–1480), submit-hourly.js (validation, payload construction and legacy persistence behavior), enhanced-validation.js (client formatting/validation behavior).

### Visible field groups and payload keys

| Group | Legacy field / payload key | Displayed unit or format in inspected markup |
|---|---|---|
| Basic | utcTime / utc_time | UTC hour, values 00–23 |
| Temperature | dryTemp / dry_temp | Signed dd.d °C |
| Temperature | wetTemp / wet_temp | Signed dd.d °C |
| Pressure | stationPressure / station_pressure | dddd.d millibar |
| Pressure | seaLevelPressure / sea_level_pressure | dddd.d millibar |
| Pressure tendency | pressureSlope / pressure_slope | d.d in legacy markup |
| Pressure tendency | pressureShape / pressure_shape | Code 0–8 |
| Derived humidity | relativeHumidity / relative_humidity | 3-digit percent |
| Derived humidity | vaporPressure / vapor_pressure | dd.d millibar |
| Derived humidity | dewPoint / dew_point | Signed dd.d °C |
| Derived humidity | vaporPressureDiff / vapor_pressure_diff | dd.d |
| Wind | windDirection / wind_direction | Code 00–36; label says tens |
| Wind | windSpeed / wind_speed | m/s |
| Wind | avgWindDirection / avg_wind_direction | Code 00–36; label says degrees |
| Wind | avgWindSpeed / avg_wind_speed | m/s |
| Visibility | visibility | Hundreds of metres |
| Weather | currentWeather / current_weather | Weather code |
| Weather | pastWeather / past_weather | Weather code |
| Clouds | totalCloudCover / total_cloud_cover | Cloud amount code |
| Clouds | cloud1Amount, cloud1Type, cloud1Height | Amount/type/height |
| Clouds | cloud2Amount, cloud2Type, cloud2Height | Amount/type/height |
| Clouds | cloud3Amount, cloud3Type, cloud3Height | Amount/type/height |
| Clouds | cloud4Amount | Additional cloud amount |
| Clouds | cover12, cover123 | Legacy cloud-cover combinations |
| Precipitation | precipitationAmount / precipitation_amount | Required at selected UTC synoptic hours 00, 06, 12, 18 |
| Notes | observerNotes / observer_notes | Free text |
| Attestation | responsibilityAgreement | Required checkbox; not part of the meteorological payload |

The legacy submission code also attaches user/station identity and generated report metadata. The new app must derive actor identity and station scope from the authenticated server context, not accept client-provided user IDs, names, roles or station names.

### Legacy validation and behavior observed

- # is accepted as a missing/unavailable marker by several client validators.
- The client checks dry-bulb temperature is not lower than wet-bulb temperature.
- The legacy submit handler marks temperature, pressure, humidity, wind, visibility, cloud and dew-point fields as required in selected cases.
- Precipitation is required by the legacy handler at UTC hours 00, 06, 12 and 18.
- Relative humidity, dew point, vapour pressure and vapour-pressure difference are represented as derived/related values; the authoritative psychrometric source, calculation version, rounding, and manual override policy are not established by these snippets.
- Some formatting/validation behavior is duplicated across multiple scripts. The original client-side rules are not sufficient to certify the domain contract.
- The legacy implementation can save a backup to browser localStorage and schedules synchronization. This is not approved for the new application; offline draft storage needs a separate threat model, encryption and conflict/idempotency design.

### Scientific questions still open before implementing the Flutter entry form

1. Confirm canonical field list and which fields are mandatory for each UTC observation hour.
2. Confirm UTC-to-local display mapping, observation date rollover and daylight/time-zone policy.
3. Confirm WMO code tables and exact semantics for current/past weather, cloud genera, cloud heights, pressure tendency and cloud combinations.
4. Confirm wind direction code convention and calm/variable/missing markers.
5. Confirm missing marker semantics (#, blank, trace T, and other special codes) per field; do not generalize one marker to every field.
6. Confirm valid numeric ranges, precision, rounding and unit conversions with authoritative tables.
7. Approve psychrometric lookup/calculation source and version; preserve dry/wet inputs and derived outputs with provenance.
8. Define review/return/approval state transitions and audit evidence for edits and resubmissions.

No production Flutter observation-entry screen should be marked complete until these decisions are represented in versioned domain/API contracts and executable tests.

## Daily reports screen — inspected source

Sources: daily_reports.html, daily_main.js, daily_validation.js.

The inspected daily_reports.html is primarily a daily-summary query/report screen, not proof of a complete daily observation-entry form. It exposes:
- Station, month and year filters.
- Load data (label explicitly says 24-hour reports only), clear filters and refresh station list.
- Summary cards: number of days, number of 24-hour reports, completion percentage and period.
- Dynamic report table.
- Excel export with symbols, Excel export without symbols, and print.

The file embeds a legacy Supabase project configuration and queries a legacy daily_reports table directly. It also falls back to sample station names after errors. Neither the embedded project configuration nor sample-data fallback may be copied into METRA 2027. The new client must call the approved .NET API and must display a clear error/empty state rather than substituting fictional stations or reports.

The inspected daily_validation.js references fields such as minimum/maximum temperature, precipitation, snow thickness, evaporation, sunshine duration/percentage, maximum gust speed/direction/time, and maximum/minimum humidity/time. It also describes report-type-dependent required fields (24h versus 06/18 reports) and a responsibility agreement. However, the exact corresponding authoritative entry form, full payload mapping, units and scientific code definitions still require source cross-checking. Do not treat the daily report query screen as that missing form.

## Security and migration boundary

- No legacy Supabase credentials/configuration are to be copied into Flutter, Angular or .NET.
- No browser localStorage identity is trusted as authorization evidence.
- No direct client database access or client-supplied actor identity is permitted.
- No historical data is synthesized when the API is empty or unavailable.
- No schema, INSERT policy, RLS, migration, permission grant or hosted database change was performed during this source audit.
- METRA OLD and the legacy database remain untouched.

## Next implementation gate

First obtain and index the authoritative requirements archive and the original daily/hourly field references. Then turn the verified field map into a versioned domain/API contract, field-level validation tests, permission tests and a single complete Flutter workflow. Do not build a form by copying the inconsistent legacy JavaScript behavior.