import asyncio
import inspect
import json
import os
import pathlib
import sys
import tempfile
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from main import (
    generate_swift_from_lexicons_recursive,
    generate_swift_overlay_namespaces,
    normalize_core_namespace_roots,
    run_manifest,
)


UNSET = object()


class SwiftNamespaceGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary_directory.name)
        self.core_lexicons = self.root / "core-lexicons"
        self.catbird_lexicons = self.root / "catbird-lexicons"
        self.moji_lexicons = self.root / "moji-lexicons"
        self.core_lexicons.mkdir()
        self.catbird_lexicons.mkdir()
        self.moji_lexicons.mkdir()

        self._write_lexicon(self.core_lexicons, "com.example.core.item")
        self._write_lexicon(self.catbird_lexicons, "blue.catbird.test.item")
        self._write_lexicon(self.moji_lexicons, "blue.moji.test.item")

    def tearDown(self):
        self.temporary_directory.cleanup()

    @staticmethod
    def _write_lexicon(directory: pathlib.Path, lexicon_id: str) -> None:
        lexicon = {
            "lexicon": 1,
            "id": lexicon_id,
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {},
                }
            },
        }
        (directory / f"{lexicon_id}.json").write_text(
            json.dumps(lexicon),
            encoding="utf-8",
        )

    def _write_manifest(
        self,
        name: str,
        *,
        kind: str,
        package_name: str,
        emit: pathlib.Path,
        output: pathlib.Path,
        core_namespace_roots=UNSET,
        reference=(),
    ) -> pathlib.Path:
        package = {
            "kind": kind,
            "name": package_name,
        }
        if core_namespace_roots is not UNSET:
            package["core_namespace_roots"] = core_namespace_roots

        manifest = {
            "package": package,
            "lexicons": {
                "emit": [str(emit)],
                "reference": [str(path) for path in reference],
                "exclude_namespaces": [],
            },
            "swift": {"output": str(output)},
        }
        path = self.root / f"{name}.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    @staticmethod
    def _run_manifest(path: pathlib.Path) -> None:
        asyncio.run(run_manifest(str(path), language="swift"))

    @staticmethod
    def _client_source(output: pathlib.Path, filename: str) -> str:
        return (output / "Client" / filename).read_text(encoding="utf-8")

    def test_core_manifest_synthesizes_configured_root_with_immutable_value_semantics(self):
        output = self.root / "core-output"
        manifest = self._write_manifest(
            "core",
            kind="core",
            package_name="Petrel",
            emit=self.core_lexicons,
            output=output,
            core_namespace_roots=["blue"],
        )

        self._run_manifest(manifest)
        generated = self._client_source(output, "ATProtoClient+Generated.swift")

        self.assertIn(
            "public var blue: Blue { Blue(networkService: networkService) }",
            generated,
        )
        self.assertIn("public struct Blue: Sendable {", generated)
        self.assertIn("public let networkService: NetworkService", generated)
        self.assertIn("public init(networkService: NetworkService)", generated)
        for property_name, value_type in (
            ("com", "Com"),
            ("example", "Example"),
            ("core", "Core"),
        ):
            with self.subTest(value_type=value_type):
                self.assertIn(
                    f"public var {property_name}: {value_type} "
                    f"{{ {value_type}(networkService: networkService) }}",
                    generated,
                )
                self.assertIn(f"public struct {value_type}: Sendable {{", generated)
                self.assertRegex(
                    generated,
                    rf"(?s)public struct {value_type}: Sendable \{{\s*"
                    r"public let networkService: NetworkService",
                )
        self.assertNotIn("lazy", generated)
        self.assertNotIn("final class", generated)
        self.assertNotIn("@unchecked Sendable", generated)

    def test_overlays_extend_core_owned_root_and_declare_only_their_child(self):
        cases = (
            ("PetrelCatbird", self.catbird_lexicons, "Catbird", "Moji"),
            ("PetrelBluemoji", self.moji_lexicons, "Moji", "Catbird"),
        )

        for package_name, emit, child, other_child in cases:
            with self.subTest(package_name=package_name):
                output = self.root / f"{package_name}-output"
                manifest = self._write_manifest(
                    package_name,
                    kind="overlay",
                    package_name=package_name,
                    emit=emit,
                    output=output,
                    core_namespace_roots=["blue"],
                    reference=(self.core_lexicons,),
                )

                self._run_manifest(manifest)
                generated = self._client_source(
                    output,
                    f"ATProtoClient+{package_name}.swift",
                )

                child_property = child[0].lower() + child[1:]
                self.assertIn("public extension ATProtoClient.Blue {", generated)
                self.assertIn(
                    f"var {child_property}: {child} "
                    f"{{ {child}(networkService: networkService) }}",
                    generated,
                )
                self.assertIn(f"public struct {child}: Sendable {{", generated)
                self.assertEqual(generated.count(f"public struct {child}: Sendable"), 1)
                self.assertEqual(generated.count(f"var {child_property}: {child}"), 1)
                self.assertIn(
                    "public var test: Test { Test(networkService: networkService) }",
                    generated,
                )
                self.assertIn("public struct Test: Sendable {", generated)
                self.assertEqual(
                    generated.count("public let networkService: NetworkService"),
                    2,
                )
                self.assertNotIn(other_child, generated)
                self.assertNotIn("extension ATProtoClient {", generated)
                self.assertNotIn("struct Blue", generated)
                self.assertNotIn("class Blue", generated)
                self.assertNotIn("lazy", generated)
                self.assertNotIn("final class", generated)
                self.assertNotIn("@unchecked Sendable", generated)

    def test_legacy_boundary_and_manifest_default_to_no_owned_roots(self):
        recursive_parameters = inspect.signature(
            generate_swift_from_lexicons_recursive
        ).parameters
        overlay_parameters = inspect.signature(
            generate_swift_overlay_namespaces
        ).parameters
        self.assertIn("core_namespace_roots", recursive_parameters)
        self.assertIn("core_namespace_roots", overlay_parameters)
        recursive_default = recursive_parameters["core_namespace_roots"].default
        overlay_default = overlay_parameters["core_namespace_roots"].default
        self.assertEqual(recursive_default, ())
        self.assertEqual(overlay_default, ())

        output = self.root / "legacy-output"
        manifest = self._write_manifest(
            "legacy",
            kind="core",
            package_name="Petrel",
            emit=self.core_lexicons,
            output=output,
        )

        self._run_manifest(manifest)
        generated = self._client_source(output, "ATProtoClient+Generated.swift")
        self.assertNotIn("public struct Blue", generated)
        self.assertNotIn("public var blue: Blue", generated)

        overlay_output = self.root / "legacy-overlay-output"
        overlay_manifest = self._write_manifest(
            "legacy-overlay",
            kind="overlay",
            package_name="LegacyOverlay",
            emit=self.catbird_lexicons,
            output=overlay_output,
            reference=(self.core_lexicons,),
        )
        self._run_manifest(overlay_manifest)
        overlay = self._client_source(
            overlay_output,
            "ATProtoClient+LegacyOverlay.swift",
        )
        self.assertIn("public extension ATProtoClient {", overlay)
        self.assertIn("public struct Blue: Sendable {", overlay)
        self.assertNotIn("public extension ATProtoClient.Blue {", overlay)

    def test_overlay_without_key_inherits_core_root_via_package_graph(self):
        # The overlay omits core_namespace_roots; it must still EXTEND
        # ATProtoClient.Blue because the package graph's core package declares
        # `blue` as owned. This is the "can't forget the key" safety net.
        core_output = self.root / "graph-core-output"
        core_manifest = self._write_manifest(
            "graph-core",
            kind="core",
            package_name="Petrel",
            emit=self.core_lexicons,
            output=core_output,
            core_namespace_roots=["blue"],
        )
        overlay_output = self.root / "graph-overlay-output"
        overlay_manifest = self._write_manifest(
            "graph-overlay",
            kind="overlay",
            package_name="PetrelBluemoji",
            emit=self.moji_lexicons,
            output=overlay_output,
            reference=(self.core_lexicons,),
            # NOTE: intentionally omit core_namespace_roots — inherited via graph
        )
        graph = self.root / "package-graph.json"
        graph.write_text(
            json.dumps({"packages": [
                {"name": "Petrel", "kind": "core", "manifest": str(core_manifest)},
                {"name": "PetrelBluemoji", "kind": "overlay", "manifest": str(overlay_manifest)},
            ]}),
            encoding="utf-8",
        )

        asyncio.run(
            run_manifest(str(overlay_manifest), language="swift", graph_path=str(graph))
        )
        overlay = self._client_source(overlay_output, "ATProtoClient+PetrelBluemoji.swift")
        self.assertIn("public extension ATProtoClient.Blue {", overlay)
        self.assertNotIn("public struct Blue: Sendable {", overlay)
        self.assertNotIn("final class Blue", overlay)

    def test_malformed_package_graph_degrades_to_manifest_roots_without_failing(self):
        # A broken graph must NEVER fail generation: the overlay falls back to
        # its own (absent) core_namespace_roots and redeclares — same contract
        # as no graph at all. Covers structurally-malformed shapes that parse
        # as JSON but violate the schema (dict packages, string entries,
        # null manifest, top-level list).
        malformed_graphs = (
            ("packages-as-dict", {"packages": {"name": "Petrel", "kind": "core"}}),
            ("entries-as-strings", {"packages": ["Petrel", "PetrelBluemoji"]}),
            ("manifest-null", {"packages": [{"name": "Petrel", "kind": "core", "manifest": None}]}),
            ("top-level-list", [{"name": "Petrel", "kind": "core"}]),
            ("no-core-entry", {"packages": [{"name": "X", "kind": "overlay", "manifest": "x.json"}]}),
        )
        for label, graph_content in malformed_graphs:
            with self.subTest(graph=label):
                output = self.root / f"malformed-{label}-output"
                manifest = self._write_manifest(
                    f"malformed-{label}",
                    kind="overlay",
                    package_name="MalformedOverlay",
                    emit=self.moji_lexicons,
                    output=output,
                    reference=(self.core_lexicons,),
                )
                graph = self.root / f"graph-{label}.json"
                graph.write_text(json.dumps(graph_content), encoding="utf-8")

                # Must not raise; must degrade to redeclare (no inherited roots).
                asyncio.run(
                    run_manifest(str(manifest), language="swift", graph_path=str(graph))
                )
                overlay = self._client_source(output, "ATProtoClient+MalformedOverlay.swift")
                self.assertIn("public struct Blue: Sendable {", overlay)
                self.assertNotIn("public extension ATProtoClient.Blue {", overlay)

    def test_relative_graph_paths_resolve_against_cwd(self):
        # Production package-graph.json uses repo-root-relative manifest paths;
        # exercise the CWD-join branch, not just absolute test paths.
        core_manifest = self._write_manifest(
            "relcwd-core",
            kind="core",
            package_name="Petrel",
            emit=self.core_lexicons,
            output=self.root / "relcwd-core-output",
            core_namespace_roots=["blue"],
        )
        overlay_output = self.root / "relcwd-overlay-output"
        overlay_manifest = self._write_manifest(
            "relcwd-overlay",
            kind="overlay",
            package_name="RelCwdOverlay",
            emit=self.moji_lexicons,
            output=overlay_output,
            reference=(self.core_lexicons,),
        )
        graph = self.root / "relcwd-graph.json"
        graph.write_text(
            json.dumps({"packages": [
                # relative to CWD, which we set to self.root below
                {"name": "Petrel", "kind": "core", "manifest": "relcwd-core.json"},
            ]}),
            encoding="utf-8",
        )

        previous_cwd = os.getcwd()
        os.chdir(self.root)
        try:
            asyncio.run(
                run_manifest(str(overlay_manifest), language="swift", graph_path=str(graph))
            )
        finally:
            os.chdir(previous_cwd)
        overlay = self._client_source(overlay_output, "ATProtoClient+RelCwdOverlay.swift")
        self.assertIn("public extension ATProtoClient.Blue {", overlay)
        self.assertNotIn("public struct Blue: Sendable {", overlay)

    def test_roots_are_deduplicated_and_sorted_before_rendering(self):
        self.assertEqual(
            normalize_core_namespace_roots(["zeta", "blue", "zeta", "alpha"]),
            ("alpha", "blue", "zeta"),
        )
        output = self.root / "ordered-output"
        manifest = self._write_manifest(
            "ordered",
            kind="core",
            package_name="Petrel",
            emit=self.core_lexicons,
            output=output,
            core_namespace_roots=["zeta", "blue", "zeta", "alpha"],
        )

        self._run_manifest(manifest)
        generated = self._client_source(output, "ATProtoClient+Generated.swift")

        for root in ("Alpha", "Blue", "Zeta"):
            with self.subTest(root=root):
                self.assertEqual(generated.count(f"public struct {root}: Sendable"), 1)
                property_name = root[0].lower() + root[1:]
                self.assertEqual(
                    generated.count(f"public var {property_name}: {root}"),
                    1,
                )
        self.assertRegex(
            generated,
            r"(?s)public struct Alpha: Sendable.*"
            r"public struct Blue: Sendable.*"
            r"public struct Zeta: Sendable",
        )

    def test_manifest_rejects_invalid_core_namespace_roots_before_generation(self):
        invalid_values = (
            None,
            "blue",
            {"blue": True},
            [""],
            ["   "],
            [1],
            ["Blue"],
            ["blue", "Blue"],
            ["blue.moji"],
            ["blue-cat"],
            ["2blue"],
            ["class"],
            ["in"],
            ["networkService"],
            ["storage"],
            ["logout"],
            ["sendable"],
            ["type"],
        )

        for index, value in enumerate(invalid_values):
            with self.subTest(value=value):
                output = self.root / f"invalid-output-{index}"
                manifest = self._write_manifest(
                    f"invalid-{index}",
                    kind="core",
                    package_name="Petrel",
                    emit=self.core_lexicons,
                    output=output,
                    core_namespace_roots=value,
                )
                with self.assertRaisesRegex(
                    ValueError,
                    "package.core_namespace_roots",
                ):
                    self._run_manifest(manifest)
                self.assertFalse(output.exists())

    def test_dot_root_raises_focused_validation_error(self):
        with self.assertRaisesRegex(ValueError, "core_namespace_roots"):
            normalize_core_namespace_roots(["."])

    def test_checked_in_core_manifest_declares_blue_as_its_owned_root(self):
        manifest = json.loads(
            (GENERATOR_DIR / "manifests" / "petrel-core.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(manifest["package"]["core_namespace_roots"], ["blue"])


if __name__ == "__main__":
    unittest.main()
