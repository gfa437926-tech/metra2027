# Final audit — METRA fix plan on PR #11 branch tip

**Branch:** `work/legacy-ui-migration-audit`  
**Audited tip (isolation tests):** `76375dfdd7efb52df4ff70bdb057bd58bbc698c6`  
**PR #11:** remains Draft — **not merged**  
**Databases:** no apply, no legacy touch, no schema change

## Phase outcomes

| Phase | Status | Evidence |
|---|---|---|
| 1 Flutter Analyzer | Closed | No `skip:` in tests; `flutter analyze` clean on prior tip; Client CI green |
| 2 Daily 24h test | Closed | Test active without skip; Client CI green |
| 3 Hourly/daily input tests | Closed | Local observation suite passed; Client CI green |
| 4 Support/maintenance permissions | Closed | `*.update` vs `*.resolve` mapping + unit theories; commit `c5ca7a8` |
| 5 Station isolation negatives | Closed at API layer | Cross-station forbid + update≠resolve tests; commit `76375df`; residual: live Postgres RLS |
| 6 Full CI | Closed on tip | Backend #1134/#1135 success; Client #474/#475 success |
| 7 Final audit | This document | No merge performed |

## Problem → fix → proof

1. **Analyzer String vs bool?** Temporary `skip: String` was invalid. Removed; 24h test re-enabled after form mount fix.  
2. **24h / form submit failures.** Lazy `ListView` left required fields unmounted. Fixed with `SingleChildScrollView`+`Column` (earlier commits on branch).  
3. **InProgress tied to resolve.** Split to `equipment_fault.update` / `support_incident.update`.  
4. **Cross-station risk at API.** Expanded forbidden tests proving station A cannot list/detail/transition station B for faults and support.

## Remaining risks (explicit)

- Live PostgreSQL RLS / Npgsql `SET LOCAL` not proven against a real DB (requires approved SQL + secrets).
- `legacy_users_staging` origin still owner decision.
- Service-role residual risk after JWT checks.
- Full legacy UI parity outside this fix plan.
- PR #11 still Draft; do not merge without owner approval.

## Confirmation

- No Pull Request merged to `main`.
- No SQL executed against any database.
- No connection to the legacy database.
