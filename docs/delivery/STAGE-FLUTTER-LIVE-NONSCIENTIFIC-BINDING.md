# Flutter ↔ .NET live binding (non-scientific paths)

**Branch:** `work/execution-master-2026-11-14`  
**Scope:** Option (A) — bind Flutter to live non-scientific .NET read paths only.

## What changed

### `mobile/metra_mobile/lib/core/api/metra_api_client.dart`
Added live client methods:
- `getStationUsers`
- `getRegistrationRoles`
- `getMyRegistrationStatus`
- `getAuthorities`
- `getAuthorityAccessQueue`
- `getAuthorityAccessAudit`
- `getAuthorityMembershipRoles`
- `getAuthorityPermissionOptions`

Added `MetraJsonRow` and resilient list/object JSON parsing (array, `{data|items|rows}`, or single object).

### `mobile/metra_mobile/lib/features/admin/user_management_screen.dart`
Replaced static empty tabs with live FutureBuilder panes:
- Station users (`/api/v1/stations/{id}/users`)
- Registration status + requestable roles
- Authority catalogue, membership roles, permission options, access queue
- Authority access audit

Honest 401/403/503 messaging; no fake directory rows.

### `mobile/metra_mobile/lib/features/home/metra_home.dart`
Passes `api` and `selectedStationId` into `UserManagementScreen`.

### `mobile/metra_mobile/lib/core/api/service_readiness.dart`
Marked live (client calls .NET; failures surface as HTTP errors):
- `stationAudit`, `observationQueue`, `stationUsers`, `registrationRead`, `authorityAccessRead`

Still **gated**: `observationSubmit`, `observationDecision`  
Still **mock/fail-closed**: archive, AI, Climatol, forecast, electronic audit UI

### Tests
Extended `test/metra_api_client_test.dart` for the new methods.

## Explicitly out of scope
- Scientific observation contract approval
- Enabling archive production reads
- Hosted Supabase migrations / RPC deploy
- AI / Climatol / forecast providers
- Merge to `main`

## Verification notes
Local environment lacks Flutter SDK / sufficient RAM; rely on GitHub Actions Flutter job after push.
