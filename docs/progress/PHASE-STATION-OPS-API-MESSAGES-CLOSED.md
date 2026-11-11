# Phase closed: station operations API messaging (Flutter)

**UTC:** 2026-11-11  
**Branch:** work/legacy-ui-migration-audit  

## Scope completed
- Shared `ops_api_messages.dart` for equipment faults and support incidents.
- Submit / detail / transition error mapping (400/401/403/404/409/503).
- `EquipmentFaultScreen` and `SupportIncidentScreen` use shared messages.
- `MaintenanceReportScreen` documented as non-navigated local draft; live path is equipment fault API screen.
- Observation cycle messages already unified in prior commits.

## Explicitly deferred (end of project)
- GitHub Actions / Client CI green proof on tip
- Angular Chromium e2e
- SQL / Supabase apply
- main merge / staging
- Specialist units without API contracts

## Production ops entry points (Flutter)
1. Select station in directory
2. Bottom nav: ops hub OR home quick nav
3. Faults, support, reports, summary, archive, registration review, assignments
