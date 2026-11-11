# METRA — Legacy screen and field parity evidence (2026-11-09)

Reference source is the read-only legacy repository 'gfa437926-tech/metra-old' at commit
'12a96f301102fb75bd053dd7be188a04ed38b408'.
Modern source is 'gfa437926-tech/metra2027' on
'work/legacy-ui-migration-audit'.
This inventory compares source field identifiers and route presence; it is not
visual acceptance, operational data validation, or production sign-off.

## Hourly observation

Legacy source:
- pages/hourly/hourly_send/hourly_reports.html
- hourly-send.js, enhanced-validation.js, cloud-total-cover-validation.js

Legacy fields found:
currentDate, currentTime, utcTime, dryTemp, wetTemp, stationPressure, seaLevelPressure,
pressureSlope, pressureShape, relativeHumidity, vaporPressure, dewPoint,
vaporPressureDiff, windDirection, windSpeed, avgWindDirection, avgWindSpeed,
visibility, currentWeather, pastWeather, precipitationAmount, totalCloudCover,
cloud1Amount, cloud1Type, cloud1Height, cloud2Amount, cloud2Type, cloud2Height,
cloud3Amount, cloud3Type, cloud3Height, cloud4Amount, cover12, cover123,
observerNotes, responsibilityAgreement.

Modern:
- Angular reports/hourly has the core and conditional fields, cloud layer controls,
  API submission and offline queue. The source builds cloud layer fields for
  layers 1–4 amounts and layers 1–3 type/height.
- Flutter ObservationSubmitScreen now includes the API-required core fields,
  optional vapor/wind/weather/cloud fields, conditional precipitation and
  synoptic fields, and invokes HourlyObservationContract before submit.
- The shared hourly fixtures are executed in Flutter and Angular. .NET also
  executes the same fixture manifest.

Open verification:
- Verify Angular and Flutter field-by-field behavior against the complete legacy
  formatting helpers (not only the API ranges), including auto-formatting and
  sign-toggle interactions.
- Verify currentDate / currentTime legacy UI semantics against the modern
  observationDate + utcTime model and station-local UTC+3 conversion.
- Add Flutter widget coverage for every optional cloud/vapor field and conditional
  visibility, not just contract unit coverage.

## Daily observation

Legacy source:
- pages/daily/daily_send/daily.html
- daily_validation.js, daily_main.js, daily_fields_control.js

Legacy fields found:
currentDate, report24h, report06UTC, report18UTC, minTemp, maxTemp, precipitation,
snowThickness, precipitationTrace, weatherPhenomena, evaporation, sunshineDuration,
sunshinePercentage, maxGustSpeed, maxGustDirection, maxGustTime, maxHumidity,
maxHumidityTime, minHumidity, minHumidityTime, observerNotes, responsibilityAgreement.

Modern:
- Angular reports/daily has all canonical meteorological fields and the three
  report types; the executable validateDailyObservation function is now used
  before API/offline submission.
- Flutter has a daily entry screen and DailyObservationContract; six shared
  daily fixtures are executed in Flutter and Angular, and .NET runs the same
  manifest.

Open verification:
- Compare original phenomenon checkboxes and notes/observer metadata against the
  canonical server payload and persistence projection.
- Validate report-date/time semantics for all three report types against the
  original daily JS, including day-boundary cases.
- Test offline replay of daily submissions with each report type and rejection
  feedback after a server validation error.

## Climate hourly, rainfall, soil and agriculture

| Legacy source | Legacy field set | Modern state |
|---|---|---|
| pages/h_climate/h_climate_send/h_climate_send.html | UTC time, dry/wet temperature, RH, vapor pressure, dew point, surface/average wind, total cloud, notes, responsibility, WhatsApp options | Angular climate screen contains the listed input and share controls; no API-backed submission workflow is evidenced. |
| pages/rain/rain_send/rainfall_reports.html | local/UTC time, rain amount, snow depth, observation date, responsibility | Angular rainfall screen contains rain/snow/date/time fields; API persistence is not evidenced. |
| pages/soil/soil_send/soil-send.html | UTC time, soil temperatures at 5/10/20/50 cm, notes, responsibility | Angular soil screen contains the fields but is explicitly preview-only; no persistence or API route. |
| pages/arg/send-argicultural/agricultural_reports.html | air/soil temperatures, humidity, sunshine/cloud, precipitation, wind, evaporation, dew/fog/hail/sandstorm and notes | Angular agriculture screen models many legacy fields but is explicitly preview-only; no persistence or API route. |

These four areas must not be marked complete until their domain contracts,
backend persistence, station authorization, read models, and regression tests
exist. No fake operational observations should be created for demonstration.

## Review, IT, telecom and workshop

- Core observation review/return/resubmit, IT/support incidents, and equipment
  fault lifecycles have API-backed implementations and station authorization
  tests.
- The legacy telecom-manager.html and workshop-manager.html are much broader
  manager consoles with tables, filters, image galleries/attachments, status
  actions, charts and exports. Current shared support/fault workflows do not
  prove one-to-one parity with those consoles.
- Attachment upload/download and export routes are not currently evidenced in
  the support/maintenance API inventory. Dedicated telecom and workshop manager
  views remain open.
- Full network/IT manager administration and role-specific dashboards remain
  open beyond the current registration, authority-access and station-user
  features.

## Analytics and report viewing

Legacy view-data/pages/weather_analytics.html includes multi-station selection,
date range, UTC hour range, and charts for temperature/dew point/feels-like,
wind/activity, pressure/sunshine, and humidity/statistical comparison.
There is no dedicated modern weather analytics route or equivalent dashboard.
Monthly, annual, climate, rainfall and observation report components require
separate evidence for server-backed queries, station scoping, calculations,
pagination and export; route presence alone is insufficient.

## Acceptance evidence still required

1. Complete field-level and formatting comparison for every observation type.
2. End-to-end API persistence + role/station isolation for each production form.
3. Server-backed list/detail/report query tests and safe export tests.
4. Flutter Android runner, signed release build, install and real-device test;
   iOS requires macOS build/signing and device validation if in scope.
5. Real staging host, HTTPS, server-only secrets, readiness, auth and station
   smoke tests. The repository does not contain a verified staging host.
6. User acceptance against original screenshots and Arabic RTL workflows.

The old repository is read-only and the legacy database is not a migration
target. No legacy database or hosted new database was changed during this audit.
