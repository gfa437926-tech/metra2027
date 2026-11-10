# Execution follow-up — source recovery, validation wiring, supply chain and authorization — 2026-11-10

## Scope and safety

Follow-up source audit for `integration/repository-consolidation-audit`.
No database was connected to or queried. No SQL, migration, schema, seed, grant, or production setting was applied. The legacy database and legacy station catalogue remain outside scope.

## 1. Six historical migration sources — recovery result

The six requested historical files were checked by their exact filenames against the repository's inspected source inventory and the `work/identity-migration-audit` branch. The exact root-level paths were not present on that branch, and repository commit search returned no matching historical commits for the six descriptive migration names.

| Historical filename | Result |
|---|---|
| `20261102172226_create_provenance_preserving_observation_store.sql` | Not recovered |
| `20261103122944_grant_runtime_station_coordinate_read.sql` | Not recovered |
| `20261103123005_link_membership_and_assignment_roles.sql` | Not recovered |
| `20261103123127_index_role_catalogue_foreign_keys.sql` | Not recovered |
| `20261103162707_enforce_explicit_role_permission_allowlist.sql` | Not recovered |
| `20261103162738_seed_conservative_observation_role_permissions.sql` | Not recovered |

No replacement was generated. No migration was reconstructed from a live database, current schema, similarly named file, or inferred behavior. The last two files remain critical because the exact role-permission allow-list and seed intent cannot be authenticated without their source provenance.

**Recovery gate:** locate the originating repository/branch/commit or an owner-provided archive, then compare the original bytes and SHA-256 against the expected release artifact. Until then, mark the six as unrecovered and do not apply substitute SQL.

## 2. Dependency and supply-chain review

Source inspection reconfirmed:
- Angular manifest and npm lockfile v3 are present; the lockfile root dependency declarations match `angular-app/package.json`.
- .NET API targets .NET 10 and direct package versions are explicit in `backend/Metra.Api/Metra.Api.csproj`; test package versions are explicit in `backend/Metra.Api.Tests/Metra.Api.Tests.csproj`.
- Flutter manifest and `pubspec.lock` are present; hosted dependency versions are resolved in the lockfile.

The repository's successful Backend CI run includes a NuGet high/critical advisory gate. This is useful evidence for the backend restore state on the tested commit, but it is not a complete current supply-chain assessment across all ecosystems.

Not performed in this follow-up: `npm audit` against the complete committed lockfile, `dotnet list package --vulnerable`/equivalent against restored assets, `dart pub outdated` or advisory review, SBOM generation for each client, licence-policy scan, malware scan, or direct/transitive dependency reachability analysis. The current connector does not expose repository security-alert or Dependabot alert retrieval, and no package restore/runtime shell was available in this audit session. Therefore no claim of "zero vulnerabilities" or "licence compliant" is made. No package was upgraded, removed, or re-pinned.

**Required next evidence:** run locked restores and ecosystem-specific advisory scans in CI, retain machine-readable reports, generate CycloneDX/SPDX SBOMs, apply an approved licence allow/deny policy, and review reachable vulnerable packages before remediation.

## 3. Versioned hourly/daily observation contract

The source review confirmed that the API request currently carries a generic `JsonElement` payload. The existing domain validators accept string dictionaries, but no explicit versioned hourly/daily DTO or approved daily required-field matrix is wired into the submission route.

A safe V1 contract must:
- carry an explicit schema/version identifier;
- preserve the legacy meteorological field codes without silent renaming;
- separate meteorological values from observer notes, acknowledgement, report metadata and phenomenon flags;
- define typed handling for unknown fields, nulls, whitespace, missing markers and numeric strings;
- validate hourly conditional fields from UTC hour only where the source contract establishes them;
- keep daily requiredness policy-driven by approved report type and station programme;
- represent snow depth with actual observation timestamp, time basis, station programme, and measured/zero/missing state; distinguish snow depth on ground from new snowfall depth;
- reject unsupported versions before persistence.

