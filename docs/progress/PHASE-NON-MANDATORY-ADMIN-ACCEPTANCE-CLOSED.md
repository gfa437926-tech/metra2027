# Phase closed (non-mandatory): admin messaging + manual acceptance pack

**UTC:** 2026-11-11  
**Branch:** work/legacy-ui-migration-audit  

## Done
- `admin_api_messages.dart` for registration decision, assignment request/decision/revoke, archive.
- Wired: `registration_review_screen`, `station_assignment_screen`, `manual_archive_screen`.
- Manual acceptance scenarios: `docs/acceptance/MANUAL-ACCEPTANCE-SCENARIOS-STATION-OPS.md`.
- Unit tests for admin message mapping.

## Still mandatory / deferred (owner or project end)
- GitHub Actions green on tip
- SQL / Supabase apply
- Live observation snapshot for forecasting
- Specialist unit API contracts
- Angular parity completion
- main merge / staging / production
