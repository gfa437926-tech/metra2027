#!/usr/bin/env python3
"""Verify fields catalog: fields-174.csv or chunks 0-4."""
import csv, json, sys, pathlib
root = pathlib.Path(__file__).resolve().parent
rows = []
p = root / "fields-174.csv"
if p.exists():
    r = list(csv.reader(p.open(encoding="utf-8")))
    rows = r[1:]
else:
    for i in range(5):
        cp = root / f"fields-174-chunk-{i}.csv"
        if not cp.exists():
            print("MISSING", cp)
            sys.exit(1)
        r = list(csv.reader(cp.open(encoding="utf-8")))
        rows.extend(r[1:])
uids = [x[0] for x in rows]
print("count", len(rows), "unique", len(set(uids)))
assert len(rows) == 174 and len(set(uids)) == 174
jp = root / "fields-174.json"
if jp.exists():
    data = json.load(jp.open(encoding="utf-8"))
    print("json", len(data), len({d["field_uid"] for d in data}))
    assert len(data) == 174
print("OK")
