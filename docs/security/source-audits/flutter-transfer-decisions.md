# Flutter transfer decisions — source repository review

Date: 2026-11-10
Target app: `metra2027/mobile/metra_mobile`
Source app: `metra-weather-intelligence2026`

## Decision matrix

| Source file / feature | Finding | Decision |
|---|---|---|
| `lib/domain/station_cluster.dart` | Pure grouping logic; compatible with the target's validated station coordinate model after adapting the type | Adapted into `mobile/metra_mobile/lib/features/stations/station_clusters.dart`; integrated into the map and covered by target Flutter tests |
| `lib/domain/station_record.dart` | Duplicates much of target `StationDirectoryItem`; source model reads flat latitude/longitude while target API currently reads nested `station_coordinates` | Do not copy as a second station model; preserve the target API DTO and extend it only through a reviewed API contract |
| `lib/data/station_directory_service.dart` | Calls the Supabase Edge Function `station-directory` directly and couples station reads to a source-specific response shape | Do not copy; target already has authenticated .NET station-directory endpoints and a `MetraApiClient` |
| `lib/domain/access_context.dart` | Parses an `access.memberships/permissions` payload returned by the source Edge Function | Defer until a corresponding .NET endpoint contract exists; do not fabricate an API response or trust client-side permissions as authorization |
| `lib/screens/observations_page.dart` | Uses the `observations` Supabase Edge Function for listing and writes | Do not copy directly; target already has .NET observation submission, queue and decision endpoints. Rebuild the screen against `MetraApiClient` if/when the UI is ported |
| `lib/screens/registration_flow.dart` | Uses Supabase Auth plus direct Edge Function calls for registration status and submission | Do not copy directly; target has .NET routes for requestable roles, registration status and registration submission. Adapt the UI to those routes and retain server-derived actor identity |
| `lib/screens/station_review_page.dart` | Calls the `station-review` Edge Function directly | Do not copy directly; target has .NET station catalogue review endpoints and service contracts |
| `lib/data/weather_service.dart` | Hard-codes Damascus coordinates and timezone in the provider requests | Do not copy; it is not station-generic and would silently show Damascus weather for other stations |
| `lib/domain/weather_snapshot.dart` | Validated weather response model; potentially reusable | Defer until the product chooses a station-aware weather provider/API response contract |
| `lib/domain/weather_station.dart` | Separate station abstraction with fixed classic/automatic enum and mandatory coordinates | Do not copy; target directory supports classic, automatic and synoptic types, optional/unverified coordinates and the canonical station catalogue |

## Architecture rule

The target Flutter application must use the .NET API for METRA business operations and authorization decisions. A copied screen must not call Supabase Edge Functions for operations that already have .NET API routes. Supabase Auth may continue to provide sign-in/session tokens; the API must derive the actor from the verified bearer token and enforce authorization server-side.

## Implemented transfer

The station clustering feature has been adapted to the target's `StationDirectoryItem` model. The map now groups co-located stations into count markers; selecting a cluster presents its member stations. Stations without valid coordinates remain visible in the list and are omitted only from map clusters.

Tests cover rounded coordinate grouping, invalid/missing coordinates, record preservation and immutable results.

## No deletion

No source Flutter file or target application file was deleted. The source repository remains unchanged.
