# Hourly observation workflow contract

## Scope

This document and the accompanying DTOs define the application boundary for
central hourly-observation submission and station review. They do not claim
that persistence or the endpoints are deployed.

## Planned authenticated operations

| Operation | Purpose | Required authorization |
|---|---|---|
| `POST /api/v1/observations/hourly` | Submit a validated hourly report | Active account and an effective station assignment |
| `GET /api/v1/observations/hourly` | List reports visible to the caller | Station scope derived from server-side assignments; privileged roles may have wider scope |
| `GET /api/v1/observations/hourly/{id}` | Read one report | Resource-level station/role authorization |
| `POST /api/v1/observations/hourly/{id}/review` | Approve or reject a pending report | Station reviewer for the report's station, or an explicitly authorized higher role |

## Submission rules

- Request fields are `observationDate`, `utcHour`, and `values`.
- The client must not submit a trusted `stationId`, `userId`, reviewer ID,
  status, or submission timestamp.
- The API resolves issuer + subject from the validated authentication principal,
  loads the authoritative METRA account and effective station assignment, and
  derives the station and submitter server-side.
- The API validates `values` using `HourlyObservationValidator` and checks
  that `values.utcTime` matches `utcHour`.
- New reports enter `PendingReview`; successful validation alone is not a save.

## Review rules

- Only a pending report can be reviewed. The submitter cannot review their own report.
- Rejection requires a non-empty reason. Notes are limited to 1,000 characters.
- Reviewer identity and review time are server-generated.
- Every decision must be recorded with an immutable audit event. Repeated or
  conflicting decisions must not silently overwrite the first decision.
- A reviewer must have an effective assignment/permission for the report's
  station; possession of an observation ID is not authorization.

## Persistence and schema gate

No migration, SQL statement, Supabase table, or live database change is included
in this contract. Before implementing persistence, review the approved target
schema and identity mapping with the project owner. The implementation must
not inspect, alter, or migrate legacy station datasets. A repository/store
implementation must use one transaction for submission metadata and audit data,
enforce unique/idempotency behavior, and apply least-privilege database access.

## Current implementation boundary

- Existing `/hourly/validate` remains anonymous and validation-only.
- The new request/response contracts, metadata validators, application service,
  and authenticated HTTP endpoint adapter mappings (submit/review) are implemented. The service enforces active-account checks, permission checks,
  exactly one effective station assignment for submission, server-derived station
  identity, domain validation, pending-review state, station-scoped review, and
  submitter/reviewer separation.
- `IHourlyObservationActorContextProvider` and `IHourlyObservationStore` are
  persistence/identity boundaries only; production adapters and DI registrations
  are not implemented. The new endpoint mapping extension is deliberately not
  registered in `Program.cs` until those trusted dependencies exist, so no live
  save or review endpoint is exposed yet.
- Flutter and Angular must display “validated” rather than “saved” until the
  authenticated persistence endpoint is implemented and returns a persisted ID.


## Automated test coverage added (not yet executed)

The application-service test suite covers inactive accounts, missing or multiple
station assignments, expired assignments, missing submit permission, server-derived
station identity, pending-review status, invalid review decisions, cross-station
review denial, submitter self-review denial, and concurrent review conflicts.
These tests are committed but must still be run in CI or a .NET 10 environment.
