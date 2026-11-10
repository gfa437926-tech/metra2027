# Authorized original-interface comparison and reimplementation plan

**Date:** 2026-11-10  
**Target repository:** `gfa437926-tech/metra2027`  
**Reference repository:** `gfa437926-tech/metra-old`  
**Reference revision:** `cd96e9e3ce68b0c109b4e47815a03ac68748afad` (`main`)  
**Target revision reviewed:** `0d0d61fa519e931a2920be8bcb72163d0e702c2e`  
**Authorization:** The rights holder expressly authorized comparison, extraction of design/behavior requirements, and independent reimplementation in `metra2027`, without literal copying of original files.

## 1. Scope and safeguards

This work uses the original repository as a read-only reference. It does not change `metra-old`, connect to its Supabase project, or migrate its records. The target implementation must be independently authored; do not paste original HTML, JavaScript, CSS, or component blocks into the target.

The authorization does not authorize database changes, SQL/migration execution, deployment, production data access, or merging PR #13. The new work is isolated on branch `work/authorized-original-ui-reimplementation`.

Preserve the rights notice:
- Rights holder: Ibrahim Zainab — 0934884157
- `Copyright © 2026 Ibrahim Zainab. All rights reserved.`
- Third-party frameworks and assets remain under their own licences.

## 2. Verified source inventory

The following reference files were read from `metra-old/main`:

| Interface / behavior | Original reference path |
|---|---|
| Hourly observation form and presentation | `pages/hourly/hourly_send/hourly_reports.html` |
| Hourly conditional fields and form setup | `pages/hourly/hourly_send/hourly-send.js` |
| Hourly formatting and validation | `pages/hourly/hourly_send/enhanced-validation.js` |
| Hourly cloud-layer interaction | `pages/hourly/hourly_send/cloud-total-cover-validation.js` |
| Hourly preview and collection | `pages/hourly/hourly_send/data-collector.js` |
| Hourly submission mapping | `pages/hourly/hourly_send/submit-hourly.js` |
| Daily observation form | `pages/daily/daily_send/daily.html` |
| Daily report-type visibility | `pages/daily/daily_send/daily_fields_control.js` |
| Daily field formatting and draft/preview actions | `pages/daily/daily_send/daily_main.js` |
| Daily validation | `pages/daily/daily_send/daily_validation.js` |
| Daily persistence mapping | `pages/daily/daily_send/daily_db.js` |
| Daily import/export | `pages/daily/daily_send/daily_json.js` |
| Daily settings and local backups | `pages/daily/daily_send/daily_settings.js` |
| Daily statistics | `pages/daily/daily_send/daily_stats.js` |
| Daily autocomplete | `pages/daily/daily_send/daily_autocomplete.js` |
| Shared navigation reference | `sidebar.html` |

The original sidebar builds navigation from a central path catalogue, reads the active user's role, inserts role-specific destinations, highlights the active destination, and provides logout/navigation handling. The hourly page also contains its own embedded sidebar markup; this duplication is a design defect to avoid in the reimplementation. Use one shared navigation component in the target application.

## 3. Existing target files: exact-match finding

At the reviewed target revision, several root-level files in `metra2027` have the exact same Git blob SHA as the corresponding original files. This means those target files are byte-identical to the reference; they are not evidence of an independent reimplementation.

| Target path | Original path | Matching blob SHA |
|---|---|---|
| `hourly_reports.html` | `pages/hourly/hourly_send/hourly_reports.html` | `b5a78f633a3f8456bbf20c57cac7e4889a7bc889` |
| `hourly-send.js` | `pages/hourly/hourly_send/hourly-send.js` | `d6d0b88a3ae7f8745bfae72580716781a2ea0ac2` |
| `daily.html` | `pages/daily/daily_send/daily.html` | `5c4126b6186d9d51f14a224302fa676acdcb4a32` |
| `daily_fields_control.js` | `pages/daily/daily_send/daily_fields_control.js` | `ed595d31af2ee3849c9872ee6fdb8dc9e6e6c56c` |
| `daily_validation.js` | `pages/daily/daily_send/daily_validation.js` | `5d24c49b03a1f1dbd6f6ab4a1c1c214c21be2702` |
| `daily_db.js` | `pages/daily/daily_send/daily_db.js` | `a6fadcc289277e5aa7545ff3cb9d18a3576fca04` |
| `daily_main.js` | `pages/daily/daily_send/daily_main.js` | `2126ca1c6c324059823853bcf9487fef45ad8da0` |
| `daily_json.js` | `pages/daily/daily_send/daily_json.js` | `d0203f8a6ac0751c5d54816857d5d3249c9ab376` |
| `daily_settings.js` | `pages/daily/daily_send/daily_settings.js` | `918ff6072eb964fd61cb6d1636e4f7b3ae97a6e7` |
| `daily_stats.js` | `pages/daily/daily_send/daily_stats.js` | `026aeefdf1b51440e0fa141e6270a790fa8e9dcd` |
| `daily_autocomplete.js` | `pages/daily/daily_send/daily_autocomplete.js` | `7ee9dbf86b9f11438cdea24348f5204075470b85` |
| `enhanced-validation.js` | `pages/hourly/hourly_send/enhanced-validation.js` | `ccd9b2818b5e0c30870dda13ce7e5e6489c4dc68` |
| `cloud-total-cover-validation.js` | `pages/hourly/hourly_send/cloud-total-cover-validation.js` | `4e7d37d84c93d58575eff39fb9f603d56b92c88d` |
| `data-collector.js` | `pages/hourly/hourly_send/data-collector.js` | `9839b6a48798576f1f0f15e5303122d618bd93bc` |
| `submit-hourly.js` | `pages/hourly/hourly_send/submit-hourly.js` | `a8270b838abc884e1bab3d833517e1a2e0d525c4` |
| `pressure-management.js` | `pages/hourly/hourly_send/pressure-management.js` | `58722a90c513e5d05be0963f450a8e8c969a4538` |

