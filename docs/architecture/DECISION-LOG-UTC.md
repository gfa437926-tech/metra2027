# Architecture decision record — UTC-only time semantics

- Decision ID: ADR-TIME-001
- Status: Accepted product constraint for the current METRA 2027 scope
- Recorded: 2026-11-11
- Scope: all clients, APIs, persisted observations, audit events, reports, integrations and exports.

## Decision

METRA uses UTC only. Do not introduce local-time fields, local-time conversions, or local-time labels as an alternate operational time basis. A timestamp exchanged or persisted by the system represents a UTC instant.

## Implementation requirements

1. API contracts use ISO 8601 UTC timestamps with an explicit `Z` suffix (or an explicitly zero offset normalized to `Z` at boundaries).
2. .NET uses `DateTimeOffset`; reject ambiguous/local `DateTime` values at input boundaries.
3. PostgreSQL uses `timestamptz`; database sessions, scheduled jobs and generated report boundaries must be UTC.
4. Angular and Flutter must serialize and parse instants without silently substituting device timezone.
5. Report filters, date boundaries, daily aggregation, hourly slots, exports and audit ordering must use UTC definitions consistently.
6. Tests must cover UTC midnight, month/year boundaries, leap day, offset input normalization, daylight-saving transitions in client device zones, and round-trip persistence.
7. If a source provides a non-UTC timestamp, preserve its source offset/metadata only when required for provenance, and normalize the operational instant to UTC. Do not reinterpret it as local station time.
8. A date-only scientific observation day must have a separately defined UTC convention; do not infer midnight semantics without domain approval.

## Rationale

A single global time basis prevents station-dependent and device-dependent interpretation, makes audit ordering deterministic, and aligns with the operational requirement that all reporting and time references remain UTC.

## Verification state

This is a documented decision, not a claim of complete conformance. The current observation API contract shows an ISO-8601 UTC example and the SQL uses `timestamptz`, but a repository-wide UTC audit and automated conformance suite remain required.

## Change control

Any proposal to introduce local time must be raised as a new decision, include migration and historical-data impact, and receive explicit product-owner approval. Until then, UTC-only remains normative.
