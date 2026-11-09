# Station-scoped API route permission inventory

Static scan: each `RequireStationPermission` paired with nearest preceding `Map*` path.

| Route | Permission | File |
|---|---|---|
| `/api/v1/stations/{stationId:guid}/equipment-faults` | `equipment_fault.create` | `EquipmentFaultEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/equipment-faults` | `equipment_fault.read` | `EquipmentFaultEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/equipment-faults/{faultId:guid}` | `equipment_fault.read` | `EquipmentFaultEndpoints.cs` |
| `(unknown route)` | `equipment_fault.read` | `EquipmentFaultEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/observations/{observationId:guid}/resubmit` | `observation.submit` | `ObservationResubmitEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/observations/returned` | `observation.submit` | `ObservationReturnedQueueEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/observations` | `observation.create` | `ObservationSubmissionEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/support-incidents` | `support_incident.create` | `SupportIncidentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/support-incidents` | `support_incident.read` | `SupportIncidentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/support-incidents/{incidentId:guid}` | `support_incident.read` | `SupportIncidentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/support-incidents/{incidentId:guid}/transitions` | `support_incident.read` | `SupportIncidentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/registration-requests` | `registrations.station.approve` | `RegistrationReviewEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/registration-requests/{requestId:guid}/decision` | `registrations.station.approve` | `RegistrationReviewEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/registration-audit` | `registrations.station.approve` | `RegistrationReviewEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/assignable-roles` | `users.station.manage` | `StationAssignmentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/assignments` | `users.station.manage` | `StationAssignmentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/assignments/{assignmentId:guid}/decision` | `users.station.manage` | `StationAssignmentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/assignments/{assignmentId:guid}/revoke` | `users.station.manage` | `StationAssignmentEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/audit-log` | `users.station.view` | `StationAuditEndpoints.cs` |
| `/api/v1/stations/{stationId:guid}/users` | `users.station.view` | `StationUserDirectoryEndpoints.cs` |

## Notes

- Observation **decision** uses inline `HasStationPermissionAsync` for `observation.approve` / `observation.return_for_correction` (fail closed when auth not configured) rather than `.RequireStationPermission(...)`.
- Observation **queue** accepts any of `observation.review`, `observation.approve`, `observation.return_for_correction`.
- Validation endpoints under observation field contracts may be unauthenticated by design for pure validation; confirm before production exposure.
