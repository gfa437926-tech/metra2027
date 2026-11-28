# Operational observation submission API

## Endpoint

`POST /api/v1/stations/{stationId}/observations`

Requires a valid Supabase access token and the station-scoped `observation.create` permission. The API resolves the actor only from the validated JWT `sub` claim; a client-supplied actor ID is not accepted.

Example request:

```json
{
  "idempotencyKey": "client-generated-unique-key",
  "observationType": "daily",
  "observedAt": "2026-11-03T12:00:00Z",
  "payload": {
    "tmax": 31.2,
    "tmin": 19.4
  },
  "submit": false
}
```

- `observationType`: `daily`, `hourly`, or `phenomenon`.
- `payload`: JSON object, limited to 64 KiB.
- `submit=false`: creates a draft; `submit=true`: requires both `observation.create` and `observation.submit`.
- The idempotency key is unique per actor and station. Repeating the same request returns the existing record; reusing the key with different content is a conflict.
- The database RPC repeats the station permission check in the same transaction as the insert and audit event.
- The API requires `Supabase:Url` and `Supabase:ServiceRoleKey` on the server. Never configure the service-role key in Angular, Flutter, or a public repository.

## Storage and audit

- `public.metra_observations` is the operational record store.
- `public.metra_observation_audit_events` is append-only.
- Both tables have forced RLS and explicit deny policies for `anon` and `authenticated`.
- The legacy import envelope `public.metra_observation_records` is unchanged and remains separate.
- The current API implements draft creation and submission only. Review, return, approval, editing, list/detail endpoints, and frontend integration remain follow-up work.

## Responses

- `200`: persisted record metadata (`id`, `status`, `replayed`).
- `400`: malformed request.
- `401`: missing/invalid authenticated subject.
- `403`: station permission denied.
- `409`: idempotency key reused with different request content.
- `503`: trusted database connection unavailable.
