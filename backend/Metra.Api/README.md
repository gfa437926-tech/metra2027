# METRA API — Authentication and deployment

## Supabase access tokens

The API validates Supabase Auth access tokens using ASP.NET Core JWT Bearer authentication.

- Issuer: `https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1`
- Audience: `authenticated`
- Signature, issuer, audience, and expiration are validated.
- All endpoints require an authenticated user by default. Only health and readiness endpoints are anonymous.
- JWT claims are kept in their original names; `sub` is the user identifier.

## Container build and run

Build from the repository root so the Docker build context contains the API project:

```sh
docker build -f backend/Metra.Api/Dockerfile -t metra-api:local .
```

Run with secrets supplied by the deployment platform's secret manager (never put the service-role key in an image, Dockerfile, compose file committed to Git, or client application):

```sh
docker run --rm -p 8080:8080 \
  -e ASPNETCORE_HTTP_PORTS=8080 \
  -e Supabase__Url=https://tbdnklyxjvbrilvnwgmq.supabase.co \
  -e Supabase__ServiceRoleKey="$METRA_SUPABASE_SERVICE_ROLE_KEY" \
  -e Cors__AllowedOrigins__0=https://gfa437926-tech.github.io \
  metra-api:local
```

The container listens on port 8080 and runs as the non-root `app` user supplied by the official .NET runtime image. The platform must terminate TLS and forward traffic securely to the container. Configure an HTTPS public API origin before setting `METRA_API_BASE_URL` in Angular/Flutter clients.

## Hosting configuration

Set these values in the API hosting environment (not in source control):

| Environment variable | Purpose |
|---|---|
| `Supabase__Url` | Supabase project URL |
| `Supabase__ServiceRoleKey` | Server-only service-role secret; required for database RPC and directory access |
| `Authentication__Authority` | Optional override; defaults to `{Supabase__Url}/auth/v1` |
| `Authentication__Audience` | Optional override; defaults to `authenticated` |
| `Cors__AllowedOrigins__0` | First permitted browser origin |
| `Cors__AllowedOrigins__1` | Additional permitted browser origin, if needed |
| `ASPNETCORE_HTTP_PORTS` | Container HTTP port; defaults to 8080 in the supplied image |

Do not put the Supabase service-role/secret key or JWT signing secret in Angular, Flutter, Git, or ordinary application settings.

## Health and readiness

- `GET /api/v1/health` is an anonymous liveness endpoint. It confirms that the process is responding.
- `GET /api/v1/ready` is an anonymous readiness endpoint. It returns 200 only when the server-side Supabase URL and service-role integration are configured for authorization, observation submission and decisions, review queue, station directory, station catalogue review, registration review and submission, station user directory, station assignment management, and station audit; otherwise it returns 503.
- Readiness performs a bounded server-side PostgREST round trip against the station catalogue. It verifies basic connectivity and credentials, but does not prove that every workflow migration or every RPC is operational.

## Signing-key prerequisite

This JWT Bearer configuration obtains public signing keys from the Supabase Auth OpenID/JWKS discovery endpoints. Confirm that the project uses an asymmetric signing key (for example ES256 or RS256) and that its JWKS endpoint publishes the active public key before enabling authenticated production traffic.

Supabase does not publish symmetric HS256 secrets through JWKS. If the project still uses legacy HS256 signing, this verifier will fail closed; do not work around that by committing or exposing the JWT secret. Migrate the project to asymmetric signing keys or implement a separately reviewed server-side verification strategy first.

## Authorization boundary

A valid JWT proves identity only. It does not establish METRA job role, account approval, authority membership, station assignment, or station scope. Those checks must be implemented server-side against METRA's trusted records before exposing operational data or mutations. Never authorize using user-editable `user_metadata`, client-supplied role codes, or client-supplied station ownership.

## Station-scoped authorization

Operational endpoints must apply `RequireStationPermission("permission.code")`
and include a `{stationId:guid}` route parameter. The filter reads the authenticated
Supabase JWT `sub` claim and never accepts a user ID, role, or station scope from
the request body as proof of authority.

The API calls the narrowly scoped
`public.metra_user_has_station_permission(uuid, uuid, text)` RPC using the
server-only Supabase service-role key. The RPC requires an active METRA account,
an approved and current authority membership, an approved and current assignment
to the exact station, an active catalogue role, an approved explicit permission
grant, an active authority and country, and an approved active non-demo station.
It returns false for any missing, expired, revoked, pending, or mismatched record.
The function is SECURITY DEFINER with a fixed search_path; execution is revoked
from PUBLIC, anon, and authenticated and granted only to service_role.

A missing API secret or failed RPC is fail-closed. Do not expose operational
routes until the host secret is configured and integration tests cover pending
accounts, expired memberships/assignments/grants, cross-station access,
self-elevation, and demo/unapproved stations. Generic observation validation
routes are not station-scoped operational write routes.

## Station audit log

`GET /api/v1/stations/{stationId}/audit-log?limit=100` returns a bounded,
station-scoped projection of station catalogue and assignment audit events.
It requires `users.station.view`; the API derives the caller from the verified
JWT and checks the exact station permission before calling the server-only
`get_station_audit_log` RPC. The RPC returns only selected audit fields and
never exposes the raw audit table or arbitrary JSON snapshots to browser
clients. Its execution is revoked from PUBLIC, anon, and authenticated and
granted only to service_role.

## Station catalogue review

`POST /api/v1/stations/{stationId}/review` requires the exact
`stations.catalogue.review` station permission. The authenticated JWT `sub`
is the only actor identity source; clients cannot choose the reviewer ID.
Requests must carry `expectedStatus: pending`, one of `approved`, `rejected`,
or `changes_requested`, and a trimmed reason of 5–2000 characters. The API
calls `public.decide_station_catalogue_review` using the server-only key.
The database function rechecks active account state, the approved and
unrevoked time-valid individual permission grant, locks the station row,
checks expected state to prevent stale decisions, and writes before/after
state to `station_audit_log` atomically. The public RPC is executable only
by `service_role`; direct anon/authenticated execution is denied.

The `network_director` role is included in the explicit role allow-list for
this permission. That role allow-list is not sufficient on its own: the
reviewer must also have an approved, current station assignment and the
individual permission grant. No self-grant or self-approval endpoint is
provided by this route.

## Station directory

`GET /api/v1/stations?limit=250&offset=0&stationType=classic` returns the authenticated
read-only station directory. It exposes only the catalogue's non-demo station
projection: station identifiers/codes, bilingual names, station type, operational
and approval states, elevation, and current coordinate records. It does not expose
account, membership, assignment, grant, or audit fields.

The `stationType` filter accepts `classic`, `automatic`, or `synoptic`.
Pagination is bounded to 500 rows. Both classic and automatic records are included
when no type filter is supplied. Pending or unverified records remain visibly
labelled in the response; consumers must not treat them as approved/operational.
The server-side service-role key is used only by the API host. The mobile client
must send a valid Supabase access token and must never call the database directly.

## Automated container publishing

Every change to `backend/Metra.Api/**` on `main` also triggers
`.github/workflows/publish-api-container.yml`. After the backend build and
tests pass independently, that workflow publishes the production Docker image
to GitHub Container Registry:

- `ghcr.io/gfa437926-tech/metra2027-api:latest` for the current main branch.
- `ghcr.io/gfa437926-tech/metra2027-api:sha-<commit>` for an immutable commit build.

The workflow uses the repository-scoped `GITHUB_TOKEN`; no service-role key
or Supabase credential is used during image publication. The image is a
deployable artifact, not a live API deployment. A hosting platform, runtime
secrets, HTTPS origin, and production CORS allow-list are still required.

## Two-stage user registration review

The station-scoped user review API exposes:
- `GET /api/v1/stations/{stationId}/registration-requests`
- `POST /api/v1/stations/{stationId}/registration-requests/{requestId}/decision`
- `GET /api/v1/stations/{stationId}/system-registration-requests`
- `POST /api/v1/stations/{stationId}/system-registration-requests/{requestId}/decision`
- `GET /api/v1/stations/{stationId}/registration-audit`
- `GET /api/v1/stations/{stationId}/system-registration-audit`

The station stage requires `registrations.station.approve`; the second stage
requires `registrations.system.approve`. Both are station-scoped and require
an approved assignment and a separate time-valid individual permission grant.
The final reviewer must differ from the station approver. The API derives the
reviewer from the verified JWT `sub` claim and never accepts an actor ID from
the request body.

The station-bound RPC locks the registration request and verifies that its
stored station equals the route station before invoking the transactional
decision function. The database function rechecks stage and account state,
prevents self-review, creates the approved station assignment only after the
second-stage approval, updates the account state, and appends the audit event
atomically. The RPC is callable only by the API's server-side `service_role`.
The API queue intentionally omits authentication email and other auth-provider
secrets; it returns only the profile and request fields required for review.

This workflow does not provide a general role-grant or privilege-escalation
endpoint. Non-requestable administrative roles and individual permission
grants must remain separate, explicitly reviewed operations.

## User registration submission and account status

- `GET /api/v1/registration-roles` returns only active requestable roles.
- `POST /api/v1/registration-requests` submits a registration for the user in
  the verified JWT `sub`; the client cannot submit for another user.
- `GET /api/v1/account/registration-status` returns only the caller's own
  account and latest registration state.
- `GET /api/v1/stations/{stationId}/users` returns the station-scoped
  read-only user/assignment directory and requires `users.station.view`.

The submission RPC accepts only an approved, active, non-demo station and a
currently requestable role. It uses an idempotency key and records the
registration-submitted audit event atomically with profile, account-state and
request creation. The public wrapper and status read model are executable only
by `service_role`; the API supplies the caller identity from the verified JWT.
The browser never receives the service-role key. The station directory omits
email and authentication-provider fields and exposes no grant/revoke controls.

## Station assignment management

- `GET /api/v1/stations/{stationId}/assignable-roles`
- `POST /api/v1/stations/{stationId}/assignments`
- `POST /api/v1/stations/{stationId}/assignments/{assignmentId}/decision`
- `POST /api/v1/stations/{stationId}/assignments/{assignmentId}/revoke`

All routes require `users.station.manage` for the exact station and a separate
approved individual grant. The station-manager workflow can assign only
`observer` and `station_auditor`; administrative and director roles cannot
be assigned through it. A target must already have an active METRA account
and approved, current membership in the station's authority. A different
reviewer must approve or reject the pending assignment. Revocation requires
a different authorized manager and a reason. Request, approval, rejection and
revocation are appended to `station_audit_log` atomically with the state
change. No station assignment operation creates or changes permission grants.

Authority membership and individual permission-grant management remain
separate controlled operations and are not exposed by these endpoints.
