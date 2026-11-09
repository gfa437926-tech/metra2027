# Service-role path review — support & maintenance

## Flow
1. JWT validated; `sub` = actor.
2. `RequireStationPermission` and/or `HasStationPermissionAsync` for the route station.
3. Server uses `Supabase:ServiceRoleKey` **or** Npgsql ops connection (never the client).

## Query binding
| Operation | Station binding |
|---|---|
| List faults/incidents | `station_id=eq.{routeStationId}` |
| Detail | `id=eq.{id}&station_id=eq.{routeStationId}` + response `station_id` must match |
| Submit / transition RPC | `p_station_id` from route |
| Npgsql list/detail/update | `where station_id = @station_id` inside transaction after `SET LOCAL` |

## Gaps closed in code (this change set)
- Detail endpoints fail closed if `station_id` missing or mismatched in storage payload.

## Gaps remaining
- Live RLS not proven; service role bypasses end-user RLS by design until a user-JWT path is approved.
