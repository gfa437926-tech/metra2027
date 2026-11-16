# Fields catalog

## Source of truth (committed)
- `fields-174-part1.csv` — 87 rows
- `fields-174-part2.csv` — 87 rows

## Generate full catalog
```bash
python3 assemble_and_verify.py
```
Writes **full** `fields-174.csv` and `fields-174.json` (174 unique records) and verifies distribution and CSV↔JSON match.

## Do not
- Commit a partial file named `fields-174.csv`
- Invent `screen_id` for the 91 unlinked fields without U-03/U-04

See `MANIFEST.json` and `../traceability/FIELD-SCREEN-LINKAGE.md`.