This audit records the observed state only. It does not claim when or by whom those files were copied. The independent Angular components are the appropriate target for the new implementation; the byte-identical root compatibility files must not be treated as the completed target design.

## 4. Extracted hourly-interface requirements

### Layout and navigation
- Arabic right-to-left page with a clear hourly-report title and concise operational description.
- A single shared sidebar/navigation source; no second page-specific sidebar.
- Station/observer identity and current local date/time are displayed as context, not trusted as authorization input.
- Organize the form into: station and observer context; UTC observation hour; temperature; pressure; derived humidity/vapour fields; wind and visibility; present/past weather; precipitation; cloud cover and cloud layers; observer notes; responsibility acknowledgement.
- Responsive layout for desktop, tablet, and mobile; grouped fields must remain readable on narrow screens.
- Provide clear validation feedback, loading state, preview, and submission result. A submitted status is shown only after server confirmation.

### Hourly fields
The reference form contains: `utcTime`, `dryTemp`, `wetTemp`, `stationPressure`, `seaLevelPressure`, `pressureSlope`, `pressureShape`, `relativeHumidity`, `vaporPressure`, `dewPoint`, `vaporPressureDiff`, `windDirection`, `windSpeed`, `avgWindDirection`, `avgWindSpeed`, `visibility`, `currentWeather`, `pastWeather`, `precipitationAmount`, `totalCloudCover`, `cloud1Amount`, `cloud1Type`, `cloud1Height`, `cloud2Amount`, `cloud2Type`, `cloud2Height`, `cloud3Amount`, `cloud3Type`, `cloud3Height`, `cloud4Amount`, `cover12`, `cover123`, `observerNotes`, and `responsibilityAgreement`.

### Time-dependent behavior to preserve pending domain approval
- UTC hour must be an explicit value from 00 through 23.
- Precipitation is conditionally shown/required at 00, 06, 12, and 18 UTC in the original form.
- Pressure tendency/slope and pressure shape are conditionally shown/required at 00, 03, 06, 09, 12, 15, 18, and 21 UTC.
- Past-weather code is treated as a synoptic-time field in the current Angular implementation and legacy validation scripts; reconcile this against the approved operational observation schedule before finalizing.
- The original interface includes four cloud layers, including a fourth amount field. The current server validator does not yet cover all cloud type/height/amount semantics; do not silently discard these values.
- The original hourly form includes derived values and cloud coverage relationships. Define which values are manually entered versus calculated, and validate cross-field constraints consistently on both client and server.

## 5. Extracted daily-interface requirements

### Layout and report types
- Arabic RTL form with three explicit report types: `24h`, `06utc`, and `18utc`.
- Clearly show the selected reporting period and the meaning of the date/time basis.
- Group information into station/observer/report metadata; minimum/maximum temperature; precipitation and snow; weather phenomena; evaporation/sunshine; wind gust; humidity; notes; acknowledgement.
- Provide field formatting, missing-value controls only where the contract permits them, preview, local draft, export/import, and statistics as separate functions.
- Local draft/preview status must never be presented as a server-persisted submission.

### Daily fields
Core fields: `minTemp`, `maxTemp`, `precipitation`, `snowThickness`, `precipitationTrace`.
24-hour-only fields: `thunderstorm`, `hail`, `snow`, `rain`, `frost`, `fog`, `mist`, `dustStorm`, `blowingDust`, `haze`, `stormyWind`, `evaporation`, `sunshineDuration`, `sunshinePercentage`, `maxGustSpeed`, `maxGustDirection`, `maxGustTime`, `maxHumidity`, `maxHumidityTime`, `minHumidity`, `minHumidityTime`.
Metadata: report date, report type, station identity, observer identity, notes, and responsibility acknowledgement. Metadata must not be mixed into the meteorological measurement payload without an explicit contract.

