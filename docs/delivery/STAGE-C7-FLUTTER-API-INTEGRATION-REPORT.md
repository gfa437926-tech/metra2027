# Stage C7 — Flutter / .NET API Integration

**App path:** `mobile/metra_mobile/` only (no new project)

## Changes
1. **Archive route alignment** — client path `…/observation-archive` matches .NET (`ObservationArchiveEndpoints`).
2. **Error mapping** — `_send` extracts JSON `code`/`error` (e.g. `archive_service_unavailable` on 503).
3. **`service_readiness.dart`** — classifies live vs mock services (AI/climatol/forecast remain mock).
4. **Contract doc** — `docs/mobile/FLUTTER-DOTNET-API-CONTRACT.md`
5. **Tests** — archive path expectation + 503 body mapping case in `test/metra_api_client_test.dart`

## Mock policy
- Live-capable when `METRA_API_BASE_URL` set: stations, audit, queue, submit, decision, archive (archive still API 503).
- Mock retained: AI, Climatol, forecast centres, electronic audit UI extras.
- Auth remains Supabase session → Bearer to API.

## Not done
- Removing mocks wholesale  
- Enabling production archive data  
- Angular / new Flutter app  
