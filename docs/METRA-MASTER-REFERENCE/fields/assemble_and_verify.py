#!/usr/bin/env python3
"""Assemble fields-174.csv/json from part1+part2 or chunks 0-4; verify 174 unique."""
import csv, json, sys
from pathlib import Path
root = Path(__file__).resolve().parent
rows = []
p1, p2 = root/'fields-174-part1.csv', root/'fields-174-part2.csv'
if p1.exists() and p2.exists():
    r1 = list(csv.DictReader(p1.open(encoding='utf-8')))
    r2 = list(csv.DictReader(p2.open(encoding='utf-8')))
    rows = r1 + r2
else:
    for i in range(5):
        cp = root / f'fields-174-chunk-{i}.csv'
        if not cp.exists():
            print('MISSING', cp); sys.exit(1)
        rows.extend(list(csv.DictReader(cp.open(encoding='utf-8'))))
uids = [r['field_uid'] for r in rows]
print('count', len(rows), 'unique', len(set(uids)))
if len(rows) != 174 or len(set(uids)) != 174:
    print('FAIL'); sys.exit(2)
# write assembled full files
cols = list(rows[0].keys())
with (root/'fields-174.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader(); w.writerows(rows)
json.dump(rows, (root/'fields-174.json').open('w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('WROTE fields-174.csv and fields-174.json')
print('OK')
