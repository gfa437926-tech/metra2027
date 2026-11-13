# METRA 2027 — Flutter UI Remaining Gaps

## Implemented integration paths

- **Hourly observation:** Flutter exposes the source-derived individual fields and calls the .NET submission endpoint. Server-side validation and atomic persistence RPC code exist. Staging verification is still pending.
- **Daily 24-hour observation:** Flutter exposes the 24-hour fields, report type, precipitation trace, and weather-phenomena controls, and calls the .NET endpoint. The 06/18 UTC options remain disabled.
- **Observation API readiness:** a successful API response means the backend accepted the submission; it does not mean the observation has been reviewed or approved.

## Remaining blockers

1. **Scientific approval:** temperature range conflict (-20..+50 versus -50..+50), approved psychrometric lookup/calculation method, and the 06/18 UTC daily source contradiction.
2. **Staging:** no real identity-provider end-to-end test has been completed against a dedicated staging environment.
3. **Archive:** the .NET archive service and actor-bound RPC proposals exist, but the required functions are not deployed to the configured hosted project; archive remains fail-closed.
4. **AI gateway:** UI exists; provider contract, credentials, real inference, and tests remain pending.
5. **Climatol:** UI prepares requests; server runtime, versioned execution contract, job lifecycle, and integration tests remain pending.
6. **Forecast centres:** UI exists; approved feed/provider contract, credentials, freshness policy, and tests remain pending.
7. **User directory / audit / review queue:** actor-bound API and RPC paths exist, but hosted RPC deployment and staging authorization fixtures remain pending.
8. **Charts / export / print:** not fully production-wired.
9. **Role-aware destination visibility:** still needs a server access-context contract and end-to-end tests.

No mock provider is represented as a live external integration. No hosted schema, production data, or legacy database was changed.
