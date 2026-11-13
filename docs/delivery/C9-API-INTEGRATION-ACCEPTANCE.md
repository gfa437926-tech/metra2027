# C9 — API Integration Acceptance

| Contract | Flutter | .NET (local) |
|----------|---------|--------------|
| Stations directory | liveApi | Implemented |
| Observation queue / submit / decision | liveApi | Implemented |
| Observation archive | path aligned; expects error codes | **503** until service |
| Grant conflict | — | **409** on unique_violation |
| 401 / 403 | Client throws MetraApiException | Authz tests |

Integration is **contract-ready** for RC against local Backend. Full E2E with hosted IdP + API was not run in this environment.
