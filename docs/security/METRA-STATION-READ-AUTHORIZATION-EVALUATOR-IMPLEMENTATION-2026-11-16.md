# Station read authorization evaluator — implementation boundary

**Code:** `backend/Metra.Api/Security/MetraStationReadAuthorization.cs`  
**Tests:** `backend/Metra.Api.Tests/Security/MetraStationReadAuthorizationTests.cs`  
**Status:** Implemented as a pure policy component; not registered or connected to HTTP/database adapters.

## Behavior

The evaluator accepts a server-resolved authorization snapshot, a requested station UUID, and one exact read permission. It denies by default unless the profile and membership are active and an active grant supplies the requested permission.

- `station` scope allows access only when the grant station UUID exactly matches the requested station.
- `global` scope is accepted only for `auditor` or `network_department_head` and only for an explicit global-read permission in the allow-list.
- Global-read permissions are limited to station directory, observations, audit, forecasts, alerts, recorder and instrument read projections.
- Write permissions, malformed permission identifiers, empty station IDs, missing identity, inactive profile/membership and inactive grants are denied.
- The evaluator does not infer authority from user-supplied station IDs, role claims, request bodies or role names alone.

## Required integration work

This component is deliberately not wired into endpoints yet. A production caller must build the snapshot from current trusted database state after validating the JWT subject, active profile, membership validity, role-assignment validity, assignment scope and permission catalogue. The HTTP layer must map every denial to a non-enumerating response and must not disclose whether an inaccessible station exists.

Before endpoint activation, the same scope rules must be enforced by the database/RLS or a narrow server-side database gateway. Otherwise direct Data API requests could bypass API-only checks. Add integration coverage for PostgREST/direct database paths and for list, detail, export, map, archive, attachment and child-resource routes.

## Verification boundary

Unit tests cover own-station allow, cross-station deny, auditor and network-head global-read allow, missing global permission, invalid role/scope, write denial, inactive profile/membership/grant, missing identity, empty station ID and malformed permission. These tests are committed but no CI run was returned for the current branch head when this document was written.

No hosted SQL, schema, grants, RLS policies, seed rows, credentials or runtime configuration were changed. No live endpoint was activated.