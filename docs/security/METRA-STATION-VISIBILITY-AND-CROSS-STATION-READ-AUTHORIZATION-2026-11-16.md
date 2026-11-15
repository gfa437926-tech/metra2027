# METRA 2027 — Station Visibility and Cross-Station Read Authorization

**Status:** User decision recorded; implementation specification for review  
**Decision date:** 2026-11-16  
**Target:** Greenfield identity, station catalogue, observation and audit APIs  
**Execution boundary:** Documentation only. No hosted SQL, DDL, grants, RLS policies, seed rows, secrets or runtime configuration changed.

## 1. Confirmed visibility rule

The user approved this station visibility model:
- An ordinary station user may read records belonging to their currently assigned station only.
- The Head of the Network Department may read across all approved stations.
- Auditors may read across all approved stations for audit/review purposes.
- Cross-station visibility is a read scope, not a blanket grant to create, edit, approve, assign users, manage identities, or administer the platform.
- Every non-read action continues to require its own permission and scope check.
- A station user must not gain cross-station access by changing a station ID, station code, organization ID, role, query filter, pagination cursor, or request-body actor field.

The word “all” means all stations within the METRA station catalogue and station-scoped records the caller is separately authorized to read. It does not expose private identity, integration secrets, support incidents, credentials, or unrelated administrative data.

## 2. Existing schema evidence

Read-only inspection of the current greenfield Supabase project found:
- iam.roles already contains station_manager, observer, maintenance_technician, auditor, catalogue_reviewer, organization_admin, and platform_admin.
- The auditor role currently has audit.read, alerts.read, observations.read_station, stations.read, and forecasts.read.
- No network_department_head role was present in the inspected role catalogue.
- iam.role_assignments supports scope_type, organization_id, unit_id, and station_id; assignments are linked to memberships.
- catalog.stations has owner_organization_id, and station-scoped domain records reference the station UUID.
- The station catalogue currently contains zero station rows.
- Current RLS grants do not make the caller-JWT .NET station reader operational. It remains fail-closed until the reviewed runtime access path is implemented.

This is evidence about the inspected project state, not authorization to mutate it.

## 3. Authorization model

Authorization must be resolved from trusted server/database state:
1. Validate the access token and derive the subject from its sub claim.
2. Require an active iam.user_profiles row.
3. Require an active membership whose validity interval includes the current UTC instant.
4. Require an active role assignment whose validity interval includes the current UTC instant.
5. Resolve station scope from the assignment and membership; never accept scope from request data.
6. Resolve the permission for the requested operation.
7. Apply visibility scope: station means exact assigned station_id only; global_read means all approved, operationally visible stations, but only for explicitly granted read permissions.
8. Deny by default if identity, membership, assignment, permission, station ownership or scope is missing, ambiguous, expired, suspended or inconsistent.

### 3.1 Role-to-scope proposal

| Role | Directory/read scope | Mutations |
|---|---|---|
| observer | Assigned station only | Observation-entry permissions at assigned station only |
| station_manager | Assigned station only | Station workflow permissions at assigned station; no cross-station override |
| maintenance_technician | Assigned station only | Equipment/fault permissions at assigned station |
| auditor | Global read across approved stations | No business-data mutations by virtue of auditor role |
| network_department_head (new role required) | Global read across approved stations | No automatic mutation rights; network-management permissions separately granted |
| catalogue_reviewer | Catalogue records covered by explicit review permission/scope | Catalogue decisions only through dedicated review operations |
| organization_admin | Organization scope only, unless separately granted global read | Organization administration only |
| platform_admin | No implicit scientific-data bypass; explicit audited permissions required | Platform administration only |

A role name alone is not enough to authorize access. The active assignment scope and explicit permission must agree. The existing auditor permission set is not yet a complete implementation of global station-scoped reads.

## 4. Permission additions to review

The current permission catalogue has stations.read and audit.read, but no explicit stations.read_all or audit.read_all permission in the inspected set. Before deployment, review whether to add:
- stations.read_all: read the approved station directory across station scopes.
- observations.read_all: read station observations across station scopes for explicitly assigned auditors.
- audit.read_all: read station audit events across station scopes.
- network.read_all: optional domain permission only if the network-department head needs additional network-specific station data.

These permissions must not be inferred from stations.read, nor granted to all authenticated users. Auditors should receive only global read permissions approved for audit duties. The new network role should receive only required global read permissions and separately reviewed network-management permissions.

## 5. Mandatory positive and negative tests

| Actor | Requested resource | Expected |
|---|---|---|
| Observer assigned to Station A | Station A | Allow if operation permission is present |
| Observer assigned to Station A | Station B | Deny; no data or existence leakage |
| Station manager assigned to Station A | Station B | Deny |
| Maintenance technician assigned to Station A | Station B | Deny |
| Auditor with active global-read assignment | Any approved station | Allow read-only where corresponding permission is present |
| Auditor | Create/update/approve station observation | Deny unless a separate non-auditor permission and scope explicitly authorizes it |
| Network department head with active global-read assignment | Any approved station | Allow read-only |
| Network department head | Mutate station data | Deny unless a separate operation-specific permission authorizes it |
| User with expired or revoked assignment | Previously assigned station | Deny |
| Suspended profile or inactive membership | Any station | Deny |
| Caller supplies another station ID or role in request body | Other station | Deny; ignore caller-supplied authority |
| Auditor or network head without global-read assignment | Other station | Deny |
| User assigned two stations under separately valid assignments | Either assigned station | Allow only where active assignment and operation permission match |

Also verify direct PostgREST cannot bypass API checks; global read is limited to approved stations and relevant projections; pagination, filters, exports, maps, archive, attachments and child resources apply the same scope; child rows/files require parent-station authorization; cross-station reads are audited; and inaccessible resources do not leak existence.

## 6. Implementation sequence

1. Preserve this business rule in the canonical authorization matrix.
2. Review the existing role/permission catalogue and define exact permissions for auditors and the Head of the Network Department.
3. Add network_department_head and global-read permission definitions only in a disposable migration after schema review.
4. Implement a single server-side authorization evaluator used by directory, observations, archive, audit, exports, maps and file metadata endpoints.
5. Implement RLS or narrow database operations so direct Data API access enforces the same scopes.
6. Add integration tests for all positive and negative cases above.
7. Keep the feature flag disabled until tests, security review and explicit hosted-change approval are complete.

## 7. Non-changes

- No changes were made to the hosted Supabase project.
- No station records or user-role assignments were inserted.
- No grants, RLS policies, functions, migrations, storage settings or secrets were changed.
- No legacy database or legacy station catalogue was read for migration or modified.
- The existing .NET station directory reader remains disabled by default and must fail closed until the runtime authorization path is ready.