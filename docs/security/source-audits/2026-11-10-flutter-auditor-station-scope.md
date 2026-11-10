# Flutter auditor and station-head access boundary

Date: 2026-11-10
Repository: `gfa437926-tech/metra2027`
Branch: `work/flutter-observation-modules`
Status: source audit and implementation requirements; not an authorization-policy approval.

## User-approved product rule

The legacy `view-data/rec-main.html` workflow is restricted to two user classes:

- **Station auditor:** may inspect the station data within the explicitly approved all-stations audit scope.
- **Station head:** may inspect data for the one station currently assigned to that account.
- **All other roles:** must not see the workflow and must be denied by the API even when they call an endpoint directly.

The Flutter menu is presentation only. The API and authoritative permission checks must enforce the same boundary. A station ID supplied by Flutter is a resource selector, never proof of access.

## Findings in the current branch

1. `MetraHome` currently exposes a generic review navigation item to every authenticated session. It does not load an authoritative role/access context.
2. `ObservationReviewScreen` accepts a `stationId` from its caller. It calls the station-scoped queue endpoint; it does not establish that the signed-in user is a station auditor or station head.
3. `GET /api/v1/stations/{stationId}/observations` checks `observation.review`, `observation.approve`, or `observation.return_for_correction` through `IStationAuthorizationService.HasStationPermissionAsync`. This is a useful per-station fail-closed check, but it does not implement a global auditor scope or return the user's permitted station set.
4. The station permission RPC `metra_user_has_station_permission` requires an active account, active approved station and authority, approved current authority membership, approved current station assignment, active role, role-permission allow-list entry, and approved current non-revoked permission grant. It is explicitly station-scoped.
5. The existing authority permission RPC `metra_user_has_authority_permission` is authority-scoped, not a global all-country/all-authority grant. It may support a separately approved authority-wide auditor design, but it does not by itself prove a global auditor role.
6. The station-assignment workflow only allows `observer` and `station_auditor` as station assignment roles. That is not proof that every `station_auditor` is entitled to every station.
7. `GET /api/v1/stations/{stationId}/audit-log` is protected by `users.station.view`; it is an operational station audit log, not the `view-data` meteorological data-review dashboard.
8. The generic station directory endpoint returns the non-demo station catalogue to any authenticated caller. It must not be treated as an authorized review-data list or used to infer a user's operational access.

## Required design before enabling the Flutter route

### Trusted access context

Add a read-only authenticated API contract that returns only server-derived access information. It must distinguish:
- an explicitly approved all-stations auditor scope;
- a station-scoped station-head scope with exactly one current station assignment;
- no access.

Do not trust client-supplied role codes, station IDs, user IDs, or permission names. The API must derive the actor from the verified JWT `sub` claim. The access-context response is a UI convenience; every data endpoint must independently repeat authoritative authorization.

### Station data access

- Auditor: return data only for stations authorized by the canonical global audit permission/scope. Do not equate `station_auditor` on one station with all-stations access.
- Station head: ignore or reject any requested station ID that differs from the one current assigned station. The station scope must be resolved server-side.
- Other roles, inactive/suspended accounts, expired assignments/grants, demo/inactive/unapproved stations: deny and disclose no records.
- All list, detail, export, report, review, and decision endpoints must apply the same scope. Pagination and filters must not permit cross-station leakage.
- Keep station audit-log access separate from meteorological data review.

### Flutter behavior

- Load the trusted access context after authentication.
- Show the `view-data` entry only to the two approved classes.
- Auditor view: show an authorized station selector and cross-station filters only after the server confirms the global scope.
- Station-head view: omit the station selector and bind the view to the server-resolved assigned station.
- Everyone else: do not render the entry; deep-link attempts show a localized forbidden state.
- On 401, clear/refresh session according to the auth flow; on 403 show access denied; on 503 fail closed and do not show cached cross-station data.

## Required tests

1. Unauthenticated caller receives 401.
2. Authenticated user without either approved scope receives 403 and no data.
3. Station head reads own assigned station successfully.
4. Station head requests a second station by path, query, filter, or payload and receives 403 with no records.
5. Station head's assignment is inactive, expired, pending, or revoked: deny.
6. Auditor with approved global scope can list only eligible non-demo stations and read data across them.
7. A station-scoped `station_auditor` cannot be escalated to global scope.
8. User with an unrelated role/permission cannot access the dashboard.
9. Changing client-supplied user ID, role code, or station ID cannot change the server-derived scope.
10. Pagination, export, details, reports, and review decisions preserve the same scope.
11. Authorization RPC failure, malformed response, or missing configuration fails closed.
12. Flutter route visibility is tested separately from API denial tests.

## Safety and unresolved approval gates

- No database connection was opened and no SQL or migration was applied.
- No changes were made to the legacy repository, legacy database, or station catalogue.
- Do not create a new global permission code, role mapping, or database policy by assumption. First reconcile the authoritative role-permission registry and recover/verify its original allow-list and seed sources.
- The current code does not yet prove an approved global all-stations auditor permission. This is a blocking authorization gap, not a UI-only task.
- Do not claim the Flutter auditor dashboard or the role boundary is implemented until the API contract, server-side tests, Flutter route tests, and CI all pass.
