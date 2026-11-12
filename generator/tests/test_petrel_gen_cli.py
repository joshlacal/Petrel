import contextlib
import io
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
if str(GENERATOR_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATOR_DIR))

import cli as cli_module
from cli import _find_pinned_swiftformat, cli_main, derive_default_package_name


class PetrelGenCLITests(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        self.temp_root = pathlib.Path(self._temp.name)

    def tearDown(self):
        self._temp.cleanup()

    def _run_cli(self, argv, cwd=None, stdin_bytes=None):
        stdout_buf = io.StringIO()
        stderr_buf = io.StringIO()
        previous_cwd = os.getcwd()
        previous_stdin = sys.stdin
        try:
            if cwd is not None:
                os.chdir(cwd)
            if stdin_bytes is not None:
                text_wrapper = io.TextIOWrapper(io.BytesIO(stdin_bytes), encoding="utf-8")
                sys.stdin = text_wrapper
            with contextlib.redirect_stdout(stdout_buf), contextlib.redirect_stderr(stderr_buf):
                code = cli_main(argv)
        finally:
            sys.stdin = previous_stdin
            os.chdir(previous_cwd)
        return code, stdout_buf.getvalue(), stderr_buf.getvalue()

    def test_derive_default_package_name(self):
        self.assertEqual(derive_default_package_name("xyz.statusphere"), "PetrelStatusphere")
        self.assertEqual(derive_default_package_name("blue.moji"), "PetrelMoji")
        self.assertEqual(derive_default_package_name("com.example.notes"), "PetrelExampleNotes")

    def test_info_reports_bundled_core_lexicons(self):
        code, stdout, stderr = self._run_cli(["info", "--json"], cwd=self.temp_root)
        self.assertEqual(code, 0, stderr)
        info = json.loads(stdout)
        self.assertEqual(info["version"], "2.0.0")
        self.assertEqual(info["bundled_core_lexicons_token"], "@petrel/core-lexicons")
        self.assertGreaterEqual(info["bundled_core_lexicon_count"], 400)
        self.assertIn("blue", info["core_namespace_roots"])
        self.assertTrue(pathlib.Path(info["bundled_core_lexicons_dir"]).is_dir())

    def test_cold_developer_init_and_generate_outside_repo(self):
        project_dir = self.temp_root / "PetrelStatusphere"
        code, stdout, stderr = self._run_cli(
            [
                "init",
                "--namespace",
                "xyz.statusphere",
                "--name",
                "PetrelStatusphere",
                "--dir",
                str(project_dir),
            ],
            cwd=self.temp_root,
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("PetrelStatusphere", stdout)

        manifest_path = project_dir / "petrel-manifest.json"
        package_swift_path = project_dir / "Package.swift"
        sample_lexicon_path = project_dir / "lexicons" / "xyz" / "statusphere" / "status.json"
        self.assertTrue(manifest_path.is_file())
        self.assertTrue(package_swift_path.is_file())
        self.assertTrue(sample_lexicon_path.is_file())
        self.assertTrue((project_dir / "kotlin" / "build.gradle.kts").is_file())
        self.assertTrue((project_dir / "Makefile").is_file())

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["package"]["kind"], "overlay")
        self.assertEqual(manifest["package"]["name"], "PetrelStatusphere")
        self.assertEqual(manifest["package"]["core_namespace_roots"], ["blue"])
        self.assertEqual(manifest["lexicons"]["reference"], ["@petrel/core-lexicons"])

        package_swift = package_swift_path.read_text(encoding="utf-8")
        self.assertIn('.upToNextMinor(from: "2.0.0")', package_swift)
        self.assertIn(".swiftLanguageMode(.v6)", package_swift)
        self.assertNotIn("0.2.0", package_swift)
        expected_dependency_block = (
            "    dependencies: [\n"
            "        .package(\n"
            '            url: "https://github.com/joshlacal/Petrel.git",\n'
            '            .upToNextMinor(from: "2.0.0")\n'
            "        ),\n"
            "    ],\n"
        )
        self.assertIn(expected_dependency_block, package_swift)

        # Add an XRPC query referencing both the local record and bundled core com.atproto.repo.strongRef
        query_lexicon = {
            "lexicon": 1,
            "id": "xyz.statusphere.getStatuses",
            "defs": {
                "main": {
                    "type": "query",
                    "parameters": {
                        "type": "params",
                        "properties": {
                            "limit": {"type": "integer", "minimum": 1, "maximum": 100},
                            "cursor": {"type": "string"},
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["statuses"],
                            "properties": {
                                "statuses": {
                                    "type": "array",
                                    "items": {"type": "ref", "ref": "xyz.statusphere.status"},
                                },
                                "pinned": {
                                    "type": "ref",
                                    "ref": "com.atproto.repo.strongRef",
                                },
                            },
                        },
                    },
                }
            },
        }
        (project_dir / "lexicons" / "xyz" / "statusphere" / "getStatuses.json").write_text(
            json.dumps(query_lexicon, indent=2),
            encoding="utf-8",
        )

        # Generate from inside the isolated external directory
        gen_code, _, gen_stderr = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json"],
            cwd=project_dir,
        )
        self.assertEqual(gen_code, 0, gen_stderr)
        self.assertEqual(gen_stderr, "")

        # Verify Swift 6 overlay outputs
        swift_gen = project_dir / "Sources" / "PetrelStatusphere" / "Generated"
        swift_record = (
            swift_gen / "Lexicons" / "Xyz" / "Statusphere" / "XyzStatusphereStatus.swift"
        ).read_text(encoding="utf-8")
        swift_query = (
            swift_gen / "Lexicons" / "Xyz" / "Statusphere" / "XyzStatusphereGetStatuses.swift"
        ).read_text(encoding="utf-8")
        swift_client = (
            swift_gen / "Client" / "ATProtoClient+PetrelStatusphere.swift"
        ).read_text(encoding="utf-8")
        swift_reg = (
            swift_gen / "Client" / "PetrelStatusphereLexicons.swift"
        ).read_text(encoding="utf-8")

        self.assertIn("import Petrel", swift_record)
        self.assertIn("public struct XyzStatusphereStatus: ATProtocolCodable, ATProtocolValue", swift_record)
        self.assertIn("public let createdAt: ATProtocolDate", swift_record)
        self.assertIn("public func toCBORValue() throws -> Any", swift_record)

        self.assertIn("ComAtprotoRepoStrongRef", swift_query)
        self.assertIn("func getStatuses(", swift_query)

        self.assertIn("public extension ATProtoClient {", swift_client)
        self.assertIn("var xyz: Xyz", swift_client)
        self.assertIn(
            'ATProtocolValueContainer.registerDecoder(forType: "xyz.statusphere.status", as: XyzStatusphereStatus.self)',
            swift_reg,
        )

        # Verify Kotlin overlay outputs
        kt_gen = (
            project_dir
            / "kotlin"
            / "src"
            / "main"
            / "kotlin"
            / "blue"
            / "catbird"
            / "petrel"
            / "generated"
        )
        kt_record = (
            kt_gen / "lexicons" / "xyz" / "statusphere" / "XyzStatusphereStatus.kt"
        ).read_text(encoding="utf-8")
        kt_query = (
            kt_gen / "lexicons" / "xyz" / "statusphere" / "XyzStatusphereGetStatuses.kt"
        ).read_text(encoding="utf-8")
        kt_namespaces = (
            kt_gen / "client" / "PetrelStatusphereNamespaces.kt"
        ).read_text(encoding="utf-8")

        self.assertIn("data class XyzStatusphereStatus(", kt_record)
        self.assertIn("val createdAt: ATProtocolDate", kt_record)
        self.assertIn("suspend fun XyzStatusphereNamespace.getStatuses(", kt_query)
        self.assertIn("data class XyzStatusphereGetStatusesParameters(", kt_query)
        self.assertIn("val ATProtoClient.xyz: XyzNamespace", kt_namespaces)

        # Verify --check succeeds when clean and fails when drifted
        check_fmt_flags = (
            [] if _find_pinned_swiftformat(require=False) is not None else ["--no-format"]
        )
        chk_ok, _, chk_err = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--check", *check_fmt_flags],
            cwd=project_dir,
        )
        self.assertEqual(chk_ok, 0, chk_err)

        reg_file = swift_gen / "Client" / "PetrelStatusphereLexicons.swift"
        original_reg = reg_file.read_text(encoding="utf-8")
        reg_file.write_text(original_reg + "\n// local drift\n", encoding="utf-8")
        chk_fail, _, chk_fail_err = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--check", *check_fmt_flags],
            cwd=project_dir,
        )
        self.assertEqual(chk_fail, 1)
        self.assertIn("out of date", chk_fail_err)

    def test_generate_from_unrelated_cwd_resolves_manifest_directory(self):
        project_dir = self.temp_root / "nested" / "overlay-pkg"
        unrelated_cwd = self.temp_root / "elsewhere"
        unrelated_cwd.mkdir(parents=True)

        init_code, _, init_err = self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir)],
            cwd=unrelated_cwd,
        )
        self.assertEqual(init_code, 0, init_err)

        gen_code, _, gen_err = self._run_cli(
            ["generate", "--manifest", str(project_dir / "petrel-manifest.json")],
            cwd=unrelated_cwd,
        )
        self.assertEqual(gen_code, 0, gen_err)
        self.assertTrue(
            (
                project_dir
                / "Sources"
                / "PetrelStatusphere"
                / "Generated"
                / "Lexicons"
                / "Xyz"
                / "Statusphere"
                / "XyzStatusphereStatus.swift"
            ).is_file()
        )
        self.assertFalse((unrelated_cwd / "Sources").exists())

    def test_shared_core_roots_extend_instead_of_redeclaring(self):
        project_dir = self.temp_root / "blue-overlay"
        self._run_cli(
            ["init", "--namespace", "blue.custom", "--name", "PetrelCustom", "--dir", str(project_dir)],
            cwd=self.temp_root,
        )
        # Even if a user hand-edits petrel-manifest.json and omits core_namespace_roots,
        # petrel-gen inherits bundled core roots ('blue') and extends ATProtoClient.Blue.
        manifest_path = project_dir / "petrel-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["package"].pop("core_namespace_roots", None)
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        code, _, stderr = self._run_cli(["generate"], cwd=project_dir)
        self.assertEqual(code, 0, stderr)
        client_ext = (
            project_dir
            / "Sources"
            / "PetrelCustom"
            / "Generated"
            / "Client"
            / "ATProtoClient+PetrelCustom.swift"
        ).read_text(encoding="utf-8")
        self.assertIn("public extension ATProtoClient.Blue {", client_ext)
        self.assertNotIn("public struct Blue: Sendable {", client_ext)

    def test_generate_stdout_mode_does_not_write_to_disk(self):
        project_dir = self.temp_root / "stdout-overlay"
        self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir)],
            cwd=self.temp_root,
        )
        code, stdout, stderr = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--stdout"],
            cwd=project_dir,
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("// === [swift] Lexicons/Xyz/Statusphere/XyzStatusphereStatus.swift ===", stdout)
        self.assertIn("// === [kotlin] lexicons/xyz/statusphere/XyzStatusphereStatus.kt ===", stdout)
        self.assertFalse((project_dir / "Sources" / "PetrelStatusphere" / "Generated").exists())

    def test_inspect_modes_and_stdin_and_validation(self):
        project_dir = self.temp_root / "inspect-overlay"
        self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir)],
            cwd=self.temp_root,
        )
        lex_file = project_dir / "lexicons" / "xyz" / "statusphere" / "status.json"

        # Summary card
        code, summary_out, stderr = self._run_cli(["inspect", str(lex_file)], cwd=self.temp_root)
        self.assertEqual(code, 0, stderr)
        self.assertIn("xyz.statusphere.status", summary_out)
        self.assertIn("XyzStatusphereStatus", summary_out)
        self.assertIn("string (datetime)", summary_out)

        # JSON mode
        code, json_out, stderr = self._run_cli(
            ["inspect", str(lex_file), "--json", "--no-core-refs"],
            cwd=self.temp_root,
        )
        self.assertEqual(code, 0, stderr)
        parsed = json.loads(json_out)
        self.assertEqual(parsed["id"], "xyz.statusphere.status")
        self.assertEqual(parsed["primary_type"], "record")
        self.assertEqual(parsed["swift_symbol"], "XyzStatusphereStatus")

        # Pure Swift from stdin
        raw_bytes = lex_file.read_bytes()
        code, swift_out, stderr = self._run_cli(
            ["inspect", "-", "--language", "swift", "--overlay", "--no-core-refs"],
            cwd=self.temp_root,
            stdin_bytes=raw_bytes,
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("import Petrel", swift_out)
        self.assertIn("public struct XyzStatusphereStatus", swift_out)

        # Invalid schema rejected cleanly
        bad_code, _, bad_err = self._run_cli(
            ["inspect", "-", "--no-core-refs"],
            cwd=self.temp_root,
            stdin_bytes=b'{"lexicon": 2, "id": "bad"}',
        )
        self.assertNotEqual(bad_code, 0)
        self.assertIn("Expected '\"lexicon\": 1'", bad_err)

    def test_init_refuses_overwrite_without_force_and_run_py_accepts_bundled_token(self):
        project_dir = self.temp_root / "overwrite-guard"
        first_code, _, _ = self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir)],
            cwd=self.temp_root,
        )
        self.assertEqual(first_code, 0)

        second_code, _, second_err = self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir)],
            cwd=self.temp_root,
        )
        self.assertEqual(second_code, 1)
        self.assertIn("refusing to overwrite", second_err)

        forced_code, _, forced_err = self._run_cli(
            ["init", "--namespace", "xyz.statusphere", "--dir", str(project_dir), "--force"],
            cwd=self.temp_root,
        )
        self.assertEqual(forced_code, 0, forced_err)

        # Verify legacy run.py remains 100% backwards-compatible and resolves @petrel/core-lexicons
        result = subprocess.run(
            [
                sys.executable,
                str(REPO_ROOT / "run.py"),
                "--manifest",
                str(project_dir / "petrel-manifest.json"),
                "--language",
                "swift",
            ],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            (
                project_dir
                / "Sources"
                / "PetrelStatusphere"
                / "Generated"
                / "Client"
                / "PetrelStatusphereLexicons.swift"
            ).is_file()
        )

    def test_generate_manifest_prefers_manifest_directory_over_sibling_overlay_cwd(self):
        pkg_a = self.temp_root / "pkg-alpha"
        pkg_b = self.temp_root / "pkg-beta"

        code_a, _, err_a = self._run_cli(
            ["init", "--namespace", "xyz.alpha", "--name", "PetrelAlpha", "--dir", str(pkg_a)],
            cwd=self.temp_root,
        )
        self.assertEqual(code_a, 0, err_a)
        code_b, _, err_b = self._run_cli(
            ["init", "--namespace", "xyz.beta", "--name", "PetrelBeta", "--dir", str(pkg_b)],
            cwd=self.temp_root,
        )
        self.assertEqual(code_b, 0, err_b)

        # Both pkg_a and pkg_b contain `lexicons/`. Running from pkg_a with --manifest
        # pointing at pkg_b must compile pkg_b's schemas into pkg_b without touching pkg_a.
        gen_code, _, gen_err = self._run_cli(
            [
                "generate",
                "--manifest",
                str(pkg_b / "petrel-manifest.json"),
                "--language",
                "swift",
            ],
            cwd=pkg_a,
        )
        self.assertEqual(gen_code, 0, gen_err)

        beta_generated = (
            pkg_b
            / "Sources"
            / "PetrelBeta"
            / "Generated"
            / "Lexicons"
            / "Xyz"
            / "Beta"
            / "XyzBetaStatus.swift"
        )
        self.assertTrue(beta_generated.is_file())
        self.assertIn("public struct XyzBetaStatus", beta_generated.read_text(encoding="utf-8"))
        self.assertFalse((pkg_a / "Sources" / "PetrelAlpha" / "Generated").exists())
        self.assertFalse((pkg_a / "Sources" / "PetrelBeta").exists())

        # Even if pkg_c's emit directory is missing, invoking its manifest from pkg_a
        # must stay anchored at pkg_c and never read pkg_a's lexicons/ or write into pkg_a.
        pkg_c = self.temp_root / "pkg-c"
        pkg_c.mkdir(parents=True)
        (pkg_c / "petrel-manifest.json").write_text(
            (pkg_b / "petrel-manifest.json").read_text(encoding="utf-8"),
            encoding="utf-8",
        )
        self._run_cli(
            ["generate", "--manifest", str(pkg_c / "petrel-manifest.json"), "--language", "swift"],
            cwd=pkg_a,
        )
        self.assertFalse((pkg_a / "Sources" / "PetrelBeta").exists())
        self.assertFalse(
            (
                pkg_c
                / "Sources"
                / "PetrelBeta"
                / "Generated"
                / "Lexicons"
                / "Xyz"
                / "Alpha"
                / "XyzAlphaStatus.swift"
            ).exists()
        )

    def test_check_mode_stages_and_verifies_auxiliary_lexicon_documents(self):
        pkg_dir = self.temp_root / "core-with-lex-docs"
        lex_dir = pkg_dir / "lexicons" / "com" / "example"
        lex_dir.mkdir(parents=True)
        schema_path = lex_dir / "note.json"
        schema_doc = {
            "lexicon": 1,
            "id": "com.example.note",
            "defs": {
                "main": {
                    "type": "record",
                    "key": "tid",
                    "record": {
                        "type": "object",
                        "required": ["text"],
                        "properties": {
                            "text": {"type": "string", "maxLength": 300},
                        },
                    },
                }
            },
        }
        schema_path.write_text(json.dumps(schema_doc, indent=2) + "\n", encoding="utf-8")

        manifest_path = pkg_dir / "petrel-manifest.json"
        manifest_doc = {
            "package": {"kind": "core", "name": "ExampleCore"},
            "lexicons": {"emit": ["lexicons"], "reference": []},
            "swift": {
                "output": "Sources/ExampleCore/Generated",
                "lexicon_documents": {
                    "output": "Sources/ExampleLexicon/Generated",
                    "type": "BundledLexiconDocuments",
                },
            },
        }
        manifest_path.write_text(json.dumps(manifest_doc, indent=2) + "\n", encoding="utf-8")

        gen_code, _, gen_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--language", "swift"],
            cwd=pkg_dir,
        )
        self.assertEqual(gen_code, 0, gen_err)

        bundled_file = (
            pkg_dir / "Sources" / "ExampleLexicon" / "Generated" / "BundledLexiconDocuments.swift"
        )
        self.assertTrue(bundled_file.is_file())
        original_bundled_bytes = bundled_file.read_bytes()

        check_fmt_flags = (
            [] if _find_pinned_swiftformat(require=False) is not None else ["--no-format"]
        )
        clean_code, _, clean_err = self._run_cli(
            [
                "generate",
                "--check",
                "--manifest",
                str(manifest_path),
                "--language",
                "swift",
                *check_fmt_flags,
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(clean_code, 0, clean_err)

        # 1. Schema change that affects only a constraint in lexicon_documents (maxLength 300 -> 500)
        # must be flagged by --check AND must NOT overwrite BundledLexiconDocuments.swift on disk.
        schema_doc["defs"]["main"]["record"]["properties"]["text"]["maxLength"] = 500
        schema_path.write_text(json.dumps(schema_doc, indent=2) + "\n", encoding="utf-8")

        drift_code, _, drift_err = self._run_cli(
            [
                "generate",
                "--check",
                "--manifest",
                str(manifest_path),
                "--language",
                "swift",
                *check_fmt_flags,
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(drift_code, 1)
        self.assertIn("BundledLexiconDocuments.swift", drift_err)
        self.assertEqual(
            bundled_file.read_bytes(),
            original_bundled_bytes,
            "--check must not mutate auxiliary swift.lexicon_documents output on disk",
        )

    def _create_fake_swiftformat(self, version: str = "0.61.1") -> tuple[pathlib.Path, pathlib.Path]:
        script_path = self.temp_root / f"fake-swiftformat-{version.replace('.', '_')}"
        log_path = self.temp_root / f"fake-swiftformat-{version.replace('.', '_')}.jsonl"
        script_body = f"""#!{sys.executable}
import json
import pathlib
import sys

VERSION = {version!r}
LOG_PATH = pathlib.Path({str(log_path)!r})
args = sys.argv[1:]

if args == ["--version"]:
    print(VERSION)
    raise SystemExit(0)

config_path = None
config_text = None
if "--config" in args:
    idx = args.index("--config")
    config_path = args[idx + 1]
    config_text = pathlib.Path(config_path).read_text(encoding="utf-8")

target_dir = pathlib.Path(args[-1])
mode = "custom-config" if config_text else ("inline-core" if "--indent" in args else "default-overlay")
marker = f"// swiftformat-{{VERSION}}:{{mode}}\\n"

touched = []
if target_dir.is_dir():
    for swift_file in sorted(target_dir.rglob("*.swift")):
        content = swift_file.read_text(encoding="utf-8")
        if not content.endswith(marker):
            swift_file.write_text(content + marker, encoding="utf-8")
        touched.append(swift_file.name)

with LOG_PATH.open("a", encoding="utf-8") as handle:
    handle.write(
        json.dumps(
            {{
                "args": args,
                "config_path": config_path,
                "config_text": config_text,
                "mode": mode,
                "target_dir": str(target_dir),
                "touched": touched,
            }}
        )
        + "\\n"
    )
"""
        script_path.write_text(script_body, encoding="utf-8")
        script_path.chmod(0o755)
        return script_path, log_path

    def test_check_mode_formats_staged_swift_and_isolates_overlay_config(self):
        fake_sf, log_path = self._create_fake_swiftformat("0.61.1")

        # Part A: Repository root with `.swiftformat` + both swift.output and lexicon_documents.output
        outer_repo = self.temp_root / "repo-root"
        outer_repo.mkdir(parents=True)
        (outer_repo / "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
        repo_cfg = outer_repo / ".swiftformat"
        repo_cfg.write_text("--indent 4\n--wraparguments before-first\n", encoding="utf-8")

        lex_dir = outer_repo / "lexicons" / "com" / "example"
        lex_dir.mkdir(parents=True)
        (lex_dir / "item.json").write_text(
            json.dumps(
                {
                    "lexicon": 1,
                    "id": "com.example.item",
                    "defs": {
                        "main": {
                            "type": "record",
                            "key": "tid",
                            "record": {
                                "type": "object",
                                "required": ["title"],
                                "properties": {"title": {"type": "string"}},
                            },
                        }
                    },
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        core_manifest = outer_repo / "petrel-manifest.json"
        core_manifest.write_text(
            json.dumps(
                {
                    "package": {"kind": "core", "name": "ExampleCore"},
                    "lexicons": {"emit": ["lexicons"], "reference": []},
                    "swift": {
                        "output": "Sources/ExampleCore/Generated",
                        "lexicon_documents": {
                            "output": "Sources/ExampleLexicon/Generated",
                            "type": "BundledLexiconDocuments",
                        },
                    },
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        # Part B: Nested standalone overlay package inside outer_repo with its own Package.swift and NO .swiftformat
        nested_overlay = outer_repo / "Examples" / "NestedOverlay"
        with mock.patch.dict(os.environ, {"PETREL_SWIFTFORMAT": str(fake_sf)}):
            init_code, _, init_err = self._run_cli(
                [
                    "init",
                    "--namespace",
                    "xyz.nested",
                    "--name",
                    "PetrelNested",
                    "--dir",
                    str(nested_overlay),
                ],
                cwd=outer_repo,
            )
            self.assertEqual(init_code, 0, init_err)

            gen_core_code, _, gen_core_err = self._run_cli(
                ["generate", "--manifest", str(core_manifest), "--language", "swift"],
                cwd=outer_repo,
            )
            self.assertEqual(gen_core_code, 0, gen_core_err)

            core_model = (
                outer_repo
                / "Sources"
                / "ExampleCore"
                / "Generated"
                / "Lexicons"
                / "Com"
                / "Example"
                / "ComExampleItem.swift"
            )
            core_lex_doc = (
                outer_repo
                / "Sources"
                / "ExampleLexicon"
                / "Generated"
                / "BundledLexiconDocuments.swift"
            )
            self.assertTrue(
                core_model.read_text(encoding="utf-8").endswith("// swiftformat-0.61.1:custom-config\n")
            )
            self.assertTrue(
                core_lex_doc.read_text(encoding="utf-8").endswith(
                    "// swiftformat-0.61.1:custom-config\n"
                )
            )
            model_stat_before = core_model.stat()
            lex_doc_stat_before = core_lex_doc.stat()

            log_path.unlink(missing_ok=True)
            chk_core_code, _, chk_core_err = self._run_cli(
                ["generate", "--check", "--manifest", str(core_manifest), "--language", "swift"],
                cwd=outer_repo,
            )
            self.assertEqual(chk_core_code, 0, chk_core_err)
            self.assertEqual(core_model.stat().st_mtime_ns, model_stat_before.st_mtime_ns)
            self.assertEqual(core_lex_doc.stat().st_mtime_ns, lex_doc_stat_before.st_mtime_ns)

            check_invocations = [
                json.loads(line)
                for line in log_path.read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]
            self.assertEqual(len(check_invocations), 2)
            for inv in check_invocations:
                self.assertEqual(pathlib.Path(inv["config_path"]).resolve(), repo_cfg.resolve())
                self.assertNotIn(str(outer_repo), inv["target_dir"])

            # Removing post-format normalization on disk (simulating raw or unpinned-formatter output) fails --check
            raw_without_marker = core_model.read_text(encoding="utf-8").replace(
                "// swiftformat-0.61.1:custom-config\n", ""
            )
            core_model.write_text(raw_without_marker, encoding="utf-8")
            unformatted_code, _, unformatted_err = self._run_cli(
                ["generate", "--check", "--manifest", str(core_manifest), "--language", "swift"],
                cwd=outer_repo,
            )
            self.assertEqual(unformatted_code, 1)
            self.assertIn("ComExampleItem.swift", unformatted_err)

            # Nested overlay must NOT inherit outer_repo/.swiftformat across its Package.swift boundary
            log_path.unlink(missing_ok=True)
            gen_ov_code, _, gen_ov_err = self._run_cli(
                [
                    "generate",
                    "--manifest",
                    str(nested_overlay / "petrel-manifest.json"),
                    "--language",
                    "swift",
                ],
                cwd=outer_repo,
            )
            self.assertEqual(gen_ov_code, 0, gen_ov_err)
            ov_model = (
                nested_overlay
                / "Sources"
                / "PetrelNested"
                / "Generated"
                / "Lexicons"
                / "Xyz"
                / "Nested"
                / "XyzNestedStatus.swift"
            )
            self.assertTrue(
                ov_model.read_text(encoding="utf-8").endswith(
                    "// swiftformat-0.61.1:default-overlay\n"
                )
            )
            chk_ov_code, _, chk_ov_err = self._run_cli(
                [
                    "generate",
                    "--check",
                    "--manifest",
                    str(nested_overlay / "petrel-manifest.json"),
                    "--language",
                    "swift",
                ],
                cwd=outer_repo,
            )
            self.assertEqual(chk_ov_code, 0, chk_ov_err)

    def test_check_mode_rejects_unpinned_or_missing_swiftformat_unless_no_format(self):
        pkg_dir = self.temp_root / "unpinned-guard"
        self._run_cli(
            ["init", "--namespace", "xyz.guard", "--name", "PetrelGuard", "--dir", str(pkg_dir)],
            cwd=self.temp_root,
        )
        gen_code, _, gen_err = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--language", "swift", "--no-format"],
            cwd=pkg_dir,
        )
        self.assertEqual(gen_code, 0, gen_err)

        # 1. Unpinned SwiftFormat (e.g. Homebrew 0.64.0) must fail closed on --check
        fake_064, _ = self._create_fake_swiftformat("0.64.0")
        with mock.patch.dict(os.environ, {"PETREL_SWIFTFORMAT": str(fake_064)}):
            bad_code, _, bad_err = self._run_cli(
                ["generate", "--check", "--manifest", "petrel-manifest.json", "--language", "swift"],
                cwd=pkg_dir,
            )
            self.assertEqual(bad_code, 1)
            self.assertIn("0.64.0", bad_err)
            self.assertIn("0.61.1", bad_err)

            opt_out_code, _, opt_out_err = self._run_cli(
                [
                    "generate",
                    "--check",
                    "--no-format",
                    "--manifest",
                    "petrel-manifest.json",
                    "--language",
                    "swift",
                ],
                cwd=pkg_dir,
            )
            self.assertEqual(opt_out_code, 0, opt_out_err)

        # 2. Missing SwiftFormat 0.61.1 everywhere must fail closed on --check unless --no-format is passed
        isolated_env = {
            k: v
            for k, v in os.environ.items()
            if k not in ("PETREL_SWIFTFORMAT", "RELEASE_MINT", "MINT_PATH")
        }
        isolated_env["PATH"] = ""
        with (
            mock.patch.dict(os.environ, isolated_env, clear=True),
            mock.patch.object(cli_module, "_candidate_release_tools_roots", return_value=[]),
        ):
            missing_code, _, missing_err = self._run_cli(
                ["generate", "--check", "--manifest", "petrel-manifest.json", "--language", "swift"],
                cwd=pkg_dir,
            )
            self.assertEqual(missing_code, 1)
            self.assertIn("0.61.1", missing_err)
            self.assertIn("--no-format", missing_err)

            no_fmt_code, _, no_fmt_err = self._run_cli(
                [
                    "generate",
                    "--check",
                    "--no-format",
                    "--manifest",
                    "petrel-manifest.json",
                    "--language",
                    "swift",
                ],
                cwd=pkg_dir,
            )
            self.assertEqual(no_fmt_code, 0, no_fmt_err)

    def test_inspect_and_generate_stdout_keep_diagnostics_off_stdout_for_multi_def_schemas(self):
        feed_defs = REPO_ROOT / "generator" / "lexicons" / "app" / "bsky" / "feed" / "defs.json"
        self.assertTrue(feed_defs.is_file())

        # 1. `inspect --json` on a multi-def schema (with core refs enabled) must emit pure JSON
        #    and skip KotlinCodeGenerator entirely.
        with mock.patch.object(
            cli_module,
            "KotlinCodeGenerator",
            wraps=cli_module.KotlinCodeGenerator,
        ) as kt_spy:
            json_code, json_out, _ = self._run_cli(["inspect", str(feed_defs), "--json"])
            self.assertEqual(json_code, 0)
            self.assertEqual(kt_spy.call_count, 0)
            parsed = json.loads(json_out)
            self.assertEqual(parsed["id"], "app.bsky.feed.defs")
            self.assertEqual(parsed["primary_type"], "defs-only")
            self.assertIn("postView", parsed["definitions"])

            # 2. `inspect --language swift` must emit pure Swift source (no `Processing def:` / `Loaded `)
            #    and skip KotlinCodeGenerator.
            swift_code, swift_out, _ = self._run_cli(
                ["inspect", str(feed_defs), "--language", "swift"]
            )
            self.assertEqual(swift_code, 0)
            self.assertEqual(kt_spy.call_count, 0)
            self.assertNotIn("Processing def:", swift_out)
            self.assertNotIn("Loaded ", swift_out)
            self.assertTrue(swift_out.startswith("import Foundation"))
            self.assertIn("public struct AppBskyFeedDefs", swift_out)

        # 3. `inspect --language kotlin` must emit pure Kotlin source and skip SwiftCodeGenerator.
        with mock.patch.object(
            cli_module,
            "SwiftCodeGenerator",
            wraps=cli_module.SwiftCodeGenerator,
        ) as swift_spy:
            kt_code, kt_out, _ = self._run_cli(
                ["inspect", str(feed_defs), "--language", "kotlin"]
            )
            self.assertEqual(kt_code, 0)
            self.assertEqual(swift_spy.call_count, 0)
            self.assertNotIn("Processing def:", kt_out)
            self.assertNotIn("Loaded ", kt_out)
            self.assertTrue(kt_out.startswith("// Lexicon: 1, ID: app.bsky.feed.defs"))
            self.assertIn("object AppBskyFeedDefsDefs", kt_out)

        # 4. `generate --stdout` on a multi-def schema must also redirect generator diagnostics to stderr.
        pkg_dir = self.temp_root / "multi-def-stdout"
        self._run_cli(
            ["init", "--namespace", "xyz.multidef", "--name", "PetrelMultidef", "--dir", str(pkg_dir)],
            cwd=self.temp_root,
        )
        defs_schema = {
            "lexicon": 1,
            "id": "xyz.multidef.defs",
            "defs": {
                "badgeView": {
                    "type": "object",
                    "required": ["label"],
                    "properties": {
                        "label": {"type": "string"},
                        "kind": {"type": "string", "knownValues": ["gold", "silver"]},
                    },
                }
            },
        }
        (pkg_dir / "lexicons" / "xyz" / "multidef" / "defs.json").write_text(
            json.dumps(defs_schema, indent=2) + "\n",
            encoding="utf-8",
        )
        gen_out_code, gen_stdout, gen_stderr = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--stdout"],
            cwd=pkg_dir,
        )
        self.assertEqual(gen_out_code, 0, gen_stderr)
        self.assertNotIn("Processing def:", gen_stdout)
        self.assertNotIn("Loaded ", gen_stdout)
        self.assertTrue(gen_stdout.startswith("// === [swift] "))
        self.assertIn("Processing def: badgeView", gen_stderr)

    def test_generate_stdout_applies_and_validates_property_type_overrides(self):
        pkg_dir = self.temp_root / "stdout-overrides"
        self._run_cli(
            ["init", "--namespace", "xyz.overrides", "--name", "PetrelOverrides", "--no-sample", "--dir", str(pkg_dir)],
            cwd=self.temp_root,
        )
        session_schema = {
            "lexicon": 1,
            "id": "xyz.overrides.createSession",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["identifier"],
                            "properties": {
                                "identifier": {"type": "string"},
                            },
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["did", "didDoc"],
                            "properties": {
                                "did": {"type": "string", "format": "did"},
                                "didDoc": {"type": "unknown"},
                            },
                        },
                    },
                }
            },
        }
        schema_file = pkg_dir / "lexicons" / "xyz" / "overrides" / "createSession.json"
        schema_file.parent.mkdir(parents=True, exist_ok=True)
        schema_file.write_text(json.dumps(session_schema, indent=2) + "\n", encoding="utf-8")

        manifest_path = pkg_dir / "petrel-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.pop("kotlin", None)
        manifest["swift"]["property_type_overrides"] = {
            "xyz.overrides.createSession": {"Output.didDoc": "DIDDocument"}
        }
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        # 1. Valid override rewrites Output.didDoc to DIDDocument in --stdout without writing to disk.
        code, stdout, stderr = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--language", "swift", "--stdout", "--no-format"],
            cwd=pkg_dir,
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn(
            "// === [swift] Lexicons/Xyz/Overrides/XyzOverridesCreateSession.swift ===",
            stdout,
        )
        self.assertIn("public let didDoc: DIDDocument", stdout)
        self.assertNotIn("public let didDoc: ATProtocolValueContainer", stdout)
        self.assertFalse((pkg_dir / "Sources" / "PetrelOverrides" / "Generated").exists())

        # 2. Unmatched property_type_overrides fail in --stdout just like normal generate / --check.
        manifest["swift"]["property_type_overrides"]["xyz.overrides.nonexistent"] = {
            "Output.foo": "DIDDocument"
        }
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        bad_code, _, bad_stderr = self._run_cli(
            ["generate", "--manifest", "petrel-manifest.json", "--language", "swift", "--stdout", "--no-format"],
            cwd=pkg_dir,
        )
        self.assertEqual(bad_code, 1)
        self.assertIn("xyz.overrides.nonexistent", bad_stderr)

        # 3. --stdout and --check are mutually exclusive.
        with self.assertRaises(SystemExit) as ctx:
            self._run_cli(
                ["generate", "--manifest", "petrel-manifest.json", "--stdout", "--check"],
                cwd=pkg_dir,
            )
        self.assertEqual(ctx.exception.code, 2)

    def test_app_intents_manifest_generate_check_and_stdout(self):
        intents_pkg = self.temp_root / "intents-pkg"
        manifests_dir = intents_pkg / "manifests"
        manifests_dir.mkdir(parents=True, exist_ok=True)
        (intents_pkg / "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")

        # Symlink core lexicons at a relative path from `manifests_dir` (`../ref-lexicons`)
        # to verify both `lexicons.reference` and `swift.output` anchor at `manifest_path.parent`.
        os.symlink(REPO_ROOT / "generator" / "lexicons", intents_pkg / "ref-lexicons")

        starter = json.loads(
            (REPO_ROOT / "generator" / "manifests" / "app-intents-starter.json").read_text(
                encoding="utf-8"
            )
        )
        starter.pop("$comment", None)
        starter["package"] = {"kind": "app-intents", "name": "SampleAppIntents"}
        starter["lexicons"] = {"reference": ["../ref-lexicons"]}
        starter["swift"] = {"output": "../GeneratedIntents"}
        manifest_path = manifests_dir / "app-intents.json"
        manifest_path.write_text(json.dumps(starter, indent=2) + "\n", encoding="utf-8")

        unrelated_cwd = self.temp_root / "unrelated-intents-cwd"
        unrelated_cwd.mkdir(parents=True, exist_ok=True)

        # 1. Generate from an unrelated CWD -> writes under intents_pkg/GeneratedIntents.
        gen_code, _, gen_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path)],
            cwd=unrelated_cwd,
        )
        self.assertEqual(gen_code, 0, gen_err)

        gen_root = intents_pkg / "GeneratedIntents"
        search_intent = gen_root / "Intents" / "SearchBlueskyProfilesIntent.swift"
        get_profile_intent = gen_root / "Intents" / "GetBlueskyProfileIntent.swift"
        profile_entity = gen_root / "Entities" / "ProfileEntity.swift"
        self.assertTrue(search_intent.is_file())
        self.assertTrue(get_profile_intent.is_file())
        self.assertTrue(profile_entity.is_file())
        self.assertTrue(
            search_intent.read_text(encoding="utf-8").startswith(
                "// GENERATED by app_intents_generator.py — DO NOT EDIT\n"
            )
        )
        self.assertFalse((unrelated_cwd / "GeneratedIntents").exists())

        # 2. `--check` from an unrelated CWD passes cleanly (even without SwiftFormat on PATH).
        with (
            mock.patch.dict(os.environ, {"PATH": ""}, clear=False),
            mock.patch.object(cli_module, "_candidate_release_tools_roots", return_value=[]),
        ):
            os.environ.pop("PETREL_SWIFTFORMAT", None)
            os.environ.pop("RELEASE_MINT", None)
            chk_code, chk_out, chk_err = self._run_cli(
                ["generate", "--manifest", str(manifest_path), "--check"],
                cwd=unrelated_cwd,
            )
        self.assertEqual(chk_code, 0, chk_err)
        self.assertIn("Generated outputs are up to date.", chk_out)

        # 3. `--stdout` from an unrelated CWD emits all curated App Intents & Entities.
        out_code, out_stdout, out_stderr = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--stdout"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(out_code, 0, out_stderr)
        self.assertIn(
            "// === [swift] Intents/SearchBlueskyProfilesIntent.swift ===",
            out_stdout,
        )
        self.assertIn(
            "// === [swift] Entities/ProfileEntity.swift ===",
            out_stdout,
        )
        self.assertIn("// GENERATED by app_intents_generator.py — DO NOT EDIT", out_stdout)

        # 4. Mutating an AppIntent file triggers `[Swift modified]` without overwriting it.
        original_search = search_intent.read_text(encoding="utf-8")
        mutated_search = original_search + "\n// manual drift\n"
        search_intent.write_text(mutated_search, encoding="utf-8")
        mod_code, _, mod_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--check"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(mod_code, 1)
        self.assertIn("[Swift modified]", mod_err)
        self.assertIn("SearchBlueskyProfilesIntent.swift", mod_err)
        self.assertEqual(search_intent.read_text(encoding="utf-8"), mutated_search)
        search_intent.write_text(original_search, encoding="utf-8")

        # 5. Deleting an AppIntent file triggers `[Swift missing]`.
        saved_get_profile = get_profile_intent.read_text(encoding="utf-8")
        get_profile_intent.unlink()
        miss_code, _, miss_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--check"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(miss_code, 1)
        self.assertIn("[Swift missing]", miss_err)
        self.assertIn("GetBlueskyProfileIntent.swift", miss_err)
        get_profile_intent.write_text(saved_get_profile, encoding="utf-8")

        # 6. Stale file with `app_intents_generator.py` header triggers `[Swift stale]`,
        #    while `--language kotlin` fails cleanly.
        stale_file = gen_root / "Intents" / "ObsoleteIntent.swift"
        stale_file.write_text(
            "// GENERATED by app_intents_generator.py — DO NOT EDIT\n// Source: app.bsky.actor.defs\n",
            encoding="utf-8",
        )
        stale_code, _, stale_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--check"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(stale_code, 1)
        self.assertIn("[Swift stale]", stale_err)
        self.assertIn("ObsoleteIntent.swift", stale_err)

        kt_code, _, kt_err = self._run_cli(
            ["generate", "--manifest", str(manifest_path), "--language", "kotlin", "--stdout"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(kt_code, 1)
        self.assertIn("does not support --language kotlin", kt_err)

        # 7. Bundled lexicon tokens (`@petrel/core-lexicons` / `petrel:core`) work symmetrically
        #    across normal `generate`, `--check`, and `--stdout`, and non-object JSON manifests fail cleanly.
        bundled_starter = json.loads(manifest_path.read_text(encoding="utf-8"))
        bundled_starter["lexicons"] = {"reference": ["@petrel/core-lexicons"]}
        bundled_starter["swift"] = {"output": "../GeneratedBundledIntents"}
        bundled_manifest_path = manifests_dir / "bundled-app-intents.json"
        bundled_manifest_path.write_text(
            json.dumps(bundled_starter, indent=2) + "\n", encoding="utf-8"
        )
        b_gen_code, _, b_gen_err = self._run_cli(
            ["generate", "--manifest", str(bundled_manifest_path)],
            cwd=unrelated_cwd,
        )
        self.assertEqual(b_gen_code, 0, b_gen_err)
        b_chk_code, _, b_chk_err = self._run_cli(
            ["generate", "--manifest", str(bundled_manifest_path), "--check"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(b_chk_code, 0, b_chk_err)
        b_out_code, b_out_stdout, b_out_err = self._run_cli(
            ["generate", "--manifest", str(bundled_manifest_path), "--stdout"],
            cwd=unrelated_cwd,
        )
        self.assertEqual(b_out_code, 0, b_out_err)
        self.assertIn(
            "// === [swift] Intents/SearchBlueskyProfilesIntent.swift ===",
            b_out_stdout,
        )

        non_dict_manifest = manifests_dir / "not-an-object.json"
        non_dict_manifest.write_text("[]\n", encoding="utf-8")
        nd_code, _, nd_err = self._run_cli(
            ["generate", "--manifest", str(non_dict_manifest)],
            cwd=unrelated_cwd,
        )
        self.assertEqual(nd_code, 1)
        self.assertIn("must be a JSON object", nd_err)

    def test_nested_lexicon_documents_output_generate_check_and_stdout(self):
        pkg_dir = self.temp_root / "nested-lex-docs"
        self._run_cli(
            ["init", "--namespace", "xyz.nested", "--name", "PetrelNested", "--dir", str(pkg_dir)],
            cwd=self.temp_root,
        )
        manifest_path = pkg_dir / "petrel-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.pop("kotlin", None)
        manifest["swift"]["lexicon_documents"] = {
            "output": "Sources/PetrelNested/Generated/Documents",
            "type": "BundledLexiconDocuments",
        }
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        fmt_flags = [] if _find_pinned_swiftformat(require=False) is not None else ["--no-format"]

        gen_code, _, gen_err = self._run_cli(
            ["generate", *fmt_flags, "--manifest", "petrel-manifest.json", "--language", "swift"],
            cwd=pkg_dir,
        )
        self.assertEqual(gen_code, 0, gen_err)

        gen_root = pkg_dir / "Sources" / "PetrelNested" / "Generated"
        nested_docs_file = gen_root / "Documents" / "BundledLexiconDocuments.swift"
        self.assertTrue((gen_root / "Lexicons" / "Xyz" / "Nested" / "XyzNestedStatus.swift").is_file())
        self.assertTrue(nested_docs_file.is_file())

        chk_code, chk_out, chk_err = self._run_cli(
            [
                "generate",
                "--check",
                *fmt_flags,
                "--manifest",
                "petrel-manifest.json",
                "--language",
                "swift",
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(chk_code, 0, chk_err)
        self.assertIn("Generated outputs are up to date.", chk_out)

        out_code, out_stdout, out_err = self._run_cli(
            [
                "generate",
                "--stdout",
                *fmt_flags,
                "--manifest",
                "petrel-manifest.json",
                "--language",
                "swift",
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(out_code, 0, out_err)
        self.assertEqual(
            out_stdout.count("// === [swift] Documents/BundledLexiconDocuments.swift ==="),
            1,
        )
        self.assertIn("// === [swift] Lexicons/Xyz/Nested/XyzNestedStatus.swift ===", out_stdout)

        saved_docs = nested_docs_file.read_text(encoding="utf-8")
        nested_docs_file.write_text(saved_docs + "\n// drift\n", encoding="utf-8")
        drift_code, _, drift_err = self._run_cli(
            [
                "generate",
                "--check",
                *fmt_flags,
                "--manifest",
                "petrel-manifest.json",
                "--language",
                "swift",
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(drift_code, 1)
        self.assertIn("[Swift modified]", drift_err)
        self.assertIn("Documents/BundledLexiconDocuments.swift", drift_err)
        nested_docs_file.write_text(saved_docs, encoding="utf-8")

        stale_nested = gen_root / "Documents" / "StaleDoc.swift"
        stale_nested.write_text(
            "// Generated by Petrel. DO NOT EDIT.\n// stale\n",
            encoding="utf-8",
        )
        stale_code, _, stale_err = self._run_cli(
            [
                "generate",
                "--check",
                *fmt_flags,
                "--manifest",
                "petrel-manifest.json",
                "--language",
                "swift",
            ],
            cwd=pkg_dir,
        )
        self.assertEqual(stale_code, 1)
        self.assertIn("[Swift stale]", stale_err)
        self.assertIn("Documents/StaleDoc.swift", stale_err)

    def test_inspect_client_accessor_supports_arbitrary_nsid_depth(self):
        cases = [
            (
                "fm.example.alpha.feed.getPlay",
                {
                    "type": "query",
                    "output": {
                        "encoding": "application/json",
                        "schema": {"type": "object", "properties": {"ok": {"type": "boolean"}}},
                    },
                },
                "client.fm.example.alpha.feed.getPlay",
            ),
            (
                "com.example.getRoot",
                {
                    "type": "query",
                    "output": {
                        "encoding": "application/json",
                        "schema": {"type": "object", "properties": {"ok": {"type": "boolean"}}},
                    },
                },
                "client.com.example.getRoot",
            ),
            (
                "com.example.doAction",
                {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {"type": "object", "properties": {"ok": {"type": "boolean"}}},
                    },
                },
                "client.com.example.doAction",
            ),
            (
                "fm.example.alpha.feed.play",
                {
                    "type": "record",
                    "key": "tid",
                    "record": {"type": "object", "properties": {"title": {"type": "string"}}},
                },
                "client.fm.example.alpha.feed",
            ),
            (
                "xyz.statusphere.status",
                {
                    "type": "record",
                    "key": "tid",
                    "record": {"type": "object", "properties": {"status": {"type": "string"}}},
                },
                "client.xyz.statusphere",
            ),
        ]

        for nsid, main_def, expected_accessor in cases:
            with self.subTest(nsid=nsid):
                payload = json.dumps({"lexicon": 1, "id": nsid, "defs": {"main": main_def}}).encode(
                    "utf-8"
                )
                code, stdout, stderr = self._run_cli(
                    ["inspect", "-", "--json", "--no-core-refs"],
                    stdin_bytes=payload,
                )
                self.assertEqual(code, 0, stderr)
                meta = json.loads(stdout)
                self.assertEqual(meta["client_accessor"], expected_accessor)

                sum_code, sum_out, sum_err = self._run_cli(
                    ["inspect", "-", "--no-core-refs"],
                    stdin_bytes=payload,
                )
                self.assertEqual(sum_code, 0, sum_err)
                self.assertIn(f"Client Path:     {expected_accessor}", sum_out)


if __name__ == "__main__":
    unittest.main()
