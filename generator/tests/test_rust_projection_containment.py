import asyncio
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
REPO_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

import cli as cli_module
import generated_projection as projection
import main as generator_main


class RustProjectionContainmentTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp_dir.name) / "rust_out"
        self.root.mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self.temp_dir.cleanup()

    async def test_rust_projection_rejects_escaping_paths(self):
        escaping_targets = {
            "../escaped.rs": "pub struct Escaped;",
            "/etc/passwd.rs": "root:x:0:0",
            "app/../../../outside.rs": "pub struct Outside;",
            "app/bsky/../../../../outside.rs": "pub struct Outside;",
            "app\\bsky\\post.rs": "pub struct BadSep;",
            "app/bsky/post.txt": "wrong ext",
        }
        for path, content in escaping_targets.items():
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    await projection.write_rust_projection(str(self.root), {path: content})

    async def test_rust_projection_rejects_symlink_aliases_and_components(self):
        evil_dir = self.root / "symlink_dir"
        target_dir = pathlib.Path(self.temp_dir.name) / "outside_dir"
        target_dir.mkdir(parents=True, exist_ok=True)
        os.symlink(str(target_dir), str(evil_dir))

        with self.assertRaises(ValueError):
            await projection.write_rust_projection(
                str(self.root),
                {"symlink_dir/injected.rs": "pub struct Injected;\n"},
            )

    async def test_rust_projection_rejects_case_and_unicode_alias_collisions(self):
        with self.assertRaisesRegex(ValueError, "aliases another case or Unicode spelling"):
            await projection.write_rust_projection(
                str(self.root),
                {
                    "app/post.rs": "pub struct Lower;\n",
                    "app/Post.rs": "pub struct Upper;\n",
                },
            )

        with self.assertRaisesRegex(ValueError, "aliases another case or Unicode spelling"):
            await projection.write_rust_projection(
                str(self.root),
                {
                    "app/caf\u00e9.rs": "pub struct Nfc;\n",
                    "app/cafe\u0301.rs": "pub struct Nfd;\n",
                },
            )

    async def test_rust_projection_removes_stale_files_and_preserves_unheadered_lib_rs(self):
        handwritten_lib = self.root / "lib.rs"
        handwritten_lib.write_text("#[rustfmt::skip]\npub mod generated;\n", encoding="utf-8")
        handwritten_extra = self.root / "custom_helper.rs"
        handwritten_extra.write_text("pub fn helper() {}\n", encoding="utf-8")

        initial_files = {
            "mod.rs": "pub mod com;\n",
            "com/mod.rs": "pub mod atproto;\n",
            "com/atproto/mod.rs": "pub mod old;\npub mod repo;\n",
            "com/atproto/repo.rs": "pub struct Repo;\n",
            "com/atproto/old.rs": "pub struct Old;\n",
        }
        await projection.write_rust_projection(str(self.root), initial_files)

        self.assertTrue((self.root / "com" / "atproto" / "repo.rs").is_file())
        self.assertTrue((self.root / "com" / "atproto" / "old.rs").is_file())
        self.assertTrue(
            (self.root / "mod.rs").read_text(encoding="utf-8").startswith(projection.GENERATED_RUST_HEADER)
        )

        next_files = {
            "mod.rs": "pub mod com;\n",
            "com/mod.rs": "pub mod atproto;\n",
            "com/atproto/mod.rs": "pub mod new_mod;\npub mod repo;\n",
            "com/atproto/repo.rs": "pub struct Repo;\n",
            "com/atproto/new_mod.rs": "pub struct NewMod;\n",
        }
        await projection.write_rust_projection(str(self.root), next_files)

        self.assertTrue((self.root / "com" / "atproto" / "repo.rs").is_file())
        self.assertTrue((self.root / "com" / "atproto" / "new_mod.rs").is_file())
        self.assertFalse((self.root / "com" / "atproto" / "old.rs").exists())
        self.assertEqual(
            handwritten_lib.read_text(encoding="utf-8"),
            "#[rustfmt::skip]\npub mod generated;\n",
        )
        self.assertEqual(
            handwritten_extra.read_text(encoding="utf-8"),
            "pub fn helper() {}\n",
        )


class RustCliAndManifestPlumbingTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_root = pathlib.Path(self.temp_dir.name)

    def tearDown(self):
        self.temp_dir.cleanup()

    def _write_sample_lexicons(self, lex_dir: pathlib.Path) -> None:
        (lex_dir / "com" / "example").mkdir(parents=True, exist_ok=True)
        (lex_dir / "com" / "example" / "ping.json").write_text(
            json.dumps({
                "lexicon": 1,
                "id": "com.example.ping",
                "defs": {
                    "main": {
                        "type": "query",
                        "output": {
                            "encoding": "application/json",
                            "schema": {
                                "type": "object",
                                "properties": {"ok": {"type": "boolean"}},
                            },
                        },
                    }
                },
            }),
            encoding="utf-8",
        )
        # Prefix-module collision case (like blue.catbird.circle + blue.catbird.circle.*)
        (lex_dir / "com" / "example" / "space.json").write_text(
            json.dumps({
                "lexicon": 1,
                "id": "com.example.space",
                "defs": {"main": {"type": "space", "key": "tid", "collections": []}},
            }),
            encoding="utf-8",
        )
        (lex_dir / "com" / "example" / "space").mkdir(parents=True, exist_ok=True)
        (lex_dir / "com" / "example" / "space" / "getInfo.json").write_text(
            json.dumps({
                "lexicon": 1,
                "id": "com.example.space.getInfo",
                "defs": {"main": {"type": "query"}},
            }),
            encoding="utf-8",
        )

    def test_run_py_and_petrel_gen_rust_manifest_check_and_stdout(self):
        pkg_dir = self.temp_root / "rust-pkg"
        lex_dir = pkg_dir / "lexicons"
        out_dir = pkg_dir / "rust" / "src" / "generated"
        self._write_sample_lexicons(lex_dir)

        manifest_path = pkg_dir / "petrel-manifest.json"
        manifest_path.write_text(
            json.dumps({
                "package": {"kind": "core", "name": "TestRust"},
                "lexicons": {"emit": ["lexicons"], "reference": [], "exclude_namespaces": []},
                "rust": {"output": "rust/src/generated", "crate": "test_rust"},
            }),
            encoding="utf-8",
        )

        # Unheadered lib.rs outside/inside output dir stays intact
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "lib.rs").write_text("// hand-written\n", encoding="utf-8")

        res = subprocess.run(
            [sys.executable, str(REPO_ROOT / "run.py"), "--manifest", str(manifest_path), "--language", "rust"],
            cwd=pkg_dir,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, res.stderr)

        self.assertTrue((out_dir / "mod.rs").is_file())
        self.assertTrue((out_dir / "com" / "mod.rs").is_file())
        self.assertTrue((out_dir / "com" / "example" / "mod.rs").is_file())
        self.assertTrue((out_dir / "com" / "example" / "ping.rs").is_file())
        self.assertTrue((out_dir / "com" / "example" / "space" / "mod.rs").is_file())
        self.assertTrue((out_dir / "com" / "example" / "space" / "get_info.rs").is_file())
        self.assertFalse((out_dir / "com" / "example" / "space.rs").exists())
        self.assertEqual((out_dir / "lib.rs").read_text(encoding="utf-8"), "// hand-written\n")

        root_mod = (out_dir / "mod.rs").read_text(encoding="utf-8")
        self.assertTrue(root_mod.startswith(projection.GENERATED_RUST_HEADER))
        self.assertIn("pub mod com;\n", root_mod)

        example_mod = (out_dir / "com" / "example" / "mod.rs").read_text(encoding="utf-8")
        self.assertEqual(
            example_mod.splitlines()[1:],
            ["pub mod ping;", "pub mod space;"],
        )

        # petrel-gen --check --language rust passes with 0 drift
        prev_cwd = os.getcwd()
        try:
            os.chdir(pkg_dir)
            chk_code = cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--check", "--language", "rust"])
            self.assertEqual(chk_code, 0)

            # Hand-edit triggers drift
            ping_path = out_dir / "com" / "example" / "ping.rs"
            ping_path.write_text(ping_path.read_text(encoding="utf-8") + "// drift\n", encoding="utf-8")
            drift_code = cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--check", "--language", "rust"])
            self.assertEqual(drift_code, 1)

            # --stdout emits Rust banner without mutating disk
            ping_path.unlink()
            stdout_code = cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--stdout", "--language", "rust"])
            self.assertEqual(stdout_code, 0)
            self.assertFalse(ping_path.exists())
        finally:
            os.chdir(prev_cwd)

    def test_app_intents_and_legacy_positional_reject_rust(self):
        app_intents_manifest = REPO_ROOT / "generator" / "manifests" / "app-intents-starter.json"
        with self.assertRaisesRegex(ValueError, "does not support --language rust"):
            asyncio.run(generator_main.run_manifest(str(app_intents_manifest), language="rust"))

        declared_rust_manifest = self.temp_root / "app-intents-rust.json"
        data = json.loads(app_intents_manifest.read_text(encoding="utf-8"))
        data["rust"] = {"output": "rust/out"}
        declared_rust_manifest.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "must not declare a 'rust' output"):
            asyncio.run(generator_main.run_manifest(str(declared_rust_manifest), language="swift"))

        with self.assertRaisesRegex(ValueError, "requires --manifest"):
            asyncio.run(generator_main.main(str(self.temp_root), str(self.temp_root / "out"), language="rust"))

    def test_unused_property_type_overrides_fail_rust_manifest(self):
        pkg_dir = self.temp_root / "unused-overrides"
        lex_dir = pkg_dir / "lexicons"
        self._write_sample_lexicons(lex_dir)
        manifest_path = pkg_dir / "manifest.json"
        manifest_path.write_text(
            json.dumps({
                "package": {"kind": "core", "name": "TestRust"},
                "lexicons": {"emit": [str(lex_dir)], "reference": [], "exclude_namespaces": []},
                "rust": {
                    "output": str(pkg_dir / "out"),
                    "property_type_overrides": {"com.missing.lexicon": {"Output.didDoc": "DidDocument"}},
                },
            }),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "rust.property_type_overrides"):
            asyncio.run(generator_main.run_manifest(str(manifest_path), language="rust"))

    def test_inspect_rust_skips_swift_and_kotlin_generators_and_json_includes_rust_metadata(self):
        feed_defs = REPO_ROOT / "generator" / "lexicons" / "app" / "bsky" / "feed" / "defs.json"
        if not feed_defs.is_file():
            self.skipTest("app.bsky.feed.defs not present")

        import io
        import contextlib

        with (
            mock.patch.object(cli_module, "SwiftCodeGenerator", wraps=cli_module.SwiftCodeGenerator) as swift_spy,
            mock.patch.object(cli_module, "KotlinCodeGenerator", wraps=cli_module.KotlinCodeGenerator) as kt_spy,
        ):
            out = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                code = cli_module.cli_main(["inspect", str(feed_defs), "--language", "rust"])
            self.assertEqual(code, 0)
            self.assertEqual(swift_spy.call_count, 0)
            self.assertEqual(kt_spy.call_count, 0)
            self.assertIn("// Lexicon: 1, ID: app.bsky.feed.defs", out.getvalue())
            self.assertIn("pub struct PostView", out.getvalue())

            json_out = io.StringIO()
            with contextlib.redirect_stdout(json_out), contextlib.redirect_stderr(io.StringIO()):
                jcode = cli_module.cli_main(["inspect", str(feed_defs), "--json"])
            self.assertEqual(jcode, 0)
            parsed = json.loads(json_out.getvalue())
            self.assertEqual(parsed["rust_symbol"], "Defs")
            self.assertEqual(parsed["rust_path"], "app/bsky/feed/defs.rs")

    def test_rust_lexicon_documents_generate_check_and_drift(self):
        pkg_dir = self.temp_root / "rust-lex-docs"
        lex_dir = pkg_dir / "lexicons"
        self._write_sample_lexicons(lex_dir)
        out_dir = pkg_dir / "out"
        docs_dir = pkg_dir / "docs-out"
        manifest_path = pkg_dir / "petrel-manifest.json"
        manifest_path.write_text(
            json.dumps({
                "package": {"kind": "core", "name": "TestRustDocs"},
                "lexicons": {"emit": [str(lex_dir)], "reference": [], "exclude_namespaces": []},
                "rust": {
                    "output": str(out_dir),
                    "crate": "test_rust_docs",
                    "crate_path": "crate::generated",
                    "lexicon_documents": {
                        "output": str(docs_dir),
                        "module": "bundled_lexicon_documents",
                    },
                },
            }),
            encoding="utf-8",
        )

        asyncio.run(generator_main.run_manifest(str(manifest_path), language="rust"))
        docs_mod = docs_dir / "mod.rs"
        docs_file = docs_dir / "bundled_lexicon_documents.rs"
        self.assertTrue(docs_mod.is_file())
        self.assertTrue(docs_file.is_file())
        self.assertIn("pub(crate) mod bundled_lexicon_documents;", docs_mod.read_text(encoding="utf-8"))
        docs_src = docs_file.read_text(encoding="utf-8")
        self.assertIn("pub(crate) const COUNT: usize = 3;", docs_src)
        self.assertIn("com.example.ping", docs_src)

        prev_cwd = os.getcwd()
        try:
            os.chdir(pkg_dir)
            self.assertEqual(
                cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--check", "--language", "rust"]),
                0,
            )
            docs_file.write_text(docs_src + "// drift\n", encoding="utf-8")
            self.assertEqual(
                cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--check", "--language", "rust"]),
                1,
            )
            docs_file.unlink()
            self.assertEqual(
                cli_module.cli_main(["generate", "--manifest", "petrel-manifest.json", "--stdout", "--language", "rust"]),
                0,
            )
            self.assertFalse(docs_file.exists())
        finally:
            os.chdir(prev_cwd)

    def test_rust_lexicon_documents_rejects_overlapping_or_ancestor_output_before_writing(self):
        pkg_dir = self.temp_root / "rust-lex-docs-overlap"
        lex_dir = pkg_dir / "lexicons"
        self._write_sample_lexicons(lex_dir)
        parent_dir = pkg_dir / "rust"
        nested_out = parent_dir / "api"
        sentinel = nested_out / "existing.rs"
        nested_out.mkdir(parents=True)
        sentinel.write_text("// Generated by Petrel (Rust). DO NOT EDIT.\n// keep\n", encoding="utf-8")

        for bad_docs_dir in (parent_dir, nested_out, nested_out / "docs"):
            manifest_path = pkg_dir / "overlap-manifest.json"
            manifest_path.write_text(
                json.dumps({
                    "package": {"kind": "core", "name": "TestOverlap"},
                    "lexicons": {"emit": [str(lex_dir)], "reference": [], "exclude_namespaces": []},
                    "rust": {
                        "output": str(nested_out),
                        "crate": "test_overlap",
                        "crate_path": "crate::generated",
                        "lexicon_documents": {
                            "output": str(bad_docs_dir),
                            "module": "bundled_lexicon_documents",
                        },
                    },
                }),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "must not overlap"):
                asyncio.run(generator_main.run_manifest(str(manifest_path), language="rust"))
            self.assertTrue(sentinel.is_file(), f"must not delete existing files before validation for {bad_docs_dir}")


if __name__ == "__main__":
    unittest.main()