The WMO-based snow-depth policy is already recorded in the companion observation-contract audit. National station classes/programmes, fixed climatological observation time, expected-snow season and missing-value codes remain unconfirmed. The hourly source/validator differences (temperature sign and cloud-type fields) also remain unresolved. Implementing a DTO now would either silently reject legitimate form values or invent operational rules. No DTO or required-field policy was fabricated in this follow-up.

## 4. Server validation before persistence — confirmed blocker

The route in `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs` currently:
1. derives the authenticated user from the `sub` claim;
2. calls `ObservationSubmissionRequestGuard.GetError` for envelope checks (idempotency key, observation type, timestamp, JSON object and payload-size bound);
3. checks service configuration;
4. calls `IObservationSubmissionService.SubmitAsync`.

It does **not** call `HourlyObservationValidator.Validate` or `DailyObservationValidator.Validate` before `SubmitAsync`. Thus the current route does not prove meteorological field validation before persistence. The validator classes also do not, by themselves, establish strict unknown-key handling or an approved daily required-field set.

**Required implementation once the V1 contract is approved:**
- parse payload to a versioned typed request;
- map to the exact validator input without dropping or coercing fields;
- validate all accepted field types, conditional requirements and field-specific missing markers;
- return a stable 400 response with field-level errors before service invocation;
- add endpoint tests using a spy submission service proving invalid hourly and daily payloads cause zero `SubmitAsync` calls;
- add positive endpoint tests for every supported UTC hour/report type;
- add Flutter and Angular serialization contract tests against shared fixtures.

This remains an explicit implementation blocker; no partial validation was added that could create a false sense of coverage.

## 5. Station isolation and delegation ceiling

The observation submission route carries a station-specific permission requirement (`observation.create`). The prior audit identified station-scope authorization and grant-delegation ceiling as separate proofs; successful static SQL contract checks do not prove all runtime and database transaction race cases.

The grant ceiling remains unapproved. Before SQL changes, an authorized policy owner must approve authority scope, delegable subset, inherited ceiling, maximum delegation depth, expiry rules, non-delegable permissions and separation of duties. No grant-writing or schema change is authorized by this audit.

Required isolated tests:
- station A principal cannot read, submit, decide, or mutate station B records by changing route IDs, body IDs, query filters, pagination cursors, or nested resource IDs;
- missing, inactive, expired, revoked and cross-authority assignments fail closed;
- reviewer cannot grant permissions outside their own approved delegable subset or beyond their ceiling/depth/expiry;
- target role allow-list and current authority membership are rechecked atomically;
- spoofed actor IDs in body/headers do not override authenticated identity;
- concurrent grant/revoke and policy-version changes have deterministic outcomes;
- invalid observations never reach the persistence service.

The test database must be disposable and isolated, with no connection to either the legacy database or the production/new METRA project.

## 6. Current delivery status

- Six historical SQL files: **0/6 recovered**.
- Dependency manifests/lockfiles: source consistency inspected; complete advisory/licence/malware scan **not yet performed**.
- Versioned observation DTOs: **not implemented**, pending source-contract and national-operational decisions.
- Server-side meteorological validation before persistence: **not wired**; confirmed blocker.
- Station isolation and delegation: existing route/contract checks are not a substitute for the complete negative integration test matrix; delegation ceiling remains unapproved.
- No database was connected to, queried, or changed.
- No SQL/migration was authored, applied or executed.
- No deployment or PR merge was performed.

## 7. Evidence links

- Companion contract and WMO review: `docs/security/source-audits/2026-11-10-observation-contract-and-delegation-policy.md`.
- Permission and validation wiring review: `docs/security/source-audits/2026-11-10-permission-grant-ceiling-review.md`.
- Current pull request: [PR #13](https://github.com/gfa437926-tech/metra2027/pull/13).
