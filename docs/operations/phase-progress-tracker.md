# METRA Weather Intelligence — phase progress tracker

Updated from repository evidence only (no live DB writes).

| Phase | Title | Status | Notes |
|---|---|---|---|
| 1 | DB isolation review | Partial | Repo targets new Supabase only; `legacy_users_staging` source not in Git |
| 2 | DB design close | Partial | Inventory from migrations published; owner approval pending |
| 3 | Security & permissions | In progress | JWT + station checks in API; service-role residual risk documented |
| 4 | SQL apply | Blocked | Awaiting explicit approval |
| 5 | .NET API complete | Partial | Observations, stations, users, faults, support present |
| 6 | Web UI complete | Partial | Core routes exist; full legacy parity not proven |
| 7 | Flutter complete | Partial | Core observation/ops flows; pilot build docs |
| 8 | Met domain complete | Partial | Hourly/daily strong; other bulletin types incomplete |
| 9 | Full test suite | Partial | CI green on tip does not equal full isolation matrix live |
| 10 | Cybersecurity package | Partial | Docs + gates; no full pen-test report |
| 11 | Staging pilot | Not started | Needs secrets + host |
| 12 | Final delivery | Not started | Blocked on 4–11 |

**Immutable gates:** no old DB touch · no SQL apply without approval · no PR merge without approval.
