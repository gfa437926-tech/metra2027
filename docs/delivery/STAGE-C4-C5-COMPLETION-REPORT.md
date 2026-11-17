# Stage C4 Completion + C5 CI Delivery Preparation

See also `STAGE-C4-API-ADVANCED-SECURITY-REPORT.md` and `STAGE-C5-GITHUB-CI-DELIVERY-CLOSURE.md`.

## Rate limiting coverage
All primary MapPost/MapGet feature endpoints under Observations, Stations, Users now carry `RequireRateLimiting` with read/write/sensitive policies as appropriate. Prior C4 policies and limits unchanged.

## Tests target
Full suite after this change should remain green locally; HTTP contract tests added.

## Push
**Not performed.**
