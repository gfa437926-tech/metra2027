# C9.6 — Live Schema and Readiness Reconciliation

**Branch baseline:** \`b6cc12ec1a6d3013dd5f89d6ae32bc912fb02ca1\`  
**Scope:** read-only inspection of the configured METRA Supabase project, followed by isolated-schema alignment.  
**Hosted changes:** none.  
**Legacy project:** not accessed.  
**Release status:** NOT Production Ready.

## 1. Corrected understanding of the configured Supabase project

The configured project was not empty. Read-only inspection found:
- 65 station catalogue rows.
- 58,059 rows in \`public.metra_observation_records\`.
- 1,251 archive rows have \`station_id IS NULL\`.
- Seven archive observation types are present: hourly, daily, climate, soil, agricultural, phenomenon, and fieldclimate.

The archive RPCs now require \`station_id = p_station_id\` and \`is_demo = false\`. Unlinked records are never returned through station-scoped archive reads.

## 2. Actual authorization schema

The hosted \`permission_grants\` table is authority-scoped and has no \`station_id\` column. It includes \`authority_id\`, approval metadata, validity dates, and revocation state.

The corrected authorization contract is therefore:
- An approved, unrevoked \`observation.archive.read\` grant for the actor and station-owning authority.
- An active, approved authority membership.
- An active, approved assignment to the exact station.
- An active account, station, authority, country, and assignment role.
- Validity windows and approval metadata must be present.

The exact station boundary is enforced by \`station_assignments.station_id\`; the archive permission grant itself is authority-scoped. If the product requires a distinct archive grant per station even when a user is assigned to multiple stations, the current schema cannot express that. A dedicated user/station grant table and approval workflow would be required; it has not been added or applied.

The live role-permission catalogue has no \`observation.archive.read\` role mapping. Archive access is intentionally controlled by the explicit \`permission_grants\` row plus the exact active station assignment, rather than inventing a role mapping.

## 3. Provisioning state

Read-only aggregate checks found no approved authority memberships, station assignments, or active approved permission grants in the configured project at inspection time.

Consequences:
- Real staging login and station authorization cannot be demonstrated with this project as it stands.
- The archive endpoint will deny users until the necessary membership, assignment, and archive grant records are approved.
- Hourly/daily submission will likewise be denied until the required create/submit grants and assignments are provisioned.
- No test user or grant was inserted to make a demo appear successful.

## 4. Atomic database work now prepared

### Reads — proposal 033
- Station user directory.
- Station audit log.
- Observation review queue.
- Historical archive list and detail.

The RPCs accept actor ID from the trusted API, lock the authorization rows with \`FOR SHARE\`, and read protected data inside the same database transaction. The archive list uses keyset pagination, station filtering, demo exclusion, and payload redaction for raw/private/workflow keys.

### Writes — proposal 034
- Observation submission checks and locks \`observation.create\` and, when submitting, \`observation.submit\`.
- Observation decisions check and lock the appropriate \`observation.approve\` or \`observation.return_for_correction\` permission.
- Self-review is rejected.
- Idempotency is preserved.

The API no longer relies on a separate station permission pre-check for submission/decision as the security boundary. It derives actor identity from JWT \`sub\`; the database RPC is the final authorization decision.

### Isolated test coverage
The isolated PostgreSQL path now exercises:
- Same-station and cross-station access.
- Archive pagination, detail isolation, unlinked-record exclusion, and payload redaction.
- Revoked and expired grants/assignments.
- Submission idempotency, create/submit permissions, approval, return-for-correction, and self-review denial.
- Concurrent revocation while protected reads and a submission transaction are in flight.

These tests do not apply SQL to the hosted project.

## 5. Archive API implementation

The .NET archive service is wired to:
- \`get_station_observation_archive_atomic\`
- \`get_station_observation_archive_item_atomic\`

It passes actor ID from the validated JWT subject, maps SQLSTATE \`42501\` to HTTP 403, and returns 503 if the RPC is unavailable. The hosted database does not yet contain these proposed functions, so the API is not considered live until a reviewed migration is approved and applied.

## 6. Staging boundary

The configured project contains real archive data and is not a safe substitute for a staging database. No separate dedicated staging project was available in the connected project list. The legacy project was not opened or modified.

A real identity-provider staging test requires:
1. A dedicated staging Supabase project or approved isolated branch.
2. A test identity-provider configuration and test account.
3. Approved synthetic authority membership, station assignment, and permission grants.
4. Applying the reviewed schema only to that staging target.
5. End-to-end login, submit, review, archive, revoke, and concurrency tests.

No project was created and no hosted schema or data was changed.

## 7. Remaining integrations

AI, Climatol, and forecast-centre modules still require real provider/runtime contracts and configured credentials/data sources. Existing mock modules must remain visibly non-production until those integrations are implemented and verified. This report does not relabel mock services as live.

## 8. Release decision

**C9.6 complete as a read-only schema reconciliation and isolated implementation checkpoint.** The actual hosted schema differs from the previous assumed schema, and the required production/staging authorization records are not provisioned. Production deployment and hosted SQL application remain blocked pending explicit approval and staging evidence.
