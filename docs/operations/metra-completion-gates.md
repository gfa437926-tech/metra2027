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

## Daily offline outbox — first implementation slice

- Added an IndexedDB outbox for daily observation submissions. The browser transaction is considered complete only after the IndexedDB transaction commits.
- The daily form now places a validated submission in the local outbox when the browser reports no network connection. It retains the same idempotency key and does not show a server-save success message.
- The daily page displays online/offline state and the local outbox count.
- The daily form also caches the station directory in a separate IndexedDB object store and restores it before attempting an online refresh. This supports choosing a previously loaded station after a reload while offline; it does not support first-time station discovery without a prior online load. On the browser `online` event and page startup, it attempts to submit queued records through the authenticated station-scoped API.
- A queued item is removed only after the API returns a valid `submitted` receipt containing the observation UUID. Network/ambiguous failures remain queued with the same idempotency key. Validation/authorization failures are marked blocked instead of being retried indefinitely.
- This first offline workflow slice covers daily and hourly forms plus a runtime-cached application shell. A cold first visit still requires network access; not every lazy route/chunk is precached.
- IndexedDB contents are stored by the browser's origin storage and are not application-level encrypted in this implementation. Do not use shared/public devices for offline entry until device-level protection and a documented local-data retention/clearance policy are in place. No access tokens or service-role secrets are stored in the outbox.
- No background-sync API is assumed: retries occur when the page is open and connectivity returns, or when the page is reopened online. A browser/OS may suspend a closed tab.
- Browser integration tests with simulated offline/online transitions, IndexedDB failure, reload recovery, auth expiry, and duplicate delivery are still required. No live Supabase write or migration was performed.

## Application-wide offline shell and hourly outbox — implementation slice

- Added a same-origin service worker at `angular-app/src/metra-sw.js`; it caches the app shell, same-origin static resources as they are first requested, and provides a cached root navigation fallback when offline.
- The service worker deliberately bypasses non-GET requests, cross-origin requests, and every `/api/` request. Authenticated API responses and tokens are not placed in Cache Storage.
- Added a web app manifest, Arabic RTL metadata, a scalable METRA SVG icon, production asset inclusion, and HTTPS-only service-worker registration. The icon is included in the service-worker app-shell cache.
- Extended the IndexedDB outbox to distinguish daily/hourly observation types. Hourly form submissions can now be queued offline even when API configuration is absent, provided a previously cached station is available; they are retried on the `online` event or when the hourly page is reopened online. Station catalogue caching is shared with daily entry.
- Ambiguous hourly network failures are queued with the same idempotency key. The queue item is removed only after a UUID receipt is returned. Validation/authorization failures are marked blocked.
- Added a shared IndexedDB sync lease so daily and hourly pages do not drain the outbox concurrently across tabs; the lease is renewed before each queued submission to reduce expiry during long batches. Daily and hourly screens now distinguish pending from server-blocked records and expose an explicit manual retry action for blocked items. Added Node built-in contract tests for service-worker shell installation/activation, API bypass, offline navigation fallback, IndexedDB transaction completion, secure-context registration, icon declaration, offline enqueue, blocked-item recovery, and shared-lease acquisition/renewal wiring.
- Limitations still open: service-worker cache is a runtime cache rather than a generated full precache of every lazy route/chunk; the first visit must be online. Offline auth/session behavior must be tested with the actual identity provider. Third-party fonts/icons are not guaranteed offline. The manifest now declares an SVG icon, but platform installability and device-specific icon behavior still require browser/device verification.
- Browser-level tests using a real IndexedDB implementation and simulated network transitions are still required; current Node tests inspect contracts and source wiring, not actual browser IndexedDB behavior. CI must pass on the final commit before this slice is accepted.
- IndexedDB data remains browser-origin storage without app-level encryption. Shared-device protection, retention/clearance controls, and device policy remain release gates.
- No Supabase schema changes, migrations, or live database writes were made.
