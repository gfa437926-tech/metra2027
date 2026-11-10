# METRA Weather Intelligence — phase progress tracker

Updated from repository evidence only. No live DB writes.

| Phase | Title | Status | Notes |
|---|---|---|---|
| 1 | DB isolation review | Partial | Repo targets new Supabase only; staging table origin still owner decision |
| 2 | DB design close | Partial | Schema inventory + SQL review package published for approval |
| 3 | Security & permissions | In progress | JWT + station checks; service-role residual risk documented |
| 4 | SQL apply | **Blocked** | Awaiting explicit owner approval |
| 5 | .NET API complete | Partial | Observations, stations, users, faults, support present |
| 6 | Web UI complete | Partial | Core routes; full legacy parity not proven |
| 7 | Flutter complete | Partial | Observation input stabilized; CI green on recent tip |
| 8 | Met domain complete | Partial | Hourly/daily strong; other bulletin types incomplete |
| 9 | Full test suite | Partial | Backend + Client CI green does not equal full live isolation matrix |
| 10 | Cybersecurity package | Partial | Docs + gates; no full pen-test |
| 11 | Staging pilot | Not started | Needs secrets + host |
| 12 | Final delivery | Not started | Blocked on 4–11 |

**Immutable gates:** no old DB · no SQL apply without approval · no PR merge without approval.

## Recent verified tip

- Branch: `work/legacy-ui-migration-audit`
- Flutter observation forms: SingleChildScrollView + Column (validate/submit reliability)
- Client CI and Backend CI reported success on tip `25c1c06` class commits


## Phase E
Status: review package published; **awaiting owner apply approval**.


## Phase H — delivery
Status: **documentation and acceptance gates published**. Production cutover blocked on owner approvals (DB apply, secrets, staging E2E, PR merge).
