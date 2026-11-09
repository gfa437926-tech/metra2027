# Support and maintenance authorization matrix

**Status:** aligned with API code on `work/legacy-ui-migration-audit` (service-role + station permission gates).  
**Not a grant of database apply.** Persistence still uses server-side `service_role` or Npgsql ops role after API authorization.

## Principal identity
- Actor identity comes only from validated JWT `sub`. Request body cannot supply actor/station authority.
- `IStationAuthorizationService` must be configured; missing configuration fails closed (503 / forbid paths).
- `Supabase:ServiceRoleKey` is server configuration only — never in Angular/Flutter.

## Station boundary
- Every list, detail, create, and transition is under `/api/v1/stations/{stationId}/...`.
- Supabase REST filters include `station_id=eq.{stationId}` on reads; RPCs pass `p_station_id`.
- Detail responses must include `station_id` matching the route or return 404 (defense in depth).
- Npgsql path sets `SET LOCAL app.station_id` / `app.user_id` and filters `where station_id = @station_id`.

## Permission codes (API contract)

| Action | Permission | Wired in API | Covered by automated tests |
|---|---|---|---|
| Submit equipment fault | `equipment_fault.create` | Yes (`RequireStationPermission`) | Yes (unauthorized submit) |
| List / detail faults | `equipment_fault.read` | Yes | Yes (list/detail/cross-station/mismatch payload) |
| Review / reject | `equipment_fault.review` | Yes (`PermissionForTransition`) | Yes (theory map) |
| Assign technician | `equipment_fault.assign` | Yes | Yes (theory map) |
| Start / update work (`InProgress`) | `equipment_fault.update` | Yes | Yes (theory + integration update≠resolve) |
| Resolve / close | `equipment_fault.resolve` | Yes | Yes (theory + integration) |
| Submit support incident | `support_incident.create` | Yes | Yes |
| List / detail support | `support_incident.read` | Yes | Yes (cross-station + mismatch) |
| Review / reject support | `support_incident.review` | Yes | Yes (theory) |
| Assign support | `support_incident.assign` | Yes | Yes (theory) |
| Work / wait info (`InProgress`, `WaitingForInformation`) | `support_incident.update` | Yes | Yes (theory + integration) |
| Resolve / close support | `support_incident.resolve` | Yes | Yes (theory + integration) |
| Attachments | — | **No API routes** | N/A |
| Export | — | **No API routes** | N/A |
| `operations.analytics.read` | documented only | **Not wired** to maintenance/support endpoints | **Not tested** |

### Transition → permission

| Domain | Target status | Permission |
|---|---|---|
| Equipment | UnderReview, Rejected | `equipment_fault.review` |
| Equipment | Assigned | `equipment_fault.assign` |
| Equipment | InProgress | `equipment_fault.update` |
| Equipment | Resolved, Closed | `equipment_fault.resolve` |
| Support | UnderReview, Rejected | `support_incident.review` |
| Support | Assigned | `support_incident.assign` |
| Support | InProgress, WaitingForInformation | `support_incident.update` |
| Support | Resolved, Closed | `support_incident.resolve` |

Transitions also require route-level `*.read` via `RequireStationPermission` plus the finer permission above.

## Unwired / untested items
- Attachment upload/download endpoints (not present).
- Export endpoints (not present).
- `operations.analytics.read` (documentation only).
- Live PostgreSQL RLS proof (see `docs/security/postgres-isolation-test-plan.md`).
