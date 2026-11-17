# Observation Read / Correction / Version API — Contract Draft

- Repository: gfa437926-tech/metra2027
- Owner: Assistant 02 — Backend / API
- Drafted at (UTC): 2026-11-10T23:31:49Z
- Status: proposal only; requires owner review and schema/role approval
- Source: `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md` on branch `docs/metra-complete-page-test-matrix`
- No current endpoint is claimed to exist unless listed in the current source audit.

## 1. Requirements grounded in the master specification

The master specification requires:

- Hourly and daily report lists with station and UTC period/status filters, pagination and no cross-station disclosure.
- Report details with full observation, validation results, status and history.
- Review queues and decisions within verified station/auditor scope.
- Correction of returned reports without erasing prior versions; revalidation and re-review.
- Concurrent/stale review decisions handled safely.
- Audit history with the correct actor and UTC timestamp.
- Exact daily period boundaries, required fields, workflow transition matrix and auditor scope remain unresolved/owner approval items.

The daily report is a 24-hour summary. 06:00 UTC and 18:00 UTC are hourly bulletin times, not daily reports. All report timestamps and filters are UTC-only.

## 2. Proposed route family (not implemented)

| Method | Proposed route | Purpose | Current source status |
|---|---|---|---|
| GET | `/api/v1/stations/{stationId}/observations` | Existing submitted review queue only | Exists; not a general report list |
| GET | `/api/v1/stations/{stationId}/observations/search` | Proposed general list for hourly/daily records | Not found in audited source |
| GET | `/api/v1/stations/{stationId}/observations/{observationId}` | Proposed record detail | Not found in audited source |
| GET | `/api/v1/stations/{stationId}/observations/{observationId}/versions` | Proposed immutable version history | Not found in audited source |
| POST | `/api/v1/stations/{stationId}/observations/{observationId}/corrections` | Proposed correction of a returned record | Not found in audited source |
| POST | `/api/v1/stations/{stationId}/observations/{observationId}/decision` | Existing review decision route | Exists; atomic authorization/version behavior requires review |

Route names are a draft convention, not a requirement. They must be reconciled with Angular/Flutter API usage and the repository's existing route style before implementation.

## 3. Proposed list query contract

Potential query parameters:

- `type`: hourly or daily; required for the general list unless a documented default is approved.
- `status`: one or more approved workflow states; exact state enum requires owner approval.
- `fromUtc`, `toUtc`: inclusive/exclusive UTC interval contract to be fixed consistently; values must be ISO-8601 UTC with zero offset.
- `pageSize`: bounded integer; proposed 1–100, default 50.
- `cursor`: opaque server-generated continuation token; do not accept arbitrary sort/filter fragments from clients.

Requirements:
- The server derives actor ID from the validated JWT `sub`.
- Station scope is authorized on the server for every request; caller-supplied station ID is a selector, not proof of access.
- Apply station authorization before any data is returned and keep scope predicates in the database read.
- Stable ordering must include a unique tie-breaker (for example timestamp plus record ID); exact sort fields need owner approval.
- Return only the requested page and a continuation token; never silently widen scope on invalid cursor/filter.
- UTC filter validation must reject non-zero offsets rather than silently converting local time.

## 4. Proposed response shapes (illustrative, not final DTOs)

List response:
```json
{
  "items": [
    {
      "id": "uuid",
      "stationId": "uuid",
      "type": "hourly",
      "observedAt": "2026-11-10T18:00:00Z",
      "status": "submitted",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

Detail response:
```json
{
  "id": "uuid",
  "stationId": "uuid",
  "type": "hourly",
  "observedAt": "2026-11-10T18:00:00Z",
  "status": "returned_for_correction",
  "version": 2,
  "payload": {},
  "validation": [],
  "history": []
}
```

These examples show the shape only. They do not define the final field catalogue, status enum, validation schema, or database columns. Avoid shipping these examples as generated OpenAPI contracts until the owner approves the domain rules.

## 5. Correction and immutable version contract

Proposed correction request:
- Caller sends the new observation payload and an expected current version token.
- Use `If-Match` with an opaque version/ETag or an explicit expected-version field; choose one convention and document it.
- Correction is allowed only from owner-approved states and by an explicitly authorized actor.
- The write must be atomic: verify station scope, record state, actor permission and expected version; append a new version; record actor and UTC timestamp; rerun server-side validation; move the workflow to the approved re-review state.
- Never overwrite or delete the prior version.
- A stale version must return 409 Conflict and must not create a partial version.
- A correction must not itself imply approval.

## 6. Version history contract

Each history item should expose only approved audit metadata:
- version identifier/number;
- event type (submitted, returned, corrected, approved, rejected, or other owner-approved transition);
- actor identifier/display fields subject to privacy policy;
- UTC event timestamp;
- reason/note where policy permits;
- version relationship and validation outcome.

History must be append-only from the API perspective. The final retention model, actor display data, and note visibility require owner/security review.

## 7. Authorization and privacy requirements

- List, detail, history and correction operations must all enforce exact station/record scope on the server.
- A station ID in the URL or a record ID alone never authorizes access.
- Auditor/national/global access must not be inferred from a role name; use only explicit approved grants.
- Do not trust actor IDs, role names, station assignments or version numbers from a client as authorization evidence.
- Correction and decision operations must re-check the action-specific permission in the same atomic database operation as the write.
- Avoid exposing another station's record existence; use a consistent 404/403 policy after owner/security review.
- Keep service-role credentials exclusively in the backend.

## 8. Error contract proposal

| HTTP | Meaning |
|---|---|
| 400 | Invalid query, UTC timestamp, cursor or request shape |
| 401 | Missing/invalid authentication |
| 403 | Authenticated actor lacks the required action/scope |
| 404 | Record not visible under the approved existence-disclosure policy |
| 409 | Stale version, duplicate transition or workflow conflict |
| 422 | Semantically invalid observation payload, if adopted consistently |
| 503 | Authorization/data dependency unavailable; fail closed |

The existing API has mixed error response conventions. A consistent error envelope should be approved before client integration; do not silently change existing error identifiers in this draft.

## 9. Decisions required before implementation

1. Approved observation type/status enums and transition matrix.
2. Exact hourly/daily field catalogues, units, validation rules and daily UTC period boundaries.
3. Approved station/auditor scope and role-to-permission mapping.
4. Database schema for observations, versions, decisions and audit events.
5. Cursor pagination and stable ordering policy.
6. ETag/If-Match versus explicit expected-version request convention.
7. Record existence disclosure policy (403 versus 404).
8. Correction actor policy, reason requirements and retention rules.
9. Atomic RPC/transaction design and concurrency behavior.

## 10. Current implementation status

- Existing queue GET and decision POST are present in the audited backend.
- General report list, record detail, correction and version-history endpoints were not found in the reviewed source.
- This file is a proposal only. No API code, DTO, database schema, SQL, migration, RPC, RLS, seed, Angular or Flutter change was made.
- B-008 remains in progress pending contract review and the decisions above.
