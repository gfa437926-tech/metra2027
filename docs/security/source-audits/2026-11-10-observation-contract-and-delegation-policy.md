# Observation contract reconciliation and delegation policy proposal — 2026-11-10

## Scope and safety

Source-only review of `integration/repository-consolidation-audit`.
No database connection was opened; no SQL, migration, or schema change was executed.
The legacy database and legacy station catalogue were not accessed or changed.
This document does not approve a permission policy and does not authorize grant-writing.

## 1. Source contracts located

The original form sources are present at repository root:
- `hourly_reports.html` (form source; SHA `b5a78f633a3f8456bbf20c57cac7e4889a7bc889`)
- `hourly-send.js` (conditional hourly field visibility; SHA `d6d0b88a3ae7f8745bfae72580716781a2ea0ac2`)
- `submit-hourly.js` (hourly payload collection; SHA `a8270b838abc884e1bab3d833517e1a2e0d525c4`)
- `daily.html` (daily form; SHA `5c4126b6186d9d51f14a224302fa676acdcb4a32`)
- `daily_fields_control.js` (daily report-type visibility; SHA `ed595d31af2ee3849c9872ee6fdb8dc9e6e6c56c`)
- `daily_db.js` (daily persistence mapping; SHA `a6fadcc289277e5aa7545ff3cb9d18a3576fca04`)
- `daily_validation.js` (daily browser validation; SHA `5d24c49b03a1f1dbd6f6ab4a1c1c214c21be2702`)

These are source references, not a guarantee that every historical source file or variant has been recovered. In particular, the six previously reported missing original files still need to be matched by exact path and content before they can be declared recovered.

## 2. Hourly form contract — confirmed source fields

The HTML form uses these field codes:
`utcTime`, `dryTemp`, `wetTemp`, `stationPressure`, `seaLevelPressure`, `pressureSlope`, `pressureShape`, `relativeHumidity`, `vaporPressure`, `dewPoint`, `vaporPressureDiff`, `windDirection`, `windSpeed`, `avgWindDirection`, `avgWindSpeed`, `visibility`, `currentWeather`, `pastWeather`, `precipitationAmount`, `totalCloudCover`, `cloud1Amount`, `cloud1Type`, `cloud1Height`, `cloud2Amount`, `cloud2Type`, `cloud2Height`, `cloud3Amount`, `cloud3Type`, `cloud3Height`, `cloud4Amount`, `cover12`, `cover123`, `observerNotes`, and `responsibilityAgreement`.

The hourly UI source establishes:
- `utcTime` is selected from 00 through 23.
- `precipitationAmount` is shown and made required at UTC 00, 06, 12, and 18.
- `pressureSlope` and `pressureShape` are shown and made required at UTC 00, 03, 06, 09, 12, 15, 18, and 21.
- The HTML includes additional fields for cloud types, cloud layer 4 amount, notes, and an acknowledgement checkbox. The server validator currently does not fully describe all of these form fields.
- The submission collector serializes named controls into a key/value object. The acknowledgement control is a checkbox and therefore must not be confused with a meteorological text field.

### Hourly validator discrepancies to resolve before DTO implementation

1. The HTML temperature pattern permits an optional sign, while `HourlyObservationValidator` currently requires an explicit plus or minus sign.
2. The form includes `cloud4Amount`, but the validator rules shown do not include it.
3. The form includes `cloud1Type`, `cloud2Type`, and `cloud3Type`, but the validator has no corresponding rules.
4. The form includes `observerNotes` and `responsibilityAgreement`; these need distinct metadata/consent handling rather than being silently treated as meteorological values.
5. The form uses a `#` missing-value convention on several controls. Preserve it only for fields whose original form contract explicitly supports it; do not globally accept it for every property.
6. The current hourly validator ignores unknown keys. The DTO/API contract must decide strict unknown-field rejection and versioning explicitly.

These discrepancies mean that a typed DTO must not simply mirror the current validator's rule dictionary.

## 3. Daily form contract — confirmed source fields

