# METRA 2027 — Recorder Capture Metadata Contract

**Status:** application-level validation and Flutter request model. This is not an HTTP endpoint or persistence implementation.

## Request fields

| Field | Meaning | Validation |
|---|---|---|
| stationId | Selected station identifier | Required non-empty UUID on .NET boundary |
| instrumentId | Selected deployed instrument | Required non-empty UUID on .NET boundary |
| recorderKind | Recorder family | thermograph, hygrograph, barograph or pluviograph |
| captureStart / captureEnd | Capture interval | End must be strictly later than start |
| paperTimeZoneId | Timezone used by the paper chart | Required, bounded length, no control characters |
| chartType | Chart/form type | Required, bounded length, no control characters |
| chartScale | Chart scale metadata | Optional JSON object; detailed schema remains a domain-model review item |

## Trust boundaries

- The authenticated actor and authority are derived server-side; neither is accepted from the client payload.
- Station/instrument existence, same-authority scope, active deployment overlap, and recorder.write permission are application-service authorization checks. This validator does not claim to perform them.
- A capture identifier is generated server-side.
- Upload intents, object keys, public URLs, image validation, quarantine, malware scanning and asset completion are separate workflows.
- chartScale remains opaque beyond requiring a JSON object; no unreviewed scientific scale convention is imposed here.

## Verification

.NET unit tests cover supported recorder kinds, required identifiers, positive interval, required timezone/chart metadata, chart-scale JSON shape, and null input. Flutter tests cover UTC serialization, omitted trust-sensitive fields, interval detection, and the four recorder kinds.

## Not implemented

No database schema, migration, endpoint, upload service, instrument lookup, storage provider, OCR or chart digitization engine is added in this slice.
