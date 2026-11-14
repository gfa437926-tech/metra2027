# METRA 2027 — Master Continuation Status

**Local HEAD (before this commit):** `93df09a8d7fa181dde01c7619e58ac3bf0660b56`  
**Remote tip (Flutter C7 branch):** `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12`  
**Date:** 2026-11-13

## Reality check

| Item | State |
|------|--------|
| Original Flutter app `mobile/metra_mobile/` | Preserved; screens wired in home nav |
| Local Backend C2–C9 line | Present locally; **not fully on GitHub** |
| PR #34 Flutter archive | Open Draft on `fix/flutter-client-ci-mainline-2026-11-11` |
| PR #35 Archive API + security | Open Draft; **explicit station-only gap documented in PR body** |
| Hosted Supabase changes | **None applied** |
| Production deploy | **Not done** |

## Work executed in this continuation

1. **Defect documented + proposal SQL:** observation decision RPC inserts decision tokens into `event_type` CHECK that only allows `approved`/`returned` — proposal at `database/proposals/observation_decision_event_type_fix.sql`.
2. **Flutter test hardening:** `forecast_centre_screen_test.dart` scrolls lazy ListView before asserting `مصدر الإحداثيات` / `survey` / `GPS`.
3. **No hosted apply, no push, no PR merge.**

## Security priorities still open (need owner approval to apply)

- R4 station-bind for `observation.archive.read` (`database/proposals/c25_readiness/`).
- Grant active uniqueness indexes.
- PR #35 same-authority A/B station isolation before merge.
- TOCTOU atomic read for archive queue (design + tests; no hosted write).
- Prefer `metra_api_runtime` over broad `service_role` where feasible.

## Functional classification (Flutter)

| Area | Class |
|------|--------|
| Login, stations, hourly/daily entry, review, reports hub, user management | Present / live-oriented |
| Archive UI | Present; API **503** fail-closed |
| AI / Climatol / Forecast / Electronic audit UI | **Mock** |
| Settings folder | Empty (config via MetraConfigurationScreen) |

## Launch decision (unchanged)

**CONDITIONALLY READY** — not PRODUCTION READY.

## Next actions requiring approval

1. Non-force Git sync of local Backend history to GitHub.
2. Isolated then hosted application of decision event_type + R4 proposals.
3. PR #34/#35 security closure before merge.
4. Staging IdP + deploy.

## Next engineering (no approval if local-only)

- Expand API/integration tests for decision endpoint mapping.
- Isolated SQL regression for event_type fix.
- Align PR branches with R4 proposal once approved.