The daily form defines report types `24h`, `06utc`, and `18utc`, and the following controls:
- Always-visible base fields: `minTemp`, `maxTemp`, `precipitation`, `snowThickness`.
- Optional trace marker: `precipitationTrace` (T/t or empty).
- 24-hour-only phenomena: `thunderstorm`, `hail`, `snow`, `rain`, `frost`, `fog`, `mist`, `dustStorm`, `blowingDust`, `haze`, `stormyWind`.
- 24-hour-only numeric fields: `evaporation`, `sunshineDuration`, `sunshinePercentage`, `maxGustSpeed`, `maxGustDirection`, `maxGustTime`, `maxHumidity`, `maxHumidityTime`, `minHumidity`, `minHumidityTime`.
- Metadata: `currentDate`, `reportType`, `observerNotes`, `responsibilityAgreement`.

`daily_fields_control.js` hides and disables the phenomena, evaporation/sunshine, wind, and humidity sections for `06utc` and `18utc`. Its explanatory text says those report types contain temperatures and precipitation only. However, `snowThickness` remains in the always-visible base section and is marked required in the HTML. This is a contract conflict requiring a domain-owner decision before server required-field rules are fixed.

The database collector maps the UI names to snake_case persistence fields (for example `minTemp` to `min_temperature`, `maxTemp` to `max_temperature`, and `snowThickness` to `snow_thickness`). That persistence mapping is useful evidence but is not by itself a complete API DTO contract.

### Daily validator discrepancies to resolve

1. The server validator accepts a caller-supplied `requiredFields` set but does not define the approved required set for each report type.
2. The HTML/visibility script and the explanatory report-type text conflict on whether `snowThickness` is required for `06utc` and `18utc`.
3. The HTML exposes metadata and boolean weather-phenomena controls which need explicit typed DTO treatment.
4. The validator silently ignores unrecognized field codes; strictness must be chosen in the versioned contract.
5. The `#` missing-value marker is supported by some original form controls and must be field-specific.

No required daily field list is approved by this audit.

## 4. Safe implementation sequence for observation DTOs

Do not add DTOs until the snow-thickness/report-type conflict and the hourly optional-sign/cloud-layer rules are resolved against the approved operational contract.

Once resolved:
1. Introduce versioned `HourlyObservationPayloadV1` and `DailyObservationPayloadV1` request models using the exact approved field codes.
2. Separate meteorological fields from report metadata, observer acknowledgement, and phenomenon booleans.
3. Normalize only representations explicitly permitted by the original contract; preserve the source code/value for audit where normalization occurs.
4. Reject unsupported report types, unknown keys, invalid JSON value types, and missing required fields before persistence.
5. Invoke the domain validator after typed mapping and before `IObservationSubmissionService.SubmitAsync`.
6. Add endpoint tests with a spy/fake submission service proving invalid payloads never call persistence.
7. Add positive tests for all 24 UTC hours and conditional requirements, and for each daily report type.
8. Add Flutter and Angular serialization contract tests against the same versioned contract.

## 5. Proposed permission-delegation ceiling — policy draft, not approved

The current grant lifecycle checks that a reviewer has `authority.access.review` and that the target's role permits the requested permission. The reviewed SQL does not prove a reviewer-specific delegable subset or maximum delegation depth.

The following is a conservative policy proposal for review:

- **Authority scope:** a reviewer may act only inside an authority for which their own active, approved membership and review permission are valid. No cross-authority grants.
- **Delegable subset:** a reviewer may grant only permissions explicitly listed as delegable to that reviewer by an approved authority policy. Merely being able to review grants is not sufficient.
- **Ceiling inheritance:** the permission must also be within the reviewer's own active approved permission ceiling. A reviewer cannot grant a permission they do not hold, cannot delegate, or hold only in another authority.
- **Depth:** default maximum delegation depth is 1. A recipient receives no onward-delegation power unless a separate explicit policy grants a bounded depth. No self-increasing depth.
- **Duration:** a grant must not outlive the actor's relevant authority membership, the actor's delegable grant, or the authority policy's maximum duration; use the earliest applicable expiry.
- **Non-delegable permissions:** account administration, authority ownership transfer, security-policy changes, grant-review/revoke powers, and service-role/system privileges should be non-delegable by default unless separately approved.
- **Target eligibility:** target account and membership must be active, approved, current, and within the same authority; the target's current role must allow the permission.
- **Separation of duties:** requester, subject, and approver remain distinct where policy requires; self-approval is always denied.
- **Atomic enforcement:** lock and re-check actor membership, actor grants, target membership, target role, grant row, and policy version in the same transaction as approval. Concurrent revoke/approval must have one deterministic winner.
- **Trusted actor identity:** derive actor identity from the authenticated server-side principal; never accept an actor ID from a request body. If a service-role RPC is retained, the API boundary must authenticate the caller and the database must independently verify the actor's active authority/grant ceiling. Do not expose the service key to clients.
- **Auditability:** record actor, subject, authority, permission, policy version, delegation depth, validity interval, decision, and reason in append-only audit evidence.

