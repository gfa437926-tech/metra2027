# METRA completion gates (honest checklist)

## Done in repository (code)
- Station-scoped observation lifecycle APIs and clients
- Equipment fault + support incident APIs and clients
- Dual JWT path (JWKS primary, Auth user fallback, optional HS256 secret)
- Npgsql equipment fault service (activated by ConnectionStrings:MetraOps)
- Isolation tests for observation/equipment/support list+submit+detail gates
- Angular/Flutter operational screens wired to real contracts

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
