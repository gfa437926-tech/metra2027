# Stage C8.4 — Security & Integration Audit (local Backend + remote Flutter CI)

## Flutter ↔ API contracts (source review)

| Topic | Status |
|-------|--------|
| Archive path `/api/v1/stations/{id}/observation-archive` | Present in local client; main/remote client may lag if only tests were pushed |
| Error body `code` / `error` mapping | Local client implements |
| HTTP 503 archive fail-closed | Local API keeps unavailable archive; client must not treat as empty success |
| 401 / 403 | Domain + API tests in local suite |
| 409 grant conflict | Local `AuthorityAccessConflictDetector` maps PG 23505 |
| JWT validation | Local Program configuration (issuer/audience/lifetime) |
| Rate limiting | Local MetraRateLimiting policies |
| Security headers | Local middleware |

## Authorization

- ArchiveRead remains station-scoped in proposals + isolated SQL tests.
- Role-only / authority-only denied for archive in isolation suite.
- Hosted R4 RPC **not applied**.

## Mocks

AI / Climatol / Forecast remain mock until real services approved.

## Residual risks

1. Remote branch lacks local Backend — production must not deploy remote tip as “full C2–C6”.
2. Full git reconciliation still requires approved non-force integration.
3. Hosted schema changes still blocked pending explicit approval.
