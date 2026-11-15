# METRA greenfield IAM catalogue — global station read proposal

**Date:** 2026-11-16  
**Status:** Read-only schema inspection complete; SQL proposal and isolated test added. Not applied to hosted Supabase.

## Verified current catalogue state

Read-only inspection of project `tbdnklyxjvbrilvnwgmq` confirmed:
- IAM tables use `iam.roles`, `iam.permissions`, `iam.role_permissions`, `iam.user_profiles`, `iam.memberships` and `iam.role_assignments`.
- Assignment scope values are constrained to `global`, `organization`, `unit`, and `station`. A global assignment must have null organization, unit and station identifiers; a station assignment must have organization and station identifiers and no unit identifier.
- Role assignments have active/pending/suspended/revoked/expired states and validity intervals. Memberships have active/pending/suspended/ended/rejected states and validity intervals.
- `auditor` exists and currently has `alerts.read`, `audit.read`, `forecasts.read`, `observations.read_station`, and `stations.read`.
- `network_department_head` does not exist yet.
- The permission catalogue currently has no explicit `*.read_all` permissions.
- `iam.user_profiles`, `iam.memberships` and `iam.role_assignments` currently contain zero rows. `catalog.stations` also contains zero rows.

## Proposal

`database/proposals/036_global_station_read_roles_and_permissions.sql` is a repeatable, proposal-only catalogue change. It adds seven explicit read-only permissions (`stations`, `observations`, `audit`, `forecasts`, `alerts`, `recorders`, and `instruments`), creates a non-assignable system role `network_department_head`, and associates only those read permissions with `auditor` and `network_department_head`.

No role assignment is created. A separate trusted approval process must create an active `scope_type='global'` assignment, and a global assignment must never be self-service or caller-controlled. No write, approval, role-management or membership-management permissions are added.

## Isolated verification

`database/isolated/11_bootstrap_greenfield_iam_catalogue.sql` creates a deliberately minimal, disposable fixture matching the inspected IAM table/constraint contract; it is not presented as a full canonical replay. `database/isolated/11_test_station_global_read_roles.sql` verifies the role definition, both roles' explicit global-read permission sets, absence of mutation privileges, and the global-scope constraint. Backend CI applies the fixture, proposal and test only inside a disposable PostgreSQL job. It does not apply anything to hosted Supabase.

## .NET policy alignment

`MetraStationReadAuthorization` now uses the actual IAM `scope_type='global'` value, not a made-up `global_read` value. Station grants are restricted to `stations.read` and `observations.read_station`; cross-station grants require one of the explicit `*.read_all` permissions and a global role. Mixed global/station/organization scopes are rejected.

## Remaining activation requirements

- Implement a trusted server-side authorization snapshot reader using the validated JWT `sub`, current profile, membership, role assignment, role and permission rows.
- Enforce the same visibility in a single atomic database read projection or equivalent RLS-backed gateway. Do not authorize in one request and fetch data in another if revocation could race.
- Add integration tests proving direct Data API access cannot bypass station isolation.
- Obtain explicit approval before any hosted DDL, grants, RLS changes, role assignments, or sample-data inserts.

No hosted database state, legacy database, credentials or secrets were changed.