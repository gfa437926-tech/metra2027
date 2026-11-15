# Greenfield station directory .NET reader

**Status:** Atomic actor-scoped RPC adapter and .NET client implemented; hosted RPC and feature flag remain disabled pending schema review/approval.  
**Route:** `GET /api/v2/stations`  
**Physical source:** `catalog.stations`, `catalog.station_types`, `catalog.station_locations`; authorization from `iam.*`.

## Current implementation

- `GET /api/v2/stations` is protected by the ASP.NET JWT authentication fallback policy.
- The endpoint derives the actor UUID only from the already validated JWT `sub` claim. It does not accept a user ID, role, station ID or scope from query/body data.
- `SupabaseGreenfieldStationDirectoryReader` calls only the `public.get_station_directory_for_actor` PostgREST RPC wrapper by POST. The wrapper invokes the internal `catalog.get_station_directory_for_actor` SECURITY DEFINER function; the adapter does not query catalogue tables directly and does not require the `catalog` schema to be exposed by PostgREST.
- The server-side `Supabase:ServiceRoleKey` is used only as the credential for this one server-only RPC. The key is never returned to a client, stored in Flutter, or used for direct table reads by this adapter.
- The RPC is proposal-only and grants EXECUTE to `service_role` while revoking PUBLIC, `anon`, and `authenticated`. It is a `SECURITY DEFINER` function with a fixed `search_path`.
- The RPC checks the active profile, approved active membership, active organization, active role, active and time-valid role assignment, explicit role permission and station state in the same database statement. Authorization facts and the station/type rows are locked for the duration of the read.
- A station-scoped assignment must match the exact station and owner organization and carry `stations.read`. A global assignment is accepted only for `auditor` or `network_department_head` and only with `stations.read_all`.
- Only approved stations with operational status `active` or `temporarily_closed` and an active station type are returned. The station user receives only assigned station(s); global readers receive all eligible stations.
- The SQL returns the strict flat `stations.directory.v1` projection, which is validated by `GreenfieldStationDirectoryMapper`. Page size is bounded to 500, offset is nonnegative, and station type code is validated on both API and database sides.
- The legacy `/api/v1/stations` adapter remains separately disabled by default. There is no fallback to `public.station_catalogue`.

## Required configuration

- `Supabase:Url`
- `Supabase:ServiceRoleKey` (server secret only; do not expose in clients or logs)
- `Features:GreenfieldStationDirectoryEnabled=true` (explicit opt-in; defaults to disabled)

The endpoint returns 401 if the validated subject is not a UUID. It returns 503 when the adapter is not explicitly enabled/configured or the atomic RPC fails/returns an invalid projection. Unit tests verify the service calls only the RPC, sends the validated actor ID and bounded query values, rejects a publishable key in the server-key setting, and performs zero HTTP calls while disabled.

## SQL proposals and isolated verification

- `database/proposals/036_global_station_read_roles_and_permissions.sql` adds explicit global read permissions and the non-assignable system role `network_department_head`; it does not create user assignments.
- `database/proposals/037_atomic_greenfield_station_directory_read.sql` defines the actor-bound directory RPC.
- `database/isolated/11_bootstrap_greenfield_iam_catalogue.sql` creates a minimal disposable fixture matching the inspected IAM/catalogue contract. It is not represented as a canonical replay of the full live schema.
- `database/isolated/11_test_station_global_read_roles.sql` checks global role definitions and read-only permission sets.
- `database/isolated/12_test_atomic_greenfield_station_directory.sql` checks own-station isolation, auditor/network-head global reads, approval/operational filtering, suspended profile and expired assignment denial, and RPC execute ACL.
- Backend CI Path N applies these proposals only to a disposable PostgreSQL job. It does not apply them to hosted Supabase.

## Hosted integration boundary

Read-only inspection of project `tbdnklyxjvbrilvnwgmq` found that the actual IAM assignment scope values are `global`, `organization`, `unit`, and `station`; `auditor` exists, but `network_department_head` and explicit `*.read_all` permissions do not. Profiles, memberships, role assignments and station catalogue rows are currently empty. Existing catalogue RLS is not a direct caller-JWT read path for this adapter.

The new reader is therefore deliberately feature-gated off. Do not enable it until the SQL proposal has passed isolated CI, the owner has reviewed the exact SQL/privileges, the hosted schema change has been explicitly approved, and a non-production integration test confirms the function owner and ACLs. No blanket table grants or authenticated direct catalogue access are required.

No hosted SQL, grants, RLS policies, seed data, role assignments, keys, storage, legacy database, or deployment settings were changed.
