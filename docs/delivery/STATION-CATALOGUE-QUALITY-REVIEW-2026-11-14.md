# METRA 2027 — Station catalogue quality review

- Snapshot date: 2026-11-14
- Source project: `tbdnklyxjvbrilvnwgmq`
- Inspection mode: read-only Supabase SQL queries
- Database writes performed: **none**

## Summary

| Metric | Source value |
|---|---:|
| Station catalogue rows | 65 |
| Non-demo stations | 62 |
| Demo stations | 3 |
| Approval status = pending | 65 |
| Approval status = approved | 0 |
| Operational status = unverified | 65 |
| Operational status = active | 0 |
| Coordinate rows | 50 |
| Distinct stations with coordinates | 50 |
| Stations without coordinates | 15 |
| Orphan coordinate rows | 0 |
| Duplicate coordinate station IDs | 0 |

The 65 entries are the new station catalogue already present in the approved experimental project. They are not the legacy station list. However, **none is currently approved or verified**. The export and application must preserve these statuses; no station was approved or activated during this review.

## Stations missing coordinates

All 15 entries below have no matching row in `station_coordinates`. Their `wmo_station_id` is also null, and each is currently `approval_status=pending` and `operational_status=unverified`.

| Local code | Arabic station name | Type | Demo |
|---|---|---|---|
| 1 | مركز بحوث الغاب | classic | No |
| 11 | صحنايا | classic | No |
| 13 | البوكمال | classic | No |
| 15 | دير الزور | classic | No |
| 16 | حمام واصل | classic | No |
| 20 | الإدارة العامة | classic | No |
| 21 | درعا | classic | No |
| 23 | بوقا | classic | No |
| 24 | حلب الجامعية | classic | No |
| 25 | زاهد | classic | No |
| 29 | عين العرب الجنوبية | classic | No |
| 6 | محطة حماه | classic | No |
| DEMO-AUTO-001 | محطة تجريبية آلية 001 | automatic | Yes |
| DEMO-CLASSIC-001 | محطة تجريبية كلاسيكية 001 | classic | Yes |
| DEMO-SYNOPTIC-001 | محطة تجريبية سينوبتيكية 001 | synoptic | Yes |

No coordinates or WMO identifiers have been guessed or inserted.

## API behaviour reviewed

- `GET /api/v1/stations` is covered by the API's global authenticated-user fallback policy.
- The backend directory query excludes `is_demo=true` records, but currently returns non-demo catalogue rows regardless of `approval_status` and `operational_status`.
- The response includes both status fields so consumers can distinguish pending/unverified stations.
- The service-role key remains server-side; this directory service does not place it in Flutter.

This means the 62 non-demo rows can appear in the authenticated directory while still being unapproved and unverified. They must not be treated as operational stations for observation submission, station assignment, or scientific reporting.

## Required follow-up before operational station use

1. Review the 62 non-demo station records against the new station catalogue supplied for METRA.
2. Obtain authoritative coordinates and WMO identifiers for the 12 non-demo entries in the missing-coordinate list.
3. Keep the three demo stations visibly marked as demo and out of production operational workflows.
4. Approve stations and change operational status only through the reviewed station-catalogue approval workflow, not by direct SQL edits.
5. Re-run station provenance, coordinate integrity, data SHA-256, and API smoke tests after approved corrections.

## Acceptance boundary

The current transfer package preserves the source station catalogue and its statuses exactly. It does not manufacture coordinates, assign WMO IDs, approve stations, or mark them active. The 15 missing-coordinate entries and the 65 pending/unverified statuses remain open data-quality tasks.
