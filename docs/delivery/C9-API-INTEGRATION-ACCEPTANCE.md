# C9 — API Integration Acceptance

| Contract | Flutter | .NET / current state |
|----------|---------|----------------------|
| Station directory | liveApi | Implemented; requires configured API and authorized identity |
| Observation queue | liveApi | Actor-bound atomic RPC path implemented; hosted RPC deployment and Staging verification pending |
| Observation submit | liveApi | Flutter calls .NET; payload validation and atomic persistence RPC implemented; writes fail closed until `ObservationSubmission:ScientificContractApproved=true` |
| Observation decision | liveApi | Actor-bound atomic decision RPC path implemented; hosted deployment and Staging verification pending |
| Observation archive | API route aligned | .NET archive service and readiness probe implemented; returns 503 while required actor-bound RPCs are absent from the configured hosted project |
| Grant conflict | — | 409 on unique_violation |
| 401 / 403 | Client throws MetraApiException | Authn/authz error mapping and tests |

## Acceptance boundary

- A successful local/CI build does not prove that the hosted RPCs exist.
- A successful observation API response means the server accepted the submission; it does not mean a reviewer approved it.
- Observation writes remain disabled by default. The deployment must explicitly set `ObservationSubmission:ScientificContractApproved=true` only after the meteorological owner approves the unresolved temperature range and scientific field contract.
- Daily 06/18 UTC reports remain rejected until the source contradiction is resolved.
- Full E2E with a real hosted identity provider and a dedicated Staging environment has not been run.
- No hosted migration, production deployment, or legacy database change is included in this acceptance record.
