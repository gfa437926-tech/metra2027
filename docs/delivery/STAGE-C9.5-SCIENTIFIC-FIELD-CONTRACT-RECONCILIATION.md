# C9.5 — Scientific Field Contract Reconciliation

**Source archive:** `10-5-2026 برنامج ادارة البيانات الجوية مع الربط على.rar`  
**Source Git blob:** reviewed from the repository branch; archive extraction recovered 106 review files.  
**Extraction status:** two members were truncated/corrupt and could not be extracted.  
**Database boundary:** no legacy Supabase project was contacted; legacy connection/config files were excluded from the review artifact.  
**Decision:** hourly field validation can be enforced server-side; daily 06/18 UTC contract remains blocked by a source contradiction. No Flutter production submission is enabled yet.

## 1. Hourly observation contract

Primary source files:
- `pages/hourly/hourly_send/hourly_reports.html`
- `pages/hourly/hourly_send/enhanced-validation.js`
- `pages/hourly/hourly_send/hourly-send.js`
- `pages/hourly/hourly_send/submit-hourly.js`

The form uses a UTC hour selector from 00 through 23. The missing-data marker `#` is accepted by fields that explicitly support it.

| Field code | Format / range | Conditional requirement |
|---|---|---|
| `utcTime` | two digits, 00–23 | always required |
| `dryTemp`, `wetTemp`, `dewPoint` | signed dd.d; -20.0 to +50.0 in the extracted validator | dry temperature must be >= wet temperature |
| `stationPressure` | dddd.d; 850.0–1050.0 hPa | always required |
| `seaLevelPressure` | dddd.d; 0000.0–1050.0 hPa | always required |
| `relativeHumidity` | three digits; 001–100 | always required |
| `vaporPressure`, `vaporPressureDiff` | dd.d; 0.0–99.0 | optional |
| `windDirection`, `avgWindDirection` | two digits; 00–36 | surface direction required; average optional |
| `windSpeed`, `avgWindSpeed` | two digits; 00–99 m/s | surface speed required; average optional |
| `visibility` | three digits; 000–200 | always required |
| `currentWeather` | two digits; 00–99 | optional |
| `pastWeather` | one digit; 0–9 | optional (not required by the source form) |
| `totalCloudCover` | one digit; 0–8 | always required |
| `cloud1Amount`–`cloud4Amount` | one digit; 0–8 | optional |
| `cloud1Height`–`cloud3Height` | 1–3 digits; 0–999 (tens of metres) | optional |
| `cloud1Type`–`cloud3Type` | text cloud code | optional |
| `cover12`, `cover123` | one digit; 0–8 | required |
| `pressureSlope` | d.d or dd.d; 0.0–99.0 | optional (not required by the source form) |
| `pressureShape` | one digit; 0–8 | required at synoptic hours |
| `precipitationAmount` | ddd.d; 000.0–999.9 mm | required at 00, 06, 12, 18 UTC |

Conditional hours confirmed by the source:
- Precipitation: 00, 06, 12, 18 UTC.
- Pressure slope and pressure shape: 00, 03, 06, 09, 12, 15, 18, 21 UTC. Past weather remains optional in the source form.

The backend `HourlyObservationValidator` already implements these conditions and field-level checks. The submission endpoint now invokes that validator before persistence.

### Remaining hourly UI parity

The current Flutter screen now exposes the distinct source fields, including UTC hour, average wind direction/speed, vapor pressure difference, pressure slope/shape, cloud-layer amount/type/height fields, and cover12/cover123. It sends the payload to the .NET submission endpoint. The psychrometric lookup table named in earlier requirements was not recovered from the archive or repository, so automatic RH/dew-point calculation remains unavailable and must not be fabricated. The unresolved -20..+50 versus -50..+50 temperature range remains a scientific approval blocker.

## 2. Daily observation contract

Primary source files:
- `pages/daily/daily_send/daily.html`
- `pages/daily/daily_send/daily_validation.js`
- `pages/daily/daily_send/daily_fields_control.js`
- `pages/daily/daily_send/daily_db.js`

