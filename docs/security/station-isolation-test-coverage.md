# Station isolation test coverage (API layer)

**Scope:** ASP.NET integration tests with fake `IStationAuthorizationService`.  
**Not covered here:** live PostgreSQL RLS / `SET LOCAL app.station_id` against a real database (blocked without approved SQL apply and test DB credentials).

## Negative cases added

### Equipment faults
- List/detail/submit denied when user is not authorized for the path station.
- Station A credentials cannot list or open detail on station B.
- Station A credentials cannot transition a fault on station B.
- `equipment_fault.update` allows `InProgress` but not `Resolved`.
- `equipment_fault.resolve` alone cannot start `InProgress`.

### Support incidents
- List/detail/submit denied for unauthorized station.
- Station A cannot list or open detail on station B.
- Station A cannot transition an incident on station B.
- `support_incident.update` allows `WaitingForInformation` but not `Closed`.

## Residual risks
- Service-role PostgREST path still relies on API filters; RLS reduction remains an approved-SQL follow-up.
- Npgsql ops path sets transaction-local `app.station_id` / `app.user_id` in code; prove with isolated Postgres tests after owner approval of migrations and secrets.
