# METRA — Role authorization negative-test plan

**Target:** NEW METRA staging only  
**Repository:** gfa437926-tech/metra-weather-intelligence2026  
**Status:** Prepared; not executed  
**Safety:** Use synthetic users and synthetic stations. Never run against the legacy project or production.

## Required synthetic fixtures

- Authority North with active stations A1 and A2; Authority South with active station B1.
- User N-Head: active station manager assigned only to A1.
- User N-Observer: active observer assigned only to A1.
- User N-Reviewer: active reviewer assigned only to A1.
- User S-Head: active station manager assigned only to B1.
- User System-Reviewer: separately approved system-review permission.
- User Basic: active account with no operational grants.
- User Suspended: suspended account with otherwise valid historical assignments.
- A separate target user for grant and role assignment attempts.
- Permission registry and role-permission seed must be recovered and verified before these fixtures are created.

## Negative test cases

| ID | Attempt | Expected result |
|---|---|---|
| AUTH-001 | Basic user reads station A1 operational observations | Deny; no records disclosed |
| AUTH-002 | N-Head reads or lists operational observations for A2 | Deny; A2 is not assigned to N-Head |
| AUTH-003 | N-Head reads, creates, submits, edits, approves, or returns an observation for B1 | Deny every operation |
| AUTH-004 | N-Observer invokes approve or return-for-correction on A1 | Deny; create permission does not imply review permission |
| AUTH-005 | N-Reviewer creates/submits observations without observation.create | Deny; review permission does not imply write permission |
| AUTH-006 | User submits a valid station ID but an observation ID belonging to another station | Deny in the database transaction; no row changes |
| AUTH-007 | User supplies another user's ID as actor/creator/reviewer | Ignore client identity or deny; derive actor only from verified JWT |
| AUTH-008 | Suspended user uses a still-valid station assignment | Deny |
| AUTH-009 | Assignment is expired or not yet valid | Deny before/after its validity interval |
| AUTH-010 | Permission grant is expired, not yet valid, rejected, revoked, or inactive | Deny |
| AUTH-011 | Permission grant has a future revoked_at timestamp | Allow only until that exact timestamp; deny at and after it |
| AUTH-012 | Station is pending, inactive, suspended, decommissioned, or demo | Deny operational write/review paths |
| GRANT-001 | Basic user inserts or updates permission_grants directly | Deny at database ACL/RLS |
| GRANT-002 | metra_api_runtime attempts INSERT/UPDATE/DELETE on permission_grants before an approved grant workflow exists | Deny |
| GRANT-003 | Station manager attempts to grant a permission they do not hold | Deny |
| GRANT-004 | Station manager attempts to grant a permission outside their own station/authority scope | Deny |
| GRANT-005 | Grantor attempts to grant a permission with greater delegation rank than their own explicitly delegable ceiling | Deny |
| GRANT-006 | Grantor attempts to grant system, director, or authority-management permissions from a station-scoped role | Deny |
| GRANT-007 | User attempts to grant a permission to themselves | Deny |
| GRANT-008 | Requester attempts to approve their own grant | Deny in the database transaction |
| GRANT-009 | Grantor and approver are the same actor where separation of duties is required | Deny |
| GRANT-010 | Unknown or inactive permission code is inserted or approved | Deny; canonical permission registry required |
| ROLE-001 | Station manager assigns system_admin, authority_manager, director, reviewer, or another management role through station assignment RPC | Deny |
| ROLE-002 | Station manager assigns a user to a station owned by another authority | Deny |
| ROLE-003 | Station manager assigns a target without active membership in the station's authority | Deny |
| ROLE-004 | Requester approves their own station assignment | Deny |
| ROLE-005 | Requester approves their own registration request | Deny |
| ROLE-006 | Same person performs both station and system approval stages | Deny |
| ROLE-007 | Registration requests an inactive or non-requestable role | Deny |
| ROLE-008 | Client changes requested_role_code after submission to a higher role | Deny; immutable request snapshot / database validation |
| RPC-001 | anon invokes a privileged SECURITY DEFINER RPC | Deny |
| RPC-002 | authenticated invokes a privileged SECURITY DEFINER RPC directly | Deny unless the specific RPC is deliberately designed for that role and independently validates identity |
| RPC-003 | service_role invokes a function intended only for metra_api_runtime, or vice versa | Deny unless explicitly granted |
| RPC-004 | Untrusted role creates objects in any schema in a SECURITY DEFINER search_path | Deny via schema ACL |
| RPC-005 | Function has PUBLIC EXECUTE due to CREATE OR REPLACE default ACL | Test must fail; explicit revoke required |
| RPC-006 | Function owner is an application login or a role with unnecessary superuser/CREATEROLE privileges | Test must fail |

