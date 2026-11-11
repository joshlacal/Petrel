import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "space_lexicon_provenance", ROOT / "Scripts/space_lexicon_provenance.py"
)
PROVENANCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROVENANCE)


class SpaceLexiconProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(PROVENANCE.MANIFEST.read_text())

    def copy_corpus(self, destination):
        for namespace in self.manifest["namespaces"]:
            shutil.copytree(ROOT / "generator/lexicons" / namespace, destination / namespace)

    def test_committed_corpus_matches_reviewed_bytes(self):
        PROVENANCE.verify_tree(ROOT / "generator/lexicons", self.manifest)
        self.assertEqual(len(self.manifest["files"]), 39)

    def test_pin_alone_cannot_hide_changed_added_or_missing_schema(self):
        for mutation in ["changed", "extra", "missing"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.copy_corpus(root)
                path = root / "com/atproto/space/defs.json"
                if mutation == "changed":
                    path.write_bytes(path.read_bytes() + b"\n")
                elif mutation == "extra":
                    path.with_name("unreviewed.json").write_bytes(path.read_bytes())
                else:
                    path.rename(root / "saved-defs.json")
                with self.assertRaisesRegex(ValueError, mutation):
                    PROVENANCE.verify_tree(root, self.manifest)

    def test_weekly_sync_preserves_alpha_corpus_and_updates_standard_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            atproto, bsky, target = root / "atproto", root / "bsky", root / "vendored"
            self.copy_corpus(target)
            for namespace in ["com/atproto", "tools/ozone"]:
                (atproto / namespace).mkdir(parents=True)
            for namespace in ["app/bsky", "chat/bsky", "network/bsky"]:
                (bsky / namespace).mkdir(parents=True)
            # Stable upstream may carry an old alpha directory, or omit it.
            (atproto / "com/atproto/space").mkdir(parents=True)
            (atproto / "com/atproto/space/defs.json").write_text("stale upstream bytes")
            (atproto / "com/atproto/standard.json").write_text("new standard bytes")
            (bsky / "app/bsky/standard.json").write_text("new bsky bytes")
            (target / "com/atproto/obsolete.json").write_text("obsolete standard bytes")
            # Namespaces vendored by hand are not upstream and must survive the sync.
            (target / "com/germnetwork").mkdir(parents=True)
            (target / "com/germnetwork/declaration.json").write_text("third-party bytes")
            (target / "site/standard").mkdir(parents=True)
            (target / "site/standard/document.json").write_text("third-party bytes")
            recorded = ROOT / "generator/provenance/standard-lexicons.json"
            before = recorded.read_bytes()
            try:
                subprocess.run(
                    [
                        "bash", str(ROOT / "Scripts/sync-standard-lexicons.sh"),
                        str(atproto), "a" * 40, str(bsky), "b" * 40, str(target),
                    ],
                    check=True, capture_output=True, text=True,
                )
                provenance = json.loads(recorded.read_text())
            finally:
                recorded.write_bytes(before)
            PROVENANCE.verify_tree(target, self.manifest)
            self.assertEqual((target / "com/atproto/standard.json").read_text(), "new standard bytes")
            self.assertEqual((target / "app/bsky/standard.json").read_text(), "new bsky bytes")
            self.assertFalse((target / "com/atproto/obsolete.json").exists())
            self.assertEqual((target / "com/germnetwork/declaration.json").read_text(), "third-party bytes")
            self.assertEqual((target / "site/standard/document.json").read_text(), "third-party bytes")
            self.assertEqual([source["commit"] for source in provenance["sources"]], ["a" * 40, "b" * 40])

    def test_sync_rejects_an_abbreviated_commit_id(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            completed = subprocess.run(
                [
                    "bash", str(ROOT / "Scripts/sync-standard-lexicons.sh"),
                    str(root), "abc1234", str(root), "b" * 40, str(root / "vendored"),
                ],
                capture_output=True, text=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("not a full commit id", completed.stderr)

    def test_corrupt_archive_is_rejected_before_vendoring(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "wrong.tar.gz"
            archive.write_bytes(b"not the reviewed archive")
            with self.assertRaisesRegex(ValueError, "archive SHA-256"):
                PROVENANCE.archive_corpus(archive, self.manifest)


if __name__ == "__main__":
    unittest.main()