### Daily behavior and unresolved conflicts
- The original visibility controller hides the phenomena, evaporation/sunshine, wind, and humidity sections for 06 UTC and 18 UTC; its help text says those reports contain temperature and precipitation only.
- The original HTML keeps `snowThickness` visible and required for all three report types. The current Angular implementation also requires it for all three types.
- The WMO policy review already recorded in `docs/security/source-audits/2026-11-10-observation-contract-and-delegation-policy.md` establishes that snow depth must not be imposed universally without the station's approved observing programme and schedule. For stations whose synoptic programme includes snow depth, measurements should follow the applicable main synoptic times; climatological snow-depth observation needs a fixed station-specific daily time. Zero, missing, and not-observed are distinct states.
- Therefore, do not hard-code universal `snowThickness` requiredness for every station and report type. The target needs an approved station-programme rule and explicit value-state representation before enforcing it.
- The original daily validation permits `#` broadly in several numeric validators, while the report-type controller disables some no-data controls for 06/18. The new contract must define allowed missing markers per field and report type rather than accepting `#` globally.
- The server-side `DailyObservationValidator` currently receives `requiredFields` from its caller and does not itself define the required field set by report type. The submission endpoint must not be considered fully protected until server validation is actually wired before persistence.

## 6. Current target implementation assessment

- `angular-app/src/app/features/reports/hourly-reports.component.ts` is an independently structured Angular form with station-directory selection and a protected API submission path. It captures many of the hourly fields and conditional precipitation/pressure fields, but it still needs complete coverage of cloud-layer fields and strict contract validation.
- `angular-app/src/app/features/reports/daily-reports.component.ts` is an independently structured Angular form with the three report types, station selection, draft/preview behavior, and API submission. It currently requires snow thickness in all report types and needs the station-programme rule described above. Its required field lists and field mapping must be reconciled with the server contract.
- `angular-app/src/app/core/api/observation-api.service.ts` sends the selected station ID and observation payload through the API service. The API's actor identity must remain server-derived; browser-supplied user/station labels are display metadata only.
- `HourlyObservationValidator` has a defined baseline required set and time-dependent precipitation/pressure rules, but its field rules do not cover every source-form cloud type/height field. Unknown-key handling and complete schema/version enforcement remain unresolved.
- `DailyObservationValidator` validates known field formats and a caller-provided required set, but does not own the report-type contract. It must not be used as proof that the complete daily form is validated until endpoint wiring and report-type rules are tested.
- The operational submission API documentation describes the request envelope and station permission model; the known endpoint validation-wiring gap remains a blocker.

## 7. Independent reimplementation plan

1. Keep the original repository read-only and record source revision/hash references only.
2. Treat the Angular standalone report components as the target implementation; do not transplant original HTML/JS/CSS.
3. Create an explicit versioned field contract for hourly and daily payloads, including field units, ranges, missing-value states, requiredness, report type, and UTC/time basis.
4. Reconcile the contract with the meteorological domain owner before making station-programme assumptions, especially snow depth and synoptic schedule.
5. Implement every original meteorological field in Angular with accessible labels, responsive grouping, keyboard-friendly inputs, and one shared navigation component.
6. Implement client validation for immediate feedback and server validation for authoritative acceptance. Reject unknown fields for the selected schema version.
7. Ensure the API invokes hourly/daily validators before persistence; test malformed, missing, out-of-range, wrong-report-type, and unauthorized station submissions.
8. Keep draft/export/preview separate from server persistence. Never use browser local storage or display labels as authority.
9. Add tests for all report types, time-dependent fields, cloud-layer relationships, missing-value semantics, and mobile layout.
10. Retire or clearly isolate byte-identical legacy compatibility files only after the independent target routes and regression tests prove they are no longer needed.

## 8. Acceptance criteria

- No original source file is copied verbatim into the independent implementation.
- Every source meteorological field is either implemented, explicitly excluded with a documented reason, or awaiting domain-owner decision.
- All three daily report types have explicit, tested contracts.
- Hourly UTC conditional fields are covered by both client and server tests.
- Snow-depth requiredness is station-programme-aware and distinguishes measured zero from missing/not observed.
- The shared navigation appears once and is consistent across report routes.
- API validation runs before database persistence and cannot be bypassed by calling the endpoint directly.
- No legacy database connection, SQL execution, migration, deployment, or PR merge is performed as part of this work.

---

*Prepared for the authorized METRA reimplementation. Original reference materials remain in `metra-old`; this document records extracted requirements and audit findings, not copied source code.*
