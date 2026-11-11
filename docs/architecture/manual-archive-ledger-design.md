# Manual Excel archive ledger — design (Phase C)

## Purpose
Auditors record that an exported Excel file was archived **manually**, so the action is not forgotten.

## Non-goals
- No connection to an archive database
- No automatic transfer of observation rows
- No client-held service-role keys

## API
- `POST /api/v1/stations/{stationId}/archive-confirmations`
- `GET /api/v1/stations/{stationId}/archive-confirmations`
- `GET /api/v1/stations/{stationId}/archive-confirmations/monthly-summary?year=&month=`

## Authorization
Station-scoped `archive.confirm` / `archive.read`. Missing grants deny access.

## Persistence status
Interim in-memory service for development/CI. Durable table SQL is documented as **review-only** and must not be applied to hosted Supabase without explicit owner approval.
