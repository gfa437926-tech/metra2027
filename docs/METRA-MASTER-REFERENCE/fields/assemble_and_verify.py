#!/usr/bin/env python3
"""Assemble and verify METRA field catalog (174 records).

Sources (committed):
  fields-174-part1.csv  (87 rows)
  fields-174-part2.csv  (87 rows)

Outputs (written by this script):
  fields-174.csv
  fields-174.json

Exit 0 on success; non-zero on any check failure.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXPECTED_TOTAL = 174
EXPECTED_BY_FORM = {
    "hourly": 36,
    "daily": 32,
    "agricultural": 31,
    "fault-telecom": 21,
    "hourly-climate": 15,
    "fault-equipment": 15,
    "fault-it": 10,
    "rainfall": 7,
    "soil": 7,
}
REQUIRED_COLUMNS = {
    "field_uid",
    "field_id",
    "name_ar",
    "form_id",
    "screen_id",
    "requirement_id",
    "data_type",
    "unit",
    "min",
    "max",
    "required",
    "bound_source",
    "screen_source",
}


def load_parts() -> list:
    p1 = ROOT / "fields-174-part1.csv"
    p2 = ROOT / "fields-174-part2.csv"
    if not p1.exists() or not p2.exists():
        print("FAIL: missing source parts")
        print(" expected:", p1.name, p2.name)
        sys.exit(1)
    r1 = list(csv.DictReader(p1.open(encoding="utf-8")))
    r2 = list(csv.DictReader(p2.open(encoding="utf-8")))
    if len(r1) != 87 or len(r2) != 87:
        print(f"FAIL: part sizes expected 87+87 got {len(r1)}+{len(r2)}")
        sys.exit(2)
    return r1 + r2


def fail(msg: str, code: int = 3) -> None:
    print("FAIL:", msg)
    sys.exit(code)


def main() -> None:
    rows = load_parts()
    print("loaded_parts", len(rows))

    for i, r in enumerate(rows):
        missing = REQUIRED_COLUMNS - set(r.keys())
        if missing:
            fail(f"row {i} missing columns {sorted(missing)}")
        if not (r.get("field_uid") or "").strip():
            fail(f"row {i} empty field_uid")
        if not (r.get("field_id") or "").strip():
            fail(f"row {i} empty field_id")
        if not (r.get("form_id") or "").strip():
            fail(f"row {i} empty form_id")

    if len(rows) != EXPECTED_TOTAL:
        fail(f"count {len(rows)} != {EXPECTED_TOTAL}")

    uids = [r["field_uid"] for r in rows]
    if len(set(uids)) != EXPECTED_TOTAL:
        fail(f"unique field_uid {len(set(uids))} != {EXPECTED_TOTAL}")

    pairs = [(r["form_id"], r["field_id"]) for r in rows]
    if len(set(pairs)) != EXPECTED_TOTAL:
        fail(f"unique (form_id,field_id) {len(set(pairs))} != {EXPECTED_TOTAL}")

    by_form = dict(Counter(r["form_id"] for r in rows))
    if by_form != EXPECTED_BY_FORM:
        fail(f"form distribution mismatch actual={by_form} expected={EXPECTED_BY_FORM}")

    print("count", len(rows))
    print("unique_field_uid", len(set(uids)))
    print("unique_form_field_id", len(set(pairs)))
    print("by_form", by_form)

    no_screen = sum(1 for r in rows if not (r.get("screen_id") or "").strip())
    print("fields_without_screen_id", no_screen)

    cols = list(rows[0].keys())
    csv_path = ROOT / "fields-174.csv"
    json_path = ROOT / "fields-174.json"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    json.dump(rows, json_path.open("w", encoding="utf-8"), ensure_ascii=False, indent=2)

    csv_rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    json_rows = json.load(json_path.open(encoding="utf-8"))
    if len(csv_rows) != EXPECTED_TOTAL or len(json_rows) != EXPECTED_TOTAL:
        fail("written CSV/JSON length mismatch")
    csv_uids = [r["field_uid"] for r in csv_rows]
    json_uids = [r["field_uid"] for r in json_rows]
    if csv_uids != json_uids:
        fail("CSV and JSON field_uid order/content mismatch")
    if len(set(csv_uids)) != EXPECTED_TOTAL:
        fail("written CSV unique field_uid failed")

    print("WROTE", csv_path.name, json_path.name)
    print("csv_json_match", True)
    print("OK")


if __name__ == "__main__":
    main()
