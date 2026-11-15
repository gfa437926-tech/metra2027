# METRA 2027 — Greenfield RLS and Data API Access Matrix

**Status:** Review proposal; not approved for deployment  
**Evidence:** Read-only Supabase inspection on 2026-11-15  
**Target:** Greenfield schemas in the new METRA Supabase project  
**Execution boundary:** No SQL, policies, grants, storage rules, or hosted configuration are changed by this document.

## 1. Security decision

All 21 tables identified by the Security Advisor as RLS-enabled without direct policies remain **deny by default**. Do not add blanket policies to silence the advisor. A table may intentionally have no direct policy when it is private to a trusted backend operation.

The default client boundary is:

1. Flutter never connects to Postgres using a privileged credential.
2. Flutter calls the authenticated .NET API.
3. The API derives the actor from a validated access token; request-body actor IDs, role names, organization IDs and station scopes are never authority.
4. Database operations use end-user JWT/RLS where practical. If a narrow privileged operation is unavoidable, its authorization, fixed search path, execution grants, owner privileges, input validation and audit transaction must be explicitly reviewed and tested.
5. Files remain private. A successful metadata read does not grant access to the object bytes.

The matrix below is a conservative starting point for review, not a final role assignment or authorization implementation.

## 2. Table-by-table proposal

| Table | Initial exposure decision | Candidate authorized use | Mandatory boundary |
|---|---|---|---|
| `alerts.alert_rules` | Private backend configuration | Alert administration through a dedicated API | No direct client CRUD; validate organization ownership and audit every rule change |
| `catalog.station_capabilities` | Scoped authenticated read; controlled write | Read capabilities only for approved stations visible to the caller; catalogue managers maintain them | Station/organization scope; do not expose draft or unapproved catalogue rows |
| `catalog.station_identifiers` | Scoped authenticated read; controlled write | Resolve identifiers for approved stations; catalogue managers maintain identifiers | Enforce identifier type, uniqueness and validity interval; prevent cross-organization writes |
| `catalog.station_operating_periods` | Scoped authenticated read; controlled write | Show operating history for authorized stations; catalogue managers record corrections | Preserve history; no destructive overwrite; station scope and audit |
| `files.objects` | Private backend-only metadata | Authorized API resolves object metadata and issues short-lived access after checking the parent resource | No public bucket; owner field is not sufficient authorization; object key never grants access |
| `iam.access_reviews` | Restricted security/audit API only | Authorized security reviewers inspect and record access reviews | Reviewer permission, immutable history, no self-approval where separation of duties applies |
| `integration.execution_runs` | Private worker/backend; sanitized operator read model | Operators inspect status and bounded diagnostics | Never expose secrets, raw payloads or internal stack traces; organization scope |
| `integration.sources` | Private integration configuration | Integration administrators manage source definitions | Credentials stored separately; no secret-bearing fields in API responses |
| `observations.attachments` | Scoped authenticated API only | Author/reviewer with permission on the parent observation can inspect attachment metadata | Re-check parent observation scope on every access; private object; audit downloads and changes |
| `observations.quality_flags` | Scoped authenticated API only | Assigned observers/reviewers read flags; authorized quality reviewers resolve them | Exact station/observation scope; controlled flag codes; resolution actor and timestamp; append audit |
| `operations.equipment` | Station-scoped API | Station/equipment managers read and maintain equipment inventory | Station and organization scope; immutable deployment/calibration history |
| `operations.equipment_faults` | Station-scoped API | Reporter and authorized station/maintenance staff read; authorized staff manage lifecycle | Reporter identity from JWT; station assignment; controlled state transitions |
| `operations.equipment_fault_events` | Append-only station-scoped API | Authorized maintenance actors append events; authorized station staff read | No update/delete path; actor, reason, timestamp and fault scope are server-derived |
| `operations.support_incidents` | Restricted support API | Reporter, assignee and authorized support operators | Need-to-know access; avoid broad station-wide disclosure of sensitive incident content |
| `operations.support_incident_events` | Append-only restricted support API | Authorized reporter/assignee/support actors append and read relevant events | No update/delete path; redact credentials and sensitive payloads |
| `weather.forecast_parameter_mappings` | Private backend configuration | Weather-data administrators maintain provider-to-reference mappings | Version changes; validate parameter/unit compatibility; audit changes |
| `weather.forecast_points` | No direct table access; published read model only | Consumers read approved forecast products through a bounded projection | Exclude unapproved/incomplete runs; enforce provider/run/parameter scope; no client writes |
| `weather.forecast_runs` | Private write; sanitized approved-run read model | Workers create runs; authorized consumers inspect published run metadata | Only completed/approved runs are exposed; immutable run provenance |
| `weather.ingestion_runs` | Private worker/backend; sanitized operator read model | Integration operators inspect ingestion health | No raw secrets or provider credentials; bounded diagnostics and organization scope |
| `weather.provider_payload_references` | Private backend-only | Workers resolve private source payload references | No public object URL; private storage and retention policy; access audit |
| `weather.providers` | Private configuration; optional safe catalogue projection | Administrators configure providers; clients may see a sanitized enabled-provider list if required | Never return credentials, tokens, private endpoints or secret configuration |