### Required negative tests before any SQL change

- reviewer lacks the requested permission;
- reviewer holds it but it is not in their delegable subset;
- target role does not allow it;
- authority mismatch;
- actor membership/grant expired, revoked, or inactive;
- grant duration exceeds actor or policy expiry;
- delegation depth exceeds the approved maximum;
- non-delegable permission requested;
- body-supplied actor ID attempts to override authenticated identity;
- concurrent approval and revoke;
- replayed or stale policy version.

This is a design proposal only. It must be approved, reconciled with the actual schema, and reviewed before any migration or SQL is authored or applied.

## 6. Dependency and six-file recovery audit

The six missing source files cannot be declared recovered from the form files above. Recovery requires an exact inventory containing each missing path, its expected origin/commit, replacement candidate (if any), and content/hash comparison. Do not substitute similarly named files or generated replacements without documenting provenance.

Dependency review must then compare all package manifests and lockfiles with actual imports/usages, identify direct versus transitive dependencies, pin versions, verify lockfile consistency, and assess known vulnerabilities/licences and abandoned packages. Do not upgrade or remove packages in this audit-only step.

## 7. Explicit non-actions

- No SQL or migration was changed or executed.
- No Supabase project was contacted.
- No database was read or modified.
- No legacy database or legacy station data was accessed.
- No application DTO or API behavior was changed because the source-contract conflicts above remain unresolved.
- No pull request was merged.


## 8. Exact six missing migration-source candidates

The six historical candidates carried forward by the authorization audit are:

1. `20261102172226_create_provenance_preserving_observation_store.sql`
2. `20261103122944_grant_runtime_station_coordinate_read.sql`
3. `20261103123005_link_membership_and_assignment_roles.sql`
4. `20261103123127_index_role_catalogue_foreign_keys.sql`
5. `20261103162707_enforce_explicit_role_permission_allowlist.sql`
6. `20261103162738_seed_conservative_observation_role_permissions.sql`

The last two are critical to verifying the exact `metra_role_permissions` allow-list. All six remain unrecovered as exact historical sources in the inspected source inventory. No substitute SQL was fabricated and no database was inspected to infer their contents.

## 9. Dependency manifest and lockfile review — source-only

Manifests and lockfiles inspected:
- `angular-app/package.json` and `angular-app/package-lock.json`: lockfile v3 is present and its root package declarations match the manifest. The manifest uses semver ranges (including Angular 20.3.x and Supabase JS 2.x); exact resolved versions are recorded in the lockfile.
- `backend/Metra.Api/Metra.Api.csproj`: .NET 10 target; direct package versions are explicit, including ASP.NET OpenAPI 10.0.0, JWT bearer 10.0.0, and Microsoft.OpenApi 2.7.5.
- `backend/Metra.Api.Tests/Metra.Api.Tests.csproj`: explicit test package versions are present.
- `mobile/metra_mobile/pubspec.yaml` and `pubspec.lock`: lockfile is present; Flutter SDK packages are SDK sourced and hosted dependencies have resolved versions in the lockfile. The manifest intentionally contains compatible version ranges for some dependencies and exact pins for others.

This is a manifest/lockfile consistency review only. No package restore, build, SBOM generation, licence scan, malware scan, or vulnerability database audit was run in this pass. No dependency was upgraded, removed, or re-pinned. A complete supply-chain sign-off still requires CI restore/build evidence and current advisory checks for npm, NuGet, and pub.dev against the committed lockfiles.
