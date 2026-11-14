from __future__ import annotations

import csv
import sys
import tempfile
import unittest
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import remap_auth_user_ids as remapper


class AuthUserRemapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source_id = "11111111-1111-4111-8111-111111111111"
        self.target_id = "22222222-2222-4222-8222-222222222222"
        self.inventory = self.root / "auth-fks.tsv"
        self.inventory.write_text(
            "public\tuser_profiles\tuser_id\tauth\tusers\tid\tuser_profiles_user_id_fkey\n",
            encoding="utf-8",
        )
        self.mapping = self.root / "mapping.csv"
        with self.mapping.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["source_user_id", "target_user_id"])
            writer.writerow([self.source_id, self.target_id])
        self.mapping.chmod(0o600)

    def tearDown(self):
        self.temp.cleanup()

    def test_remaps_only_declared_fk_column(self):
        source = self.root / "data.sql"
        output = self.root / "remapped.sql"
        source.write_text(
            "COPY public.user_profiles (id, user_id, note) FROM stdin;\n"
            f"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\t{self.source_id}\tcontains\\ttab\n"
            "\\N\t\\N\tordinary row\n"
            "\\.\n",
            encoding="utf-8",
        )
        inventory = remapper.load_inventory(self.inventory)
        mapping = remapper.load_mapping(self.mapping)
        count = remapper.transform(source, output, inventory, mapping)
        result = output.read_text(encoding="utf-8")
        self.assertEqual(count, 1)
        self.assertIn(self.target_id, result)
        self.assertNotIn(self.source_id, result)
        self.assertIn("contains\\ttab", result)
        self.assertIn("\\N\t\\N", result)

    def test_unmapped_source_uuid_fails_closed(self):
        source = self.root / "data.sql"
        output = self.root / "remapped.sql"
        other_id = "33333333-3333-4333-8333-333333333333"
        source.write_text(
            "COPY public.user_profiles (user_id) FROM stdin;\n"
            f"{other_id}\n"
            "\\.\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "Missing Auth UUID mapping"):
            remapper.transform(source, output, remapper.load_inventory(self.inventory),
                               remapper.load_mapping(self.mapping))

    def test_missing_fk_column_fails_closed(self):
        source = self.root / "data.sql"
        output = self.root / "remapped.sql"
        source.write_text(
            "COPY public.user_profiles (id) FROM stdin;\n"
            "\\.\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "omits Auth FK columns"):
            remapper.transform(source, output, remapper.load_inventory(self.inventory),
                               remapper.load_mapping(self.mapping))

    def test_mapping_file_must_be_private(self):
        self.mapping.chmod(0o644)
        with self.assertRaisesRegex(ValueError, "chmod 600"):
            remapper.load_mapping(self.mapping)

    def test_duplicate_target_uuid_is_rejected(self):
        with self.mapping.open("a", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["44444444-4444-4444-8444-444444444444", self.target_id])
        self.mapping.chmod(0o600)
        with self.assertRaisesRegex(ValueError, "Duplicate target UUID"):
            remapper.load_mapping(self.mapping)


if __name__ == "__main__":
    unittest.main()
