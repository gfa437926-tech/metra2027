# Flutter ↔ .NET API Contract (C7)

Base URL: `METRA_API_BASE_URL` (HTTPS origin only). Auth: Bearer access token from Supabase session (`sub`).

| Method | Path | Client | Authz | Notes |
|--------|------|--------|-------|-------|
| GET | `/api/v1/stations` | `getStationDirectory` | JWT | query limit/offset/stationType |
| GET | `/api/v1/stations/{id}/audit-log` | `getStationAuditLog` | station scope | |
| GET | `/api/v1/stations/{id}/observations` | `getReviewQueue` | station | |
| POST | `/api/v1/stations/{id}/observations` | `submitObservation` | create | |
| POST | `/api/v1/stations/{id}/observations/{oid}/decision` | `decideObservation` | review | |
| GET | `/api/v1/stations/{id}/observation-archive` | `getObservationArchive` | archive.read | **503** until service |

Errors: `MetraApiException(status, code)` — prefers JSON `code`/`error` from API. 401 missing token; 403 denied; 503 not configured / archive unavailable.

**Path fix C7:** archive client path aligned to `observation-archive` (was incorrectly `observations/archive`).
