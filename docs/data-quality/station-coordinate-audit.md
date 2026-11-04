# Station coordinate completeness audit

**Audit date:** 2026-11-04  
**Target database:** METRA 2027 Supabase project  
**Scope:** Non-demo rows in `public.station_catalogue`, matched to current rows in `public.station_coordinates` where `valid_to IS NULL`.

## Verified counts

| Station type | Catalogue records | Current coordinates | Missing current coordinates |
|---|---:|---:|---:|
| Classic | 29 | 17 | 12 |
| Automatic | 33 | 33 | 0 |
| **Total** | **62** | **50** | **12** |

The missing-coordinate rows are all classic catalogue records. The map client correctly excludes stations without a valid coordinate pair; it also shows the count of stations not plotted and retains the full station list. Therefore, these 12 records cannot be truthfully plotted until verified coordinates are supplied.

## Records requiring coordinate verification

| Local station code | Arabic catalogue name |
|---|---|
| 20 | الإدارة العامة |
| 13 | البوكمال |
| 23 | بوقا |
| 24 | حلب الجامعية |
| 16 | حمام واصل |
| 21 | درعا |
| 15 | دير الزور |
| 25 | زاهد |
| 11 | صحنايا |
| 29 | عين العرب الجنوبية |
| 6 | محطة حماه |
| 1 | مركز بحوث الغاب |

## Data-quality and safety decision

- No coordinates were fabricated, estimated from city centres, or inserted as operational station coordinates.
- No rows were changed by this audit.
- The legacy database was not accessed or modified.
- Each location must be verified against an authoritative station register, survey, GPS record, or documented official source before inserting a coordinate record.
- The coordinate record should preserve its source using `coordinate_source` and, where available, `source_reference` and `accuracy_m`.
- Until verification is complete, these records remain visible in the directory list but are not represented by map markers.

## Release follow-up

1. Obtain the authoritative coordinate register for the 12 records.
2. Resolve whether administrative entries such as `الإدارة العامة` are physical observing stations or non-station catalogue entities.
3. Review coordinate precision and station identity before inserting verified records into the new project.
4. Re-run this audit and confirm that every physical station intended for the map has one current coordinate record.

This document is a read-only audit result, not a migration or a substitute for field verification.
