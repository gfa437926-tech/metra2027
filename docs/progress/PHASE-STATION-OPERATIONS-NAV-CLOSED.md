# Phase closed: Flutter station-scoped operations navigation

**Date (UTC):** 2026-11-11  
**Branch:** `work/legacy-ui-migration-audit`  
**Scope:** Complete the operator path: select station → entry / review / ops / reports / forecasting catalogue tools.

## Acceptance for this phase

| Criterion | Status |
|---|---|
| Home shows whether a work station is selected | Done |
| Home shows station Arabic name + local code after directory selection | Done |
| Quick nav to hourly entry, review, ops, forecasting | Done |
| More menu: observation status + reports hub (station required) | Done |
| Review queue filter by type (hourly/daily/phenomenon) | Done |
| Station directory client search | Done |
| Ops hub: faults, support, reports, summary, archive, registration, assignment | Done (API-backed where endpoints exist) |
| Forecasting: catalogue compare + station profile (no invented live obs) | Done |
| `flutter analyze` / unit tests for selection label | Required green on tip after this commit |

## Explicitly out of this phase

- Live meteorological snapshot values in forecasting (pending approved contract + owner approval)
- Specialist units (rainfall/climate/agriculture/soil/AI/Climatol) — shells only
- Supabase SQL / migrations
- Merge to `main` / production publish
- Automatic CI path filters for work branch (needs `workflow` scope)

## Tip commit

Recorded after push of the analyze fix and ops hub scaffold for this phase.
