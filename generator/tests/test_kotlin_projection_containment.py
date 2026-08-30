import asyncio
import os
import pathlib
import stat
import tempfile
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(GENERATOR_DIR))

import generated_projection as projection


class KotlinProjectionContainmentTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp_dir.name) / "kotlin_out"
        self.root.mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self.temp_dir.cleanup()

    async def test_kotlin_projection_rejects_escaping_paths(self):
        """Kotlin projection must reject paths attempting to escape output root."""
        escaping_targets = {
            "../Escaped.kt": "package test",
            "/etc/passwd.kt": "root:x:0:0",
            "lexicons/../../../Outside.kt": "package test",
            "lexicons/com/atproto/../../../../Outside.kt": "package test",
        }
        for path, content in escaping_targets.items():
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    await projection.write_kotlin_projection(str(self.root), {path: content})

    async def test_kotlin_projection_rejects_symlink_aliases_and_components(self):
        """Kotlin projection must reject traversing or creating symlinks (no-follow)."""
        evil_dir = self.root / "symlink_dir"
        target_dir = pathlib.Path(self.temp_dir.name) / "outside_dir"
        target_dir.mkdir(parents=True, exist_ok=True)
        os.symlink(str(target_dir), str(evil_dir))

        with self.assertRaises(ValueError):
            await projection.write_kotlin_projection(
                str(self.root),
                {"symlink_dir/Injected.kt": "package blue.catbird.petrel.generated\n"},
            )

    async def test_kotlin_projection_removes_stale_files_and_preserves_valid(self):
        """Projection must clean up stale generated Kotlin files and keep expected ones atomically."""
        initial_files = {
            "lexicons/com/atproto/Repo.kt": "package blue.catbird.petrel.generated\nclass Repo",
            "lexicons/com/atproto/Old.kt": "package blue.catbird.petrel.generated\nclass Old",
        }
        await projection.write_kotlin_projection(str(self.root), initial_files)

        self.assertTrue((self.root / "lexicons" / "com" / "atproto" / "Repo.kt").exists())
        self.assertTrue((self.root / "lexicons" / "com" / "atproto" / "Old.kt").exists())

        # Next projection run without Old.kt
        next_files = {
            "lexicons/com/atproto/Repo.kt": "package blue.catbird.petrel.generated\nclass Repo",
            "lexicons/com/atproto/New.kt": "package blue.catbird.petrel.generated\nclass New",
        }
        await projection.write_kotlin_projection(str(self.root), next_files)

        self.assertTrue((self.root / "lexicons" / "com" / "atproto" / "Repo.kt").exists())
        self.assertTrue((self.root / "lexicons" / "com" / "atproto" / "New.kt").exists())
        self.assertFalse((self.root / "lexicons" / "com" / "atproto" / "Old.kt").exists())


if __name__ == "__main__":
    unittest.main()
