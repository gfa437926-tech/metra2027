#!/usr/bin/env python3
"""Rewrite only declared auth.users FK UUID fields in a plain pg_dump COPY stream."""
from __future__ import annotations

import argparse
import csv
import os
import re
import stat
import sys
import uuid
from pathlib import Path

COPY_RE = re.compile(
    r'^COPY (?P<schema>"(?:[^"]|"")+"|[A-Za-z_][A-Za-z0-9_$]*)\.'
    r'(?P<table>"(?:[^"]|"")+"|[A-Za-z_][A-Za-z0-9_$]*) '
    r'\((?P<columns>.*)\) FROM stdin;\s*$'
)


def unquote_ident(value: str) -> str:
    value = value.strip()
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1].replace('""', '"')
    return value


def split_ident_list(value: str) -> list[str]:
    result: list[str] = []
    token: list[str] = []
    quoted = False
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == '"':
            token.append(ch)
            if quoted and i + 1 < len(value) and value[i + 1] == '"':
                token.append('"')
                i += 1
            else:
                quoted = not quoted
        elif ch == ',' and not quoted:
            result.append(unquote_ident(''.join(token)))
            token = []
        else:
            token.append(ch)
        i += 1
    if quoted:
        raise ValueError("Unclosed quoted identifier in COPY header")
    if token:
        result.append(unquote_ident(''.join(token)))
    return result


def split_copy_fields(line: str) -> list[str]:
    fields: list[str] = []
    token: list[str] = []
    escaped = False
    for ch in line:
        if escaped:
            token.append(ch)
            escaped = False
        elif ch == "\\":
            token.append(ch)
            escaped = True
        elif ch == "\t":
            fields.append(''.join(token))
            token = []
        else:
            token.append(ch)
    fields.append(''.join(token))
    return fields


def load_inventory(path: Path) -> dict[tuple[str, str], set[str]]:
    if not path.is_file():
        raise ValueError(f"Auth FK inventory is missing: {path}")
    result: dict[tuple[str, str], set[str]] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for line_number, raw in enumerate(handle, start=1):
            row = raw.rstrip("\r\n")
            if not row:
                continue
            parts = row.split("\t")
            if len(parts) != 7:
                raise ValueError(
                    f"Invalid Auth FK inventory row {line_number}: expected 7 tab-separated fields"
                )
            schema, table, column, ref_schema, ref_table, ref_column, _constraint = parts
            if (ref_schema, ref_table, ref_column) != ("auth", "users", "id"):
                raise ValueError(
                    f"Unsupported Auth FK target on inventory row {line_number}: "
                    f"{ref_schema}.{ref_table}.{ref_column}"
                )
            result.setdefault((schema, table), set()).add(column)
    return result


def load_mapping(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise ValueError(f"Auth UUID mapping file is missing: {path}")
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        raise ValueError("Auth UUID mapping file must not be accessible by group or others (chmod 600)")
    mapping: dict[str, str] = {}
    target_ids: set[str] = set()
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != ["source_user_id", "target_user_id"]:
            raise ValueError("Mapping CSV headers must be source_user_id,target_user_id")
        for line_number, row in enumerate(reader, start=2):
            source = str(uuid.UUID((row.get("source_user_id") or "").strip()))
            target = str(uuid.UUID((row.get("target_user_id") or "").strip()))
            if source in mapping:
                raise ValueError(f"Duplicate source UUID on mapping row {line_number}")
            if target in target_ids:
                raise ValueError(f"Duplicate target UUID on mapping row {line_number}")
            mapping[source] = target
            target_ids.add(target)
    if not mapping:
        raise ValueError("Auth UUID mapping file contains no mappings")
    return mapping


def transform(source_path: Path, output_path: Path, inventory: dict[tuple[str, str], set[str]],
              mapping: dict[str, str]) -> int:
    pending = {key: set(columns) for key, columns in inventory.items()}
    in_copy = False
    active_indexes: list[int] = []
    active_table: tuple[str, str] | None = None
    replacements = 0

    with source_path.open(encoding="utf-8", newline="") as src, output_path.open(
        "w", encoding="utf-8", newline=""
    ) as dst:
        for raw in src:
            line = raw.rstrip("\r\n")
            if not in_copy:
                match = COPY_RE.match(line)
                if match:
                    table = (unquote_ident(match.group("schema")), unquote_ident(match.group("table")))
                    if table in pending:
                        columns = split_ident_list(match.group("columns"))
                        missing = pending[table] - set(columns)
                        if missing:
                            raise ValueError(
                                f"COPY block for {table[0]}.{table[1]} omits Auth FK columns: "
                                + ", ".join(sorted(missing))
                            )
                        active_indexes = [columns.index(col) for col in sorted(pending[table])]
                        active_table = table
                        pending.pop(table)
                    else:
                        active_indexes = []
                        active_table = None
                    in_copy = True
                dst.write(raw)
                continue

            if line == r"\.":
                in_copy = False
                active_indexes = []
                active_table = None
                dst.write(raw)
                continue

            if active_table is None:
                dst.write(raw)
                continue

            fields = split_copy_fields(line)
            for index in active_indexes:
                value = fields[index]
                if value == r"\N":
                    continue
                try:
                    source_id = str(uuid.UUID(value))
                except ValueError as exc:
                    raise ValueError(
                        f"Non-UUID value in declared Auth FK column "
                        f"{active_table[0]}.{active_table[1]}: {value!r}"
                    ) from exc
                if source_id not in mapping:
                    raise ValueError(
                        f"Missing Auth UUID mapping for source user {source_id} "
                        f"in {active_table[0]}.{active_table[1]}"
                    )
                fields[index] = mapping[source_id]
                replacements += 1
            dst.write("\t".join(fields) + ("\n" if raw.endswith("\n") else ""))

    if in_copy:
        raise ValueError("Input dump ended before COPY terminator")
    if pending:
        missing_tables = ", ".join(f"{s}.{t}" for s, t in sorted(pending))
        raise ValueError(f"Data dump lacks COPY blocks for Auth FK tables: {missing_tables}")
    return replacements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--mapping", type=Path, required=True)
    parser.add_argument("--print-target-ids", action="store_true")
    parser.add_argument("--count", action="store_true")
    args = parser.parse_args()

    try:
        mapping = load_mapping(args.mapping)
        if args.print_target_ids:
            print(",".join(sorted(mapping.values())))
            return 0
        if args.count:
            print(len(mapping))
            return 0
        if args.dump is None or args.output is None:
            parser.error("--dump and --output are required unless printing mapping metadata")
        inventory = load_inventory(args.inventory)
        replacements = transform(args.dump, args.output, inventory, mapping)
        print(f"Remapped {replacements} declared Auth FK values across {len(inventory)} tables.")
        return 0
    except (OSError, ValueError, KeyError) as exc:
        print(f"Auth UUID remap refused: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
