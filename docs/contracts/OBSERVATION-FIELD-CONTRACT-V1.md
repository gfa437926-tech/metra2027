# METRA Observation Field Contract v1

Status: implemented in the .NET API validation and submission boundary; client migration remains in progress.  
Contract version: `1.0`  
Applies to: hourly and daily observation submissions.

## Shared rules

- JSON field names use the exact camelCase identifiers below.
- Meteorological field values are sent as strings, not JSON numbers. This preserves fixed-width codes, signs, decimal precision, `#` missing-value markers, and `T/t` precipitation-trace codes.
- The authenticated station submission endpoint is authoritative. Calling a separate validation endpoint is optional for user experience and never bypasses validation on submission.
- `observedAt` is an ISO-8601 UTC timestamp at the envelope level. The hourly field `values.utcTime` is the two-digit UTC observation hour (`00`–`23`).
- The envelope station identifier is the station UUID in the route; station identity must not be trusted from client-supplied labels.
- The current implementation does not change any database schema or data.

## Submission envelope

The common API envelope remains:

```json
{
  "idempotencyKey": "client-generated-unique-key",
  "observationType": "hourly",
  "observedAt": "2026-11-08T00:00:00Z",
  "payload": {
    "values": {
      "utcTime": "00"
    }
  },
  "submit": true
}
```

The request is sent to:

`POST /api/v1/stations/{stationId}/observations`

The server checks the observation type, envelope, payload shape and size, then validates all hourly/daily fields before forwarding the write to the existing atomic persistence RPC. Invalid values return HTTP 400 with `error: invalid_observation_fields` and field-level `issues`.

## Hourly contract

Canonical payload:

```json
{
  "values": {
    "utcTime": "00",
    "dryTemp": "+25.0",
    "wetTemp": "+20.0",
    "dewPoint": "+18.5",
    "stationPressure": "1013.2",
    "seaLevelPressure": "1013.2",
    "relativeHumidity": "065",
    "windDirection": "18",
    "windSpeed": "12",
    "visibility": "050",
    "totalCloudCover": "4",
    "cover12": "4",
    "cover123": "5",
    "precipitationAmount": "000.0",
    "pressureSlope": "2.3",
    "pressureShape": "5",
    "pastWeather": "0"
  }
}
```

Always-required fields:

- `utcTime`: exactly two digits, 00–23.
- `dryTemp`, `wetTemp`, `dewPoint`: signed two-digit temperature with one decimal, e.g. `+25.0`.
- `stationPressure`, `seaLevelPressure`: four digits and one decimal.
- `relativeHumidity`: three digits.
- `windDirection`: two-digit code 00–36.
- `windSpeed`: two-digit code.
- `visibility`: three-digit code 000–200.
- `totalCloudCover`, `cover12`, `cover123`: one-digit cloud amount 0–8.

Conditional fields, derived only from `values.utcTime`:

- UTC 00, 06, 12, 18: `precipitationAmount`.
- UTC 00, 03, 06, 09, 12, 15, 18, 21: `pressureSlope`, `pressureShape`, `pastWeather`.

Recognized optional fields include `vaporPressure`, `vaporPressureDiff`, `avgWindDirection`, `avgWindSpeed`, `currentWeather`, `cloud1Amount`–`cloud4Amount`, `cloud1Type`–`cloud3Type`, and `cloud1Height`–`cloud3Height`. Their code/range rules are enforced where a validator rule exists.

The missing-value marker `#` is accepted by the field validator for fields where no observation is available. It does not excuse an omitted required key: required keys must be present, with an explicit value or `#`.

## Daily contract

Canonical payload:

```json
{
  "reportType": "24h",
  "responsibilityAgreement": true,
  "values": {
    "minTemp": "-05.3",
    "maxTemp": "25.7",
    "precipitation": "012.5",
    "snowThickness": "015",
    "evaporation": "12.5",
    "sunshineDuration": "08.5",
    "sunshinePercentage": "075",
    "maxGustSpeed": "15",
    "maxGustDirection": "25",
    "maxGustTime": "14.5",
    "maxHumidity": "085",
    "maxHumidityTime": "06.0",
    "minHumidity": "35",
    "minHumidityTime": "14.0",
    "precipitationTrace": "T"
  }
}
```

Supported `reportType` values and required fields:

| Report type | Required fields |
|---|---|
| `24h` | `minTemp`, `maxTemp`, `precipitation`, `snowThickness`, `evaporation`, `sunshineDuration`, `sunshinePercentage`, `maxGustSpeed`, `maxGustDirection`, `maxGustTime`, `maxHumidity`, `maxHumidityTime`, `minHumidity`, `minHumidityTime` |
| `06utc` | `minTemp`, `maxTemp`, `precipitation`, `snowThickness` |
| `18utc` | `minTemp`, `maxTemp`, `precipitation`, `snowThickness` |

Every daily submission must include `responsibilityAgreement: true`. The legacy `#` missing-value marker is preserved; `precipitationTrace` accepts `T` or `t`. The report type determines which fields are required; the UI should hide/disable fields that do not apply to 06/18 UTC reports, but the server remains authoritative.

## Validation endpoints

- `POST /api/v1/observations/hourly/validate`: `{ "values": { ... } }`
- `POST /api/v1/observations/daily/validate`: `{ "reportType": "24h", "responsibilityAgreement": true, "values": { ... } }`

The daily validation request now requires an allowed report type and responsibility acknowledgement, then selects the matching required-field set.

## UTC conversion

When a UI accepts the historical local observation hour (UTC+3), convert it as:

`utcHour = (localHour - 3 + 24) % 24`

Examples: local 00 → UTC 21 (previous UTC date), local 01 → UTC 22, local 02 → UTC 23, local 03 → UTC 00. The timestamp must account for the date rollover; do not merely replace the hour while keeping the same calendar date.

## Client migration requirements

- Angular and Flutter must share these exact field identifiers and envelope semantics.
- Client-side validation may mirror the contract for immediate feedback, but must not become the security boundary.
- Angular daily currently uses page-memory previews; it still needs a real API submission integration.
- Flutter hourly currently needs a full parity review against the canonical field list; Flutter daily entry is still missing.
- Add cross-client contract tests and UTC date-rollover tests before declaring parity.
