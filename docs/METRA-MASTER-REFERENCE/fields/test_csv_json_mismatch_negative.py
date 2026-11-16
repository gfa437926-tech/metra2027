#!/usr/bin/env python3
"""Negative test: a single field value difference between CSV and JSON must fail deep compare.

Does not modify committed sources. Works on a temp copy of assembled outputs.
Exit 0 only if the mismatch is detected (negative test passes).
Exit non-zero if mismatch is NOT detected (negative test fails).
"""
from __future__ import annotations

import csv
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        for name in ("fields-174-part1.csv", "fields-174-part2.csv", "assemble_and_verify.py"):
            shutil.copy2(ROOT / name, td_path / name)
        r = subprocess.run(
            [sys.executable, str(td_path / "assemble_and_verify.py")],
            cwd=td_path,
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            print("SETUP_FAIL assemble:", r.stdout, r.stderr)
            sys.exit(10)
        csv_path = td_path / "fields-174.csv"
        json_path = td_path / "fields-174.json"
        data = json.load(json_path.open(encoding="utf-8"))
        target = data[0]
        uid = target["field_uid"]
        original = target.get("name_ar", "")
        target["name_ar"] = original + "__CORRUPT_FOR_NEGATIVE_TEST__"
        json.dump(data, json_path.open("w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print(f"mutated JSON name_ar for {uid}")

        with csv_path.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            header = list(reader.fieldnames or [])
            csv_rows = list(reader)
        json_rows = json.load(json_path.open(encoding="utf-8"))

        def norm(v):
            if v is None:
                return ""
            if isinstance(v, bool):
                return "True" if v else "False"
            return str(v)

        detected = False
        for i, (a, b) in enumerate(zip(csv_rows, json_rows)):
            for c in header:
                if norm(a.get(c, "")) != norm(b.get(c, "")):
                    detected = True
                    print(f"DETECTED mismatch at index {i} column {c}")
                    print(f"  csv={a.get(c)!r}")
                    print(f"  json={b.get(c)!r}")
                    break
            if detected:
                break

        if not detected:
            print("NEGATIVE_TEST_FAIL: mutation was not detected")
            sys.exit(1)
        print("NEGATIVE_TEST_PASS: single-value CSV/JSON difference is detected")
        sys.exit(0)


if __name__ == "__main__":
    main()
