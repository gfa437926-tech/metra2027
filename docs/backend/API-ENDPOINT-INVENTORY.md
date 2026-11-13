# API Endpoint Inventory (implemented)

Generated for Stage C3 from `Features/**` route maps. All mutating/user routes require authentication unless noted.

## Observations
| Method | Route | Authz |
|--------|-------|-------|
| POST | `/api/v1/stations/{stationId}/observations` | station permission |
| POST | `/api/v1/stations/{stationId}/observations/{id}/decision` | review/approve |
| GET | `/api/v1/stations/{stationId}/observation-queue` | station permission |
| GET | `/api/v1/stations/{stationId}/observation-archive` | archive.read + **503 service** |

## Stations
| Method | Route |
|--------|-------|
| GET | `/api/v1/stations` (directory) |
| POST | catalogue review decision routes under stations |

## Users / authority / registration / assignments
| Area | Prefix |
|------|--------|
| Authority access | `/api/v1/authorities/{authorityId}/...` |
| Registration | `/api/v1/registration-requests`, station registration review |
| Assignments | `/api/v1/stations/{stationId}/assignments` |
| Station users / audit | `/api/v1/stations/{stationId}/users`, `.../audit-log` |

Error conventions: 401 unauthenticated, 403 forbidden, 404 not found, 409 conflict (including grant unique via C2.6), 400 validation, 503 dependency unavailable.
