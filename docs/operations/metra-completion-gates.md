# METRA completion gates (honest checklist)

## Done in repository (code)
- Station-scoped observation lifecycle APIs and clients
- Equipment fault + support incident APIs and clients
- Dual JWT path (JWKS primary, Auth user fallback, optional HS256 secret)
- Npgsql equipment fault service (activated by ConnectionStrings:MetraOps)
- Isolation tests for observation/equipment/support list+submit+detail gates
- Angular/Flutter operational screens wired to real contracts

## Verified daily-observation submission contract (repository inspection)
- Angular posts `idempotencyKey`, `observationType: daily`, `observedAt`, `payload`, and `submit: true` to the station-scoped API.
- The API validates the canonical `payload.values` contract and the daily `reportType` / `responsibilityAgreement` before calling the persistence service.
- The persistence service invokes `public.metra_submit_observation` using the server-held Supabase service-role key; that SQL function returns a JSON object with top-level `id`, `status`, and `replayed`. This matches Angular's top-level `result.id` check.
- The SQL function checks both `observation.create` and, for submitted reports, `observation.submit` permissions, stores the observation, and appends an audit event on first insert. A matching idempotent replay returns the existing observation id without adding a second audit event.
- This verifies the code-level response contract only. It does **not** prove that migrations are applied to the new Supabase project or that a real authenticated submission has succeeded there.
- Angular currently has no configured unit-test script/test runner in `angular-app/package.json`; CI's Angular check is a production build, not component behavior tests.
- The `24h` report timestamp currently maps to 00:00 UTC as a provisional convention. Confirm the operational reporting-day boundary before production use.

## Blocked without operator action
- Apply Supabase migrations on the **new** project only (not legacy INSERT DB)
- Provision DB roles and secrets for MetraOps
- Configure staging/production connection strings and Auth keys
- Merge PR #11 after review
- Staging E2E, backup restore drills, gradual production rollout

## Explicit non-goals
- Do not modify the legacy INSERT database
- Do not import legacy stations without approval
- Do not place service-role or JWT secrets in clients

## Daily submission retry hardening and legacy period semantics
- The Angular daily form now keeps a pending idempotency key in the current page and, where Web Crypto and session storage are available, across a same-tab reload.
- Session storage contains only the SHA-256 fingerprint of the exact submission plus its UUID idempotency key; the meteorological payload and observer metadata are not stored there. If hashing or session storage is unavailable, retries are protected only while the current page remains open.
- A changed station, report date/type, agreement, or submitted value changes the fingerprint and causes a new idempotency key. A confirmed submitted response clears the pending key.
- Read-only inspection of the legacy `daily_db.js` confirms the period labels: `24h` = 00:00–24:00; `06utc` = a 24-hour period ending at 06:00 UTC; `18utc` = a 24-hour period ending at 18:00 UTC. The legacy form stores the selected date as `report_date` and `collection_date`, while the UI describes the 24-hour summary as the previous day.
- Therefore, the current API `observedAt` mapping is still provisional: the repository establishes period labels and selected-date storage, but does not conclusively define whether `observedAt` should denote period start, period end, or the operational reporting date. Do not change the mapping or release this workflow until the meteorological owner confirms that convention.
- The latest change is code-only; CI must pass on its exact head SHA. No database migration was applied and no live submission was performed.

## Daily cross-field validation hardening

- The daily domain validator now rejects a minimum humidity value greater than the maximum humidity value, in addition to the existing maximum/minimum temperature ordering rule.
- The rule is enforced server-side, so direct API callers cannot bypass the cross-field constraint by skipping browser validation.
- Unit tests cover inverted humidity values and the explicit `#` missing-data marker; the API field-contract test also exercises the rule through the submission contract.
- This remains code-level validation only; no live Supabase write or migration was performed.

## Angular daily submission unit-test harness

- Extracted the daily submission security/contract helpers into `angular-app/src/app/features/reports/daily-submission.utils.ts` so the safety-critical decisions can be tested independently of browser UI state.
- Added dependency-free Node.js test coverage using the Node 22 built-in test runner; TypeScript compilation is performed by the existing Angular TypeScript compiler. No new npm dependency is required.
- Covered native secure UUID generation, secure-random fallback UUID v4 generation, fail-closed behavior when secure randomness is unavailable, acceptance/rejection of persisted submission receipts, and the current `24h` / `06utc` / `18utc` timestamp mapping.
- Added `npm test` and made Angular CI run it before the production build.
- These are focused helper/contract tests, not full Angular component integration tests. The form-to-API workflow still requires component-level tests for validation, in-flight duplicate prevention, retry-key persistence across reload, and error rendering.
- The `24h` `observedAt` boundary remains provisional pending confirmation by the meteorological business owner. No database schema or migrations were changed.
