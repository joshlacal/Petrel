import asyncio
import copy
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from main import run_manifest
from type_converter import CurationError, intent_entity_extraction, intent_facing_type


class AppIntentsGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = pathlib.Path(self.temporary_directory.name)
        self.lexicons = self.root / "lexicons"
        self.lexicons.mkdir()
        self.manifest_path = self.root / "manifest.json"
        self.output = self.root / "generated"
        self._write_lexicons()
        self.manifest = {
            "package": {"kind": "app-intents", "name": "FixtureIntents"},
            "lexicons": {"reference": ["lexicons"]},
            "swift": {"output": "generated"},
            "appIntents": {
                "availability": "iOS 18.0",
                "intents": [{
                    "id": "com.example.actor.search",
                    "kind": "query",
                    "structName": "SearchProfilesIntent",
                    "title": "Search Profiles",
                    "parameters": {"q": {"requestValue": True}},
                    "returns": {"entity": "ProfileEntity", "outputPath": "actors"},
                }],
                "entities": [{
                    "name": "ProfileEntity",
                    "source": [
                        "com.example.actor.defs#profile",
                        "com.example.actor.defs#basic",
                    ],
                    "identifier": "did",
                    "syncable": True,
                    "indexed": True,
                    "display": {"title": "handle", "image": "avatar"},
                    "properties": ["handle", "displayName", "avatar", "count"],
                    "customProperties": [{
                        "name": "summary", "swiftType": "String",
                        "title": "Summary", "expr": '"Profile"',
                    }],
                    "query": {
                        "kind": "string", "nsid": "com.example.actor.search",
                        "param": "q", "resultsPath": "actors",
                        "byIds": {
                            "nsid": "com.example.actor.getProfiles",
                            "param": "actors", "resultsPath": "profiles",
                            "localStore": "ProfileStore.shared",
                        },
                    },
                }],
            },
        }

    def _write_lexicons(self):
        profile = {
            "type": "object", "required": ["did", "handle", "count"],
            "properties": {
                "did": {"type": "string", "format": "did"},
                "handle": {"type": "string", "format": "handle"},
                "displayName": {"type": "string"},
                "avatar": {"type": "string", "format": "uri"},
                "count": {"type": "integer"},
            },
        }
        basic = copy.deepcopy(profile)
        basic["properties"].pop("displayName")
        schemas = {
            "com.example.actor.defs": {"profile": profile, "basic": basic},
            "com.example.actor.search": {"main": {
                "type": "query",
                "parameters": {"type": "params", "properties": {
                    "q": {"type": "string"},
                    "limit": {"type": "integer", "minimum": 1, "maximum": 25},
                    "sort": {"type": "string", "knownValues": ["default", "latest"]},
                }},
                "output": {"encoding": "application/json", "schema": {
                    "type": "object", "required": ["actors"], "properties": {
                        "actors": {"type": "array", "items": {
                            "type": "ref", "ref": "com.example.actor.defs#profile",
                        }},
                    },
                }},
            }},
            "com.example.actor.getProfiles": {"main": {
                "type": "query",
                "parameters": {"type": "params", "required": ["actors"], "properties": {
                    "actors": {"type": "array", "maxLength": 2, "items": {
                        "type": "string", "format": "at-identifier",
                    }},
                }},
                "output": {"encoding": "application/json", "schema": {
                    "type": "object", "required": ["profiles"], "properties": {
                        "profiles": {"type": "array", "items": {
                            "type": "ref", "ref": "com.example.actor.defs#profile",
                        }},
                    },
                }},
            }},
        }
        for nsid, defs in schemas.items():
            (self.lexicons / f"{nsid}.json").write_text(
                json.dumps({"lexicon": 1, "id": nsid, "defs": defs}), encoding="utf-8",
            )

    def _generate(self):
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        # A graph is accepted by the modern entrypoint, but App Intents does not
        # inherit the core/overlay namespace-generation configuration from it.
        asyncio.run(run_manifest(
            str(self.manifest_path), language="swift", graph_path="unused-graph.json",
        ))

    def _source(self, relative):
        return (self.output / relative).read_text(encoding="utf-8")

    def test_current_entrypoint_preserves_sources_cache_chunking_and_bridges(self):
        self._generate()
        entity = self._source("Entities/ProfileEntity.swift")
        intent = self._source("Intents/SearchProfilesIntent.swift")
        self.assertIn("init(from view: ComExampleActorDefs.Profile)", entity)
        self.assertIn("init(from view: ComExampleActorDefs.Basic)", entity)
        self.assertIn("displayName = nil", entity)
        self.assertIn("handle = view.handle.value", entity)
        self.assertIn("avatar = view.avatar?.url", entity)
        self.assertIn("var count: Int", entity)
        self.assertIn('summary = "Profile"', entity)
        self.assertIn("ProfileStore.shared.entities(for: identifiers)", entity)
        self.assertLess(entity.index("if cached.count"), entity.index("IntentClientProvider"))
        self.assertIn("by: 2", entity)
        self.assertIn("try ATIdentifier(string: $0)", entity)
        self.assertIn("limit.map { min(max($0, 1), 25) }", intent)
        self.assertIn("sort.map { $0.rawValue }", intent)
        self.assertIn("@available(anyAppleOS 27.0, *)", entity)
        self.assertNotIn("@available(iOS 27.0, *)", entity)

    def test_emitted_literals_escape_quotes_controls_and_interpolation(self):
        literal = 'Quoted "name"\r\n\t\x00\\(danger)\u2028'
        self.manifest["appIntents"]["intents"][0]["title"] = literal
        entity = self.manifest["appIntents"]["entities"][0]
        entity["properties"][0] = {"path": "handle", "title": literal}
        entity["customProperties"][0]["title"] = literal
        self._generate()
        expected = r'Quoted \"name\"\r\n\t\0\\(danger)\u{2028}'
        for relative in ("Entities/ProfileEntity.swift", "Intents/SearchProfilesIntent.swift"):
            source = self._source(relative)
            self.assertIn(expected, source)
            self.assertNotIn("\x00", source)
            self.assertNotIn("\u2028", source)

    def test_known_value_literals_and_reserved_cases_stay_valid_swift(self):
        path = self.lexicons / "com.example.actor.search.json"
        schema = json.loads(path.read_text())
        schema["defs"]["main"]["parameters"]["properties"]["sort"]["knownValues"] = [
            "default", 'say"hi', "back\\slash",
        ]
        path.write_text(json.dumps(schema), encoding="utf-8")
        self._generate()
        source = self._source("Enums/SearchProfilesIntentSortOption.swift")
        self.assertIn('case `default` = "default"', source)
        self.assertIn(r'= "say\"hi"', source)
        self.assertIn(r'= "back\\slash"', source)

    def test_unsupported_new_wrapper_shapes_fail_instead_of_emitting_string(self):
        for schema in (
            {"type": "string", "format": "space-ref"},
            {"type": "string", "enum": ["open", "closed"]},
        ):
            with self.subTest(schema=schema):
                with self.assertRaises(CurationError):
                    intent_facing_type(schema)
                self.assertIsNone(intent_entity_extraction(schema))

    def test_invalid_manifest_and_kotlin_mode_do_not_create_output(self):
        for mode in ("kotlin", "unknown-key", "unknown-parameter", "required-exclusion"):
            with self.subTest(mode=mode):
                manifest = copy.deepcopy(self.manifest)
                if mode == "unknown-key":
                    manifest["appIntents"]["intents"][0]["paramters"] = {}
                elif mode == "unknown-parameter":
                    manifest["appIntents"]["intents"][0]["excludeParameters"] = ["missing"]
                elif mode == "required-exclusion":
                    path = self.lexicons / "com.example.actor.search.json"
                    schema = json.loads(path.read_text())
                    schema["defs"]["main"]["parameters"]["required"] = ["q"]
                    path.write_text(json.dumps(schema), encoding="utf-8")
                    manifest["appIntents"]["intents"][0]["excludeParameters"] = ["q"]
                self.manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaises(ValueError):
                    asyncio.run(run_manifest(
                        str(self.manifest_path), language="kotlin" if mode == "kotlin" else "swift",
                    ))
                self.assertFalse(self.output.exists())

    def test_generation_is_identical_across_hash_seeds_and_invocation_directories(self):
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        first = None
        for seed, cwd in (("1", self.root), ("8675309", GENERATOR_DIR)):
            result = subprocess.run(
                [sys.executable, str(GENERATOR_DIR.parent / "run.py"),
                 "--manifest", str(self.manifest_path), "--language", "swift"],
                cwd=cwd, env={**os.environ, "PYTHONHASHSEED": seed},
                text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            files = {str(p.relative_to(self.output)): p.read_bytes()
                     for p in self.output.rglob("*.swift")}
            self.assertEqual(len(files), 3)
            if first is None:
                first = files
            else:
                self.assertEqual(files, first)


if __name__ == "__main__":
    unittest.main()
