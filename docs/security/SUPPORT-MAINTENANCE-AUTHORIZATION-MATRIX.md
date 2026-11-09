# Support and maintenance authorization matrix

**Status:** aligned with API and transition RPC permission codes on `work/legacy-ui-migration-audit` (service-role + station permission gates).  
**Not a grant of database apply.** Persistence still uses server-side `service_role` or Npgsql ops role after API authorization.

## Principal identity
- Actor identity comes only from validated JWT `sub`. Request body cannot supply actor/station authority.
- `IStationAuthorizationService` must be configured; missing configuration fails closed (503 / forbid paths).
- `Supabase:ServiceRoleKey` is server configuration only — never in Angular/Flutter.

## Database role and column-grant boundary

The Npgsql adapter's `ConnectionStrings:MetraOps` connection must use a
dedicated non-superuser login provisioned out of band. That login should be a
member of `metra_api_runtime`; the migration-created group role is NOLOGIN
and is itself a member of `metra_ops_faults`. Neither group role may be
SUPERUSER, CREATEDB, CREATEROLE, REPLICATION, or BYPASSRLS.

The `metra_ops_faults` group has:
- SELECT and INSERT on equipment-fault and support-incident operational tables.
- UPDATE only on equipment fault columns `status`, `assigned_to`, `progress_percent`, `progress_note`, `updated_at`.
- UPDATE only on support incident columns `status`, `assigned_to`, `updated_at`.
- SELECT and INSERT on operational audit tables; no UPDATE or DELETE on audit.
- USAGE/SELECT only on the two operational audit identity sequences.
- No DELETE on operational records and no direct table grants to `anon`
  or `authenticated`.

The PostgreSQL 17 disposable CI test `ops_role_grant_boundary_pg_test.sql`
checks role flags, runtime membership, client denials, column-level UPDATE,
audit immutability grants, and sequence boundaries. It does not test the
privileges of a future hosted login until that login is provisioned and tested
in an approved staging environment. The Supabase `service_role` used by
REST adapters remains a separate highly privileged server-only credential;
it must never be placed in Angular/Flutter or treated as the constrained
Npgsql runtime role.

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
- The SQL transition RPC permission mapping is guarded by `database/tests/verify_ops_transition_permission_contract.sh`; live role grants and RLS still require disposable PostgreSQL execution.
