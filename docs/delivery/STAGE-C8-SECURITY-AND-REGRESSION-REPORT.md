# Stage C8 — Security and Regression

## Authorization matrix exercised (SQL isolated archive suite)
| Scenario | Result |
|----------|--------|
| Explicit archive grant station A | allow |
| Same user station B same authority | deny |
| Role-only without archive grant | deny |
| Revoked grant | deny |
| Expired assignment | deny |
| Audit UPDATE/DELETE | blocked |

## Domain/API (from .NET suite, 264 tests)
- Archive not inferred from Review/Approve
- Cross-station deny
- 401 unauthenticated protected routes
- Rate limit 429 + security headers
- 23505 → 409 grant conflict mapping

## Archive API
Endpoint remains **503** fail-closed after authz when service unconfigured.

## Secrets
No production secrets committed in C8 work; Flutter uses dart-define base URL only.
