# Fields package — 174 records

## Verification (local extraction 2026-11-15)
```json
{
  "total_records": 174,
  "unique_field_uid": 174,
  "unique_form_field_id": 174,
  "duplicates": [],
  "by_form": {"hourly":36,"daily":32,"agricultural":31,"fault-telecom":21,"hourly-climate":15,"fault-equipment":15,"fault-it":10,"rainfall":7,"soil":7},
  "verification_passed": true,
  "sha256_csv_full": "638d44a56b469515a35511f405f1b6af9dac14c7b4b68642b4dadb23b0a3d551"
}
```

## Files
| File | Content |
|---|---|
| fields-174.csv | Full 174-row CSV (key columns) |
| fields-174.json | Full array (or part1+part2) |
| fields-{form}.json | Per-form arrays |
| fields-verification.json | Counts + hashes |
| MANIFEST.json | Assembly instructions |

## Assembly
`len(part1)+len(part2)==174` and unique field_uid. Per-form union must equal 174.

## Proven JS bounds (hourly)
dryTemp/wetTemp/dewPoint -20..50; stationPressure 850..1050; relativeHumidity 1..100; windDirection 0..36; windSpeed 0..99; visibility 0..200; utcTime 0..23; dry>=wet.
