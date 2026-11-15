# Greenfield station directory .NET reader

**Status:** implemented in the API source; hosted access remains fail-closed pending the approved Data API/runtime access review.  
**Route:** `GET /api/v2/stations`  
**Physical source:** `catalog.stations`, `catalog.station_types`, `catalog.station_locations`.

## Implementation

- `SupabaseGreenfieldStationDirectoryReader` reads only the normalized `catalog` schema through PostgREST.
- The API forwards the already validated caller's Supabase bearer JWT and uses only `Supabase:PublishableKey` as the `apikey` header. It never uses `service_role` for this directory path.
- The request selects the station's canonical code/names/WMO identifier/status, joins an active station type, and embeds only locations where `valid_to IS NULL`.
- The response is flattened into the strict `stations.directory.v1` DTO and passed through `GreenfieldStationDirectoryMapper`.
- Approved stations with operational state `active` or `temporarily_closed` are the only records requested. Station type codes are filtered safely, pages are bounded to 500, and results are ordered by unique `station_code`.
- Zero current locations are represented as absent coordinates. More than one current location fails the whole page; join multiplication is never silently accepted.
- The legacy `/api/v1/stations` adapter remains separately disabled by default. No fallback to `public.station_catalogue` is performed.

## Required configuration

- `Supabase:Url`
- `Supabase:PublishableKey` (publishable/legacy anon key only; never a service-role or secret key)

The caller JWT is taken from the incoming request only after ASP.NET authentication has validated it. The endpoint returns 401 without an authenticated principal/bearer token and 503 if the reader is not configured or the PostgREST result cannot be validated.

## Current integration blocker — deliberately not bypassed

Read-only inspection of project `tbdnklyxjvbrilvnwgmq` confirms the catalog tables exist and have RLS enabled. The station table is empty at inspection time. The broader access audit also found no direct table CRUD grants for `anon`/`authenticated` on inspected application tables, and the `catalog` schema's Data API exposure must be confirmed. Consequently the new PostgREST request may correctly receive 401/403/404 until the access contract is reviewed and approved.

Do not solve this by switching to `service_role`, adding blanket policies, granting broad CRUD, or enabling an unreviewed schema. The next safe gate is to approve the catalog read scope (global published catalogue vs organization-scoped stations), exposed-schema decision, and exact RLS/grant design; then test anonymous, cross-organization, pending/rejected, inactive station type, and duplicate-current-location cases against a disposable PostgreSQL/Supabase environment. Only after those tests and explicit approval may hosted grants/policies or configuration be changed.

No hosted SQL, grants, RLS policies, seeds, keys, storage, legacy database, or deployment settings were changed.
