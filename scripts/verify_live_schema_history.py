#!/usr/bin/env python3
"""Validate the recovered, non-executable Supabase migration history archive."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "supabase" / "live-schema-history"
ACTIVE = ROOT / "supabase" / "migrations"
EXPECTED_COUNT = 86
EXPECTED_FIRST = "20261102154652"
EXPECTED_LAST = "20261114204951"
MIGRATION_NAME = re.compile(r"^(?P<version>\d{14})_(?P<name>[A-Za-z0-9_-]+)\.sql$")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not ARCHIVE.is_dir():
        fail(f"missing recovered archive directory: {ARCHIVE}")

    archive_files = sorted(ARCHIVE.glob("*.sql"))
    if len(archive_files) != EXPECTED_COUNT:
        fail(f"expected {EXPECTED_COUNT} archived SQL files, found {len(archive_files)}")

    by_version: dict[str, Path] = {}
    for path in archive_files:
        match = MIGRATION_NAME.fullmatch(path.name)
        if match is None:
            fail(f"invalid archive filename: {path.name}")
        version = match.group("version")
        if version in by_version:
            fail(f"duplicate archived migration version: {version}")
        if not path.read_text(encoding="utf-8").strip():
            fail(f"empty archived migration: {path.name}")
        by_version[version] = path

    versions = sorted(by_version)
    if versions[0] != EXPECTED_FIRST or versions[-1] != EXPECTED_LAST:
        fail(f"unexpected archive range: {versions[0]}..{versions[-1]}")

    active_files = sorted(ACTIVE.glob("*.sql"))
    if not active_files:
        fail("active migration directory unexpectedly contains no SQL files")

    for active_path in active_files:
        match = MIGRATION_NAME.fullmatch(active_path.name)
        if match is None:
            fail(f"invalid active migration filename: {active_path.name}")
        version = match.group("version")
        archived_path = by_version.get(version)
        if archived_path is None:
            fail(f"active migration version is absent from recovered history: {version}")
        if active_path.read_bytes() != archived_path.read_bytes():
            fail(f"active migration differs from recovered applied SQL: {active_path.name}")

    print(
        "Supabase migration archive verified: "
        f"{len(archive_files)} recovered records "
        f"({EXPECTED_FIRST}..{EXPECTED_LAST}); "
        f"{len(active_files)} active-folder files match their exact live SQL source."
    )
    print(
        "NOTE: the recovered archive is not a canonical migration replay set. "
        "This check does not execute SQL or certify a clean database replay."
    )


if __name__ == "__main__":
    main()