## 3. Required authorization inputs

Before writing a policy or endpoint, document and test all applicable dimensions:

- Validated JWT subject and active `iam.user_profiles.profile_state`.
- Active organization and membership, including `valid_from` / `valid_to`.
- Active role assignment or direct permission grant and its validity interval.
- Exact station and organization relationship; never infer station authority from a client-provided code.
- Parent-resource authorization for attachments, quality flags, equipment faults and support events.
- Action-specific permission: read, create, update, decide, resolve, administer or audit.
- Separation-of-duties rules for self-review, access approval and high-impact administration.
- Append-only audit for security-sensitive and scientific decisions.

Never use user-editable profile metadata as an authorization source. A valid authenticated session alone is not permission to read another station or organization.

## 4. Minimum negative-test matrix

Every table-specific policy or API operation must have tests for:

1. Anonymous caller is denied.
2. Authenticated caller without the required capability is denied.
3. Same role in a different organization is denied.
4. Same organization but a different station scope is denied where station scope applies.
5. Expired membership, assignment or grant is denied.
6. Suspended/closed profile is denied.
7. Draft, rejected or unapproved station/resource is not exposed to operational users.
8. Caller cannot supply or override actor, reviewer, owner, organization or station scope.
9. Parent-resource authorization is rechecked for attachment and child-row access.
10. Unauthorized responses do not reveal whether a protected resource exists.
11. Concurrent state transitions cannot bypass authorization or create duplicate decisions.
12. Audit records are committed atomically with the protected mutation and cannot be edited by ordinary application roles.

Also test direct PostgREST access separately from .NET API access. An API test alone does not prove RLS correctness.

## 5. Deployment sequence (blocked pending review)

1. Review the ERD/data dictionary and this access matrix.
2. Confirm which operations are direct user-JWT/RLS and which, if any, require a narrowly scoped privileged server operation.
3. Implement policy/function changes only in a disposable PostgreSQL environment from the canonical, approved migration set.
4. Test role grants, RLS, function ownership, `SECURITY INVOKER`/carefully justified `SECURITY DEFINER`, fixed `search_path`, PUBLIC execute revocation and Data API exposure.
5. Run the full negative-test matrix and Supabase Security Advisor.
6. Obtain explicit approval before applying any schema, policy, grant, storage or seed-data change to the hosted project.
7. Re-run the same tests and advisors after deployment.

## 6. Current release blockers

- The existing .NET Supabase adapters still contain legacy `public.*` table/RPC mappings and use a server-side service-role credential. They are not greenfield adapters and must not be considered production-ready merely because CI passes.
- Flutter keeps schema-incompatible workflows gated; AI, CLIMATOL, forecast-centre and archive workflows remain unavailable/mock until real services exist.
- The greenfield API persistence mapping is a blueprint; normalized-schema RPCs and least-privilege adapters are not deployed.
- The current CI Path N and transfer-pack checks use legacy baseline/synthetic fixtures; they do not prove a fresh replay of the normalized greenfield schema.

**No database change is authorized by this matrix.**
