#!/usr/bin/env python3
"""Assemble and deeply verify METRA field catalog (174 records).

Sources (committed):
  fields-174-part1.csv  (87 rows)
  fields-174-part2.csv  (87 rows)

Outputs:
  fields-174.csv
  fields-174.json

Deep checks:
  - identical headers on both parts
  - no duplicate column names
  - required columns present
  - no empty critical cells / corrupt rows
  - 174 records, unique field_uid, unique (form_id, field_id)
  - form distribution
  - after write: CSV vs JSON full-record equality (all keys, all values)
"""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
EXPECTED_TOTAL = 174
EXPECTED_PART = 87
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
REQUIRED_COLUMNS = [
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
]


def fail(msg: str, code: int = 3) -> None:
    print("FAIL:", msg)
    sys.exit(code)


def read_csv_with_header(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.exists():
        fail(f"missing file {path.name}", 1)
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration:
            fail(f"empty file {path.name}", 2)
        if not header:
            fail(f"empty header {path.name}", 2)
        if len(header) != len(set(header)):
            dups = [c for c in header if header.count(c) > 1]
            fail(f"duplicate columns in {path.name}: {sorted(set(dups))}", 2)
        rows: list[dict[str, str]] = []
        for i, cells in enumerate(reader, start=2):
            if len(cells) != len(header):
                fail(
                    f"corrupt row {path.name}:{i} cell_count={len(cells)} header_count={len(header)}",
                    2,
                )
            rows.append(dict(zip(header, cells)))
    return header, rows


def normalize_value(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, bool):
        return "True" if v else "False"
    return str(v)


def records_equal(a: dict, b: dict, cols: list[str]) -> list[str]:
    diffs: list[str] = []
    keys_a = set(a.keys())
    keys_b = set(b.keys())
    if keys_a != keys_b:
        diffs.append(f"key_set_diff only_a={sorted(keys_a-keys_b)} only_b={sorted(keys_b-keys_a)}")
    for c in cols:
        va = normalize_value(a.get(c, ""))
        vb = normalize_value(b.get(c, ""))
        if va != vb:
            diffs.append(f"{c}: csv={va!r} json={vb!r}")
    return diffs


def main() -> None:
    p1 = ROOT / "fields-174-part1.csv"
    p2 = ROOT / "fields-174-part2.csv"
    h1, r1 = read_csv_with_header(p1)
    h2, r2 = read_csv_with_header(p2)

    if h1 != h2:
        fail(f"part headers differ\n part1={h1}\n part2={h2}", 2)
    header = h1
    missing_req = [c for c in REQUIRED_COLUMNS if c not in header]
    if missing_req:
        fail(f"missing required columns: {missing_req}", 2)

    if len(r1) != EXPECTED_PART or len(r2) != EXPECTED_PART:
        fail(f"part sizes expected {EXPECTED_PART}+{EXPECTED_PART} got {len(r1)}+{len(r2)}", 2)

    rows = r1 + r2
    print("loaded_parts", len(rows))
    print("header_columns", len(header))
    print("headers_match", True)

    for i, r in enumerate(rows):
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

    csv_path = ROOT / "fields-174.csv"
    json_path = ROOT / "fields-174.json"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    json.dump(rows, json_path.open("w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("WROTE", csv_path.name, json_path.name)

    csv_header, csv_rows = read_csv_with_header(csv_path)
    json_rows = json.load(json_path.open(encoding="utf-8"))
    if not isinstance(json_rows, list):
        fail("JSON root is not a list")
    if csv_header != header:
        fail("written CSV header differs from source header")
    if len(csv_rows) != EXPECTED_TOTAL or len(json_rows) != EXPECTED_TOTAL:
        fail(f"written lengths csv={len(csv_rows)} json={len(json_rows)}")

    for i in range(EXPECTED_TOTAL):
        diffs = records_equal(csv_rows[i], json_rows[i], header)
        if diffs:
            print(f"MISMATCH record[{i}] field_uid={csv_rows[i].get('field_uid')}")
            for d in diffs[:10]:
                print(" ", d)
            fail(f"CSV/JSON full-record mismatch at index {i}")

    print("csv_json_full_record_match", True)
    print("compared_records", EXPECTED_TOTAL)
    print("compared_fields_per_record", len(header))
    print("OK")


if __name__ == "__main__":
    main()