| Field code | Format / range |
|---|---|
| `minTemp`, `maxTemp` | signed dd.d; -20.0 to +50.0; maximum >= minimum |
| `precipitation` | ddd.d; 000.0–999.9 mm |
| `snowThickness` | ddd; 000–999 cm |
| `precipitationTrace` | optional T/t |
| `evaporation` | dd.d; 00.0–99.9 mm |
| `sunshineDuration` | dd.d; 00.0–24.0 hours |
| `sunshinePercentage` | ddd; 000–100% |
| `maxGustSpeed` | dd; 00–36 m/s |
| `maxGustDirection` | dd; 00–36 |
| `maxGustTime` | dd.d; 00.0–23.9 |
| `maxHumidity` | ddd; 000–100% |
| `maxHumidityTime` | dd.d; 00.0–23.9 |
| `minHumidity` | dd; 00–99% |
| `minHumidityTime` | dd.d; 00.0–23.9 |

The 24-hour report displays the weather phenomena checkboxes and the evaporation/sunshine, wind and humidity sections. The `#` marker is accepted where the source field supports missing data. The backend validator now checks the min/max temperature relationship and the min/max humidity relationship.

### Daily 06/18 UTC contradiction — release blocker

The recovered source contains conflicting behavior:
1. `daily_fields_control.js` hides the phenomena, evaporation/sunshine, wind and humidity sections for 06/18 UTC and displays a message that only temperatures and precipitation are entered.
2. `daily_validation.js` still requires `minTemp`, `maxTemp`, `precipitation` and `snowThickness` for non-24-hour reports.
3. `daily_db.js` serializes `precipitation`, `snowThickness` and `precipitationTrace` as null for non-24-hour reports.

These statements cannot all be true simultaneously. The API therefore rejects 06utc and 18utc submissions with a field-contract validation error until the meteorological owner resolves the conflict. It does not guess which values should be stored or discarded.

### Remaining daily UI parity

The current Flutter screen now exposes the 24-hour report-type selector, precipitation trace, individual gust direction/time, humidity times, and weather-phenomena checkboxes. The 06/18 UTC options remain disabled because the source contract is contradictory. The 24-hour form calls the .NET submission endpoint, but staging verification and scientific-owner approval remain outstanding.

## 3. Server-side submission guard

The .NET submission endpoint now:
- validates hourly payloads with `HourlyObservationValidator`;
- requires an explicit daily report type and validates 24-hour payloads against the required field set;
- rejects 06/18 UTC daily payloads while the source conflict remains unresolved;
- rejects client-supplied server-owned identity/workflow fields such as user ID, station ID, status and approval metadata;
- returns HTTP 422 with field-level validation issues before calling the database persistence RPC.

The hourly and daily 24-hour Flutter screens call this endpoint, but persistence is fail-closed by default. The deployment must explicitly set `ObservationSubmission:ScientificContractApproved=true` only after the meteorological owner signs off on the temperature range and the remaining scientific contract. Missing, malformed, or false configuration returns HTTP 409 (`scientific_contract_not_approved`) before the database RPC is called.\n\nThis validation runs before the atomic persistence RPC. The current Flutter hourly and daily 24-hour screens call the .NET endpoint and report server acceptance only after a successful API response. This is not evidence of a completed staging or production rollout; the unresolved scientific range, psychrometric method, and 06/18 UTC contract remain blockers.

## 4. No-go items still requiring approved external inputs

- Confirm whether hourly temperatures use -20..+50 or -50..+50; the extracted validator uses -20..+50 while an earlier requirements note records -50..+50.
- Supply the approved psychrometric lookup table or an approved calculation method.
- Resolve the 06/18 UTC daily conflict described above.
- Verify complete Flutter field parity against the authoritative source and run end-to-end staging tests before enabling production writes.
- Configure a non-production staging environment and real identity-provider test credentials.
- Do not reuse legacy station identifiers or legacy database configuration.

## 5. Change and approval boundary

This report records source extraction and contract reconciliation. The legacy database was not accessed or changed. No hosted Supabase schema/RPC was modified, no staging deployment occurred, and no PR was merged.
