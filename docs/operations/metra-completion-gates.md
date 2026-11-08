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