## Required database catalog assertions

Run only on the approved NEW METRA staging database after the complete migration chain is reconciled:

1. Enumerate every SECURITY DEFINER function, owner, schema, identity arguments, proconfig/search_path, and proacl.
2. Assert no SECURITY DEFINER function has PUBLIC EXECUTE unless a documented exception is approved.
3. Assert anon/authenticated have no EXECUTE on privileged functions.
4. Assert only the intended server role has EXECUTE for each function; distinguish service_role from metra_api_runtime.
5. Assert untrusted roles have no CREATE on public/private/other schemas included in privileged search paths.
6. Assert RLS is enabled on identity, membership, assignment, permission grant, role catalogue, and audit tables.
7. Assert anon/authenticated have no table privileges on protected identity and authorization tables.
8. Assert metra_api_runtime has only the specific SELECT/EXECUTE privileges required by the reviewed API paths, not blanket table write privileges.
9. Assert permission codes reference a canonical registry and role-permission rows reference active role and permission definitions.
10. Assert audit records preserve requester, approver, target, scope, reason, timestamp, and before/after state.

## Execution gates

- Do not execute until the missing original role-permission table/allow-list and seed migrations are recovered or a separately labelled reconstructed baseline is approved.
- Do not create real users or real permissions for testing.
- Run the suite first on a disposable NEW METRA staging branch/database.
- Capture SQLSTATE, HTTP status, response body shape, and before/after row counts for every denial.
- A denied attempt must produce no mutation and no information leak.
- A passing unit test is not a substitute for these database-backed integration tests.
- No legacy repository/database access, migration replay, or production write is permitted.


## Permission composition consistency tests

The currently reviewed source has different authorization composition by endpoint. The station permission helper requires BOTH an allowed role-permission row and an approved individual grant. The station-directory effective permission list uses the UNION of role permissions and individual grants. Registration review checks individual grants plus separate assignment/workflow constraints.

| ID | Fixture / attempt | Expected assertion |
|---|---|---|
| AUTH-013 | Role contains observation.create; no direct individual observation.create grant | Station-scoped observation create is denied by metra_user_has_station_permission |
| AUTH-014 | Direct individual observation.create grant; role lacks observation.create | Station-scoped observation create is denied by metra_user_has_station_permission |
| AUTH-015 | Direct stations.read grant; role lacks stations.read | Current station-directory behavior permits directory read; flag for policy approval |
| AUTH-016 | Role contains stations.read; no direct stations.read grant | Current station-directory behavior permits directory read; compare against intended canonical policy |
| AUTH-017 | Direct registrations.station.approve grant but no station assignment | Registration station-review queue and decision must deny |
| AUTH-018 | Direct registrations.system.approve grant but no distinct prior station approval event | System-review decision must deny |
| AUTH-019 | Role-derived registrations.system.approve without a direct individual grant | Current registration-approvals route denies; confirm whether this individual-grant-only design is intentional |

Do not alter expected behavior by guesswork. The policy owner must choose one canonical composition rule (role AND direct grant, role OR direct grant, or scoped capability model) and then align every endpoint and database predicate before release.
