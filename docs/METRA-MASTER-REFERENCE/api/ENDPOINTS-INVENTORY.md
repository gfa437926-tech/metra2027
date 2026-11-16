# .NET API Endpoints Inventory (proven from backend source)

Source: `backend/Metra.Api/Features/**` on main.

| Method | Route | File | Purpose | Station scope |
|---|---|---|---|---|
| POST | /api/v1/stations/{stationId}/observations | ObservationSubmissionEndpoints.cs | Submit | Yes + FeatureGate |
| POST | /api/v1/stations/{stationId}/observations/{observationId}/decision | ObservationSubmissionEndpoints.cs | Decide | Yes + FeatureGate |
| GET | /api/v1/stations/{stationId}/observations | ObservationQueueEndpoints.cs | Queue | Yes |
| POST | /api/v1/observations/daily/validate | ObservationValidationEndpoints.cs | Validate daily | body |
| POST | /api/v1/observations/hourly/validate | ObservationValidationEndpoints.cs | Validate hourly | body |
| POST | /api/v1/observations/phenomena/validate | ObservationValidationEndpoints.cs | Validate phenomena | body |
| GET | /api/v1/stations | StationDirectoryEndpoints.cs | Directory | auth |
| POST | /api/v1/stations/{stationId}/review | StationCatalogueReviewEndpoints.cs | Catalogue review | Yes |
| GET | /api/v1/stations/{stationId}/audit-log | StationAuditEndpoints.cs | Audit log | Yes |
| GET | /api/v1/stations/{stationId}/users | StationUserDirectoryEndpoints.cs | Station users | Yes |
| GET | /api/v1/stations/{stationId}/observation-archive | archive | Archive list | Yes — expect 503 |
| GET | /api/v1/stations/{stationId}/observation-archive/{id} | archive | Archive detail | Yes — 503 |
| POST | /api/v1/authorities/{authorityId}/memberships | AuthorityAccessEndpoints.cs | Membership | authority |
| POST | .../memberships/{id}/decision | AuthorityAccessEndpoints.cs | Membership decision | authority |
| POST | .../memberships/{id}/revocation | AuthorityAccessEndpoints.cs | Revoke | authority |
| POST | .../permission-grants | AuthorityAccessEndpoints.cs | Grant | authority |
| POST | .../permission-grants/{id}/decision | AuthorityAccessEndpoints.cs | Grant decision | authority |
| GET | /api/v1/authorities | users | List authorities | auth |
| GET | /api/v1/authorities/{id}/access-queue | Authority | Access queue | authority |
| GET | /api/v1/authorities/{id}/access-audit | Authority | Access audit | authority |
| GET | /api/v1/authorities/{id}/membership-roles | Authority | Roles | authority |
| GET | /api/v1/authorities/{id}/permission-options | Authority | Permission options | authority |
| GET | /api/v1/registration-roles | Registration | Registration roles | auth |
| GET | /api/v1/account/registration-status | Registration | My status | self |
| GET | /api/v2/stations | greenfield | Alt directory | auth |

Authorization: station-scoped services/RPC; UI hide is not auth. Tests under Metra.Api.Tests for guards.

Not found: CLIMATOL run API, AI train/infer API, full equipment CRUD, OCR API.
