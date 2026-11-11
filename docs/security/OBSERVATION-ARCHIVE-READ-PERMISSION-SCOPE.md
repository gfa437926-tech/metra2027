# METRA 2027 — Observation Archive Read Permission Scope

- Date: 2026-11-11
- Status: policy scope for this delivery phase; implementation remains fail-closed until the grant-issuance controls and isolated database tests pass.
- Permission code: `observation.archive.read`

## 1. Eligible role audience

Only these station-scoped roles are eligible to be considered for an individual archive-read grant:

| Role code | Eligibility | Scope |
|---|---|---|
| `station_head` | Eligible | Only the exact station with an approved, current assignment |
| `station_auditor` | Eligible | Only the exact station with an approved, current assignment |
| `chief_auditor` | Eligible | Only the exact station with an approved, current assignment |

Eligibility is not a grant. No other role is eligible under this phase's policy. In particular, observer, system_admin, network_director, statistics_director, aftn_operator and other technical roles do not receive archive access through role inheritance.

## 2. Required individual grant

Every user must have a separate `permission_grants` row with all of the following:
- exact permission code `observation.archive.read`;
- authority scope matching the station assignment and station owner authority; the inspected `permission_grants` schema does not currently carry an exact `station_id` scope;
- `approval_status = 'approved'`;
- current `valid_from` and optional `valid_to`;
- no effective `revoked_at`;
- active account state;
- approved, current assignment to the requested station;
- approved and operational station.

The current grant row is authority-scoped and time-bounded; the requested station is separately constrained by an approved active `station_assignments` row and the station's owner authority. This prevents access to unassigned stations, but it does **not** prove a one-station-only grant when the same user has multiple approved station assignments under one authority. The policy's exact-station wording is therefore not yet satisfied for multi-station users. Knowing a station ID, observation ID, role name, or URL never authorizes access. Detail reads repeat the same checks and bind the record to the exact station ID.

## 3. No automatic assignment

This phase must not:
- insert permission rows for every user in an eligible role;
- add a broad role-level archive permission that bypasses individual grants;
- create grants during registration, station assignment, promotion or role changes;
- inherit archive access from observation review/approval permissions;
- create global or cross-station archive access.

No user permission grants are seeded by the migration. The migration does not insert into `metra_role_permissions`. The static security test asserts that the role allow-list does not silently create this permission. The integration fixture creates explicit test grants only inside the disposable test database.

## 4. Grant issuance gate

Before any real user grant is issued, the grant-issuance workflow must:
1. resolve the user's current approved station assignment and role;
2. reject role codes outside the eligible audience in section 1;
3. bind the grant to the same authority and exact station scope;
4. require a separate authorized approver (no self-approval);
5. record approver, reason, validity period and audit event;
6. support immediate revocation and enforce it on the next read request.

The currently reviewed schema confirms time-bounded assignments and explicit individual grants, but the role column name and grant-issuance RPC contract have not yet been certified for this workflow. Therefore this document does not authorize a grant-issuance implementation or any live grant. Until that contract is verified and tested, issue **zero** archive-read grants.

## 5. Read enforcement and unresolved station scope

The proposed archive RPCs enforce active account, approved individual permission, grant validity/revocation, approved station assignment, station authority ownership, and approved/active station state in the same RPC call as the station-filtered read. The backend derives the actor from the verified JWT `sub`; the service-role credential remains server-only.

**Open security decision:** because `permission_grants` has no verified `station_id` column, the current helper combines an authority-scoped grant with any active station assignment for that user under that authority. Before this can be described as exact-station authorization, the owner/security reviewer must either (a) explicitly approve authority-wide grants across all of a user's active assignments and revise this policy's exact-station requirement, or (b) approve a verified station-scoped grant model and its migration/test plan. Do not invent a column or alter the hosted schema. Until this is resolved, keep the PR Draft and issue zero live archive grants.

The read RPC migration is still a proposal and must only be applied to the disposable CI database for this phase. Do not apply it to a hosted METRA database until schema review, permission issuance review and integration tests are accepted.

## 6. Acceptance criteria

- [x] Eligible audience documented as three station-scoped roles.
- [x] No automatic role/user grants in the migration.
- [x] Read RPC requires a separate approved, time-valid, non-revoked individual grant.
- [ ] Grant-issuance workflow validates eligible role and has two-person/audited approval.
- [ ] Isolated database tests pass for active grant, missing grant, expired grant, revoked grant, inactive account, expired assignment and cross-station access, including station A versus station B under the same authority.
- [ ] Same-authority multi-station scope decision is approved and reflected accurately in schema, policy, UI and tests.
- [ ] Owner/security reviewer accepts the final role audience and grant issuance procedure.

The checked boxes describe repository artifacts, not deployment or production access. No live database state has been changed.
