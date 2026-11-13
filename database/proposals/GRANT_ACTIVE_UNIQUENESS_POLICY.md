# Permission grant integrity policy (proposal — not applied)

## Goals
- Keep full historical grant rows (revoked / rejected / expired).
- Prevent **two active** grants for the same scope.
- Allow re-grant after revoke.

## Proposed active scope for station-bound permissions
Unique among rows where:
- `approval_status = 'approved'`
- `revoked_at IS NULL`
- `valid_from <= now()` and (`valid_to` is null or `> now()`) — time window uniqueness is harder in a partial index; start with approved+unrevoked.

For archive and other station-bound codes:

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS permission_grants_active_station_unique
ON public.permission_grants (user_id, station_id, permission_code)
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NOT NULL;
```

For authority-scoped grants (station_id IS NULL):

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS permission_grants_active_authority_unique
ON public.permission_grants (user_id, authority_id, permission_code)
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NULL;
```

## Why partial unique indexes
- Preserve history (revoked rows excluded from index predicate).
- Re-grant after revoke allowed (revoked row no longer in index).
- Concurrent second insert of active duplicate fails with unique_violation.

## Not applied in C2.4
Requires approval; test only on isolated PostgreSQL.
