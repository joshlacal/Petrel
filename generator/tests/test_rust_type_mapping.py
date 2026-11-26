import json
import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
FIXTURE_DIR = pathlib.Path(__file__).resolve().parent / "fixtures"
REPO_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

from base_code_generator import validate_lexicon_schema
from cycle_detector import CycleDetector
from rust_enum_generator import RustEnumGenerator
from rust_type_converter import (
    RustTypeConverter,
    compute_rust_boxed_fields,
    is_raw_bytes_schema,
    is_schemaless_json_body,
    resolve_rust_def_type_name,
    rust_field_ident,
    rust_module_path,
    sanitize_rust_ident,
)


class _DummyRustGenerator:
    def __init__(
        self,
        lexicon,
        cycle_detector=None,
        *,
        emit_ids=None,
        crate_path="crate",
        reference_crate="petrel_api",
        property_type_overrides=None,
    ):
        validate_lexicon_schema(lexicon)
        self.lexicon = lexicon
        self.lexicon_id = lexicon["id"]
        self.defs = lexicon["defs"]
        self.cycle_detector = cycle_detector
        self.type_converter = RustTypeConverter(
            self,
            emit_ids=emit_ids,
            crate_path=crate_path,
            reference_crate=reference_crate,
            property_type_overrides=property_type_overrides,
        )
        self.enum_generator = RustEnumGenerator(self)


class RustTypeMappingTests(unittest.TestCase):
    def test_all_integers_map_to_i64_without_heuristics(self):
        lexicon = {
            "lexicon": 1,
            "id": "com.example.counts",
            "defs": {
                "main": {
                    "type": "object",
                    "required": ["limit", "count", "seq", "timestamp"],
                    "properties": {
                        "limit": {"type": "integer", "minimum": 1, "maximum": 100},
                        "count": {"type": "integer"},
                        "seq": {"type": "integer"},
                        "timestamp": {"type": "integer"},
                    },
                }
            },
        }
        gen = _DummyRustGenerator(lexicon)
        req = lexicon["defs"]["main"]["required"]
        props = lexicon["defs"]["main"]["properties"]
        for name, schema in props.items():
            self.assertEqual(gen.type_converter.determine_type(name, schema, req, "Counts"), "i64")

    def test_all_string_formats_and_data_model_primitives(self):
        lexicon = {
            "lexicon": 1,
            "id": "com.example.formats",
            "defs": {
                "main": {
                    "type": "object",
                    "required": [
                        "did", "handle", "ident", "nsid", "atUri", "spaceRef",
                        "uri", "tid", "rkey", "dt", "lang", "cidStr",
                        "plain", "rawBytes", "cidLink", "blob", "unk", "bag",
                    ],
                    "properties": {
                        "did": {"type": "string", "format": "did"},
                        "handle": {"type": "string", "format": "handle"},
                        "ident": {"type": "string", "format": "at-identifier"},
                        "nsid": {"type": "string", "format": "nsid"},
                        "atUri": {"type": "string", "format": "at-uri"},
                        "spaceRef": {"type": "string", "format": "space-ref"},
                        "uri": {"type": "string", "format": "uri"},
                        "tid": {"type": "string", "format": "tid"},
                        "rkey": {"type": "string", "format": "record-key"},
                        "dt": {"type": "string", "format": "datetime"},
                        "lang": {"type": "string", "format": "language"},
                        "cidStr": {"type": "string", "format": "cid"},
                        "plain": {"type": "string"},
                        "rawBytes": {"type": "bytes"},
                        "cidLink": {"type": "cid-link"},
                        "blob": {"type": "blob"},
                        "unk": {"type": "unknown"},
                        "bag": {"type": "object"},
                    },
                }
            },
        }
        gen = _DummyRustGenerator(lexicon)
        req = lexicon["defs"]["main"]["required"]
        props = lexicon["defs"]["main"]["properties"]
        expected = {
            "did": "petrel_core::Did",
            "handle": "petrel_core::Handle",
            "ident": "petrel_core::AtIdentifier",
            "nsid": "petrel_core::Nsid",
            "atUri": "petrel_core::AtUri",
            "spaceRef": "petrel_core::SpaceRef",
            "uri": "petrel_core::Uri",
            "tid": "petrel_core::Tid",
            "rkey": "petrel_core::RecordKey",
            "dt": "petrel_core::Datetime",
            "lang": "petrel_core::Language",
            "cidStr": "petrel_core::CidString",
            "plain": "String",
            "rawBytes": "petrel_core::Bytes",
            "cidLink": "petrel_core::CidLink",
            "blob": "petrel_core::Blob",
            "unk": "petrel_core::Value",
            "bag": "std::collections::BTreeMap<String, petrel_core::Value>",
        }
        for name, rust_type in expected.items():
            with self.subTest(field=name):
                self.assertEqual(
                    gen.type_converter.determine_type(name, props[name], req, "Formats"),
                    rust_type,
                )

    def test_optional_nullable_and_tristate_fixture(self):
        lexicon = json.loads((FIXTURE_DIR / "required_nullable.json").read_text(encoding="utf-8"))
        gen = _DummyRustGenerator(lexicon)
        op_entry = lexicon["defs"]["opEntry"]
        req = op_entry["required"]
        nullable = op_entry["nullable"]
        props = op_entry["properties"]

        self.assertEqual(
            gen.type_converter.determine_type(
                "nullableScalar", props["nullableScalar"], req, "OpEntry", nullable_fields=nullable
            ),
            "Option<String>",
        )
        self.assertEqual(
            gen.type_converter.determine_type(
                "nullableCID", props["nullableCID"], req, "OpEntry", nullable_fields=nullable
            ),
            "Option<petrel_core::CidString>",
        )
        self.assertEqual(
            gen.type_converter.determine_type(
                "requiredCount", props["requiredCount"], req, "OpEntry", nullable_fields=nullable
            ),
            "i64",
        )
        self.assertEqual(
            gen.type_converter.determine_type(
                "optionalNote", props["optionalNote"], req, "OpEntry", nullable_fields=nullable
            ),
            "Option<String>",
        )

        # Optional + nullable -> tri-state Option<petrel_core::Nullable<T>>
        swap_lex = {
            "lexicon": 1,
            "id": "com.example.putRecord",
            "defs": {
                "main": {
                    "type": "object",
                    "required": ["repo"],
                    "nullable": ["swapRecord"],
                    "properties": {
                        "repo": {"type": "string", "format": "did"},
                        "swapRecord": {"type": "string", "format": "cid"},
                    },
                }
            },
        }
        swap_gen = _DummyRustGenerator(swap_lex)
        self.assertEqual(
            swap_gen.type_converter.determine_type(
                "swapRecord",
                swap_lex["defs"]["main"]["properties"]["swapRecord"],
                ["repo"],
                "PutRecord",
                nullable_fields=["swapRecord"],
            ),
            "Option<petrel_core::Nullable<petrel_core::CidString>>",
        )

    def test_unknown_and_number_types_raise_never_fallback(self):
        for bad_type in ("number", "float", "exoticFutureType"):
            lexicon = {
                "lexicon": 1,
                "id": "com.example.bad",
                "defs": {"main": {"type": "object", "properties": {"bad": {"type": bad_type}}}},
            }
            gen = _DummyRustGenerator(lexicon)
            with self.subTest(bad_type=bad_type):
                with self.assertRaisesRegex(ValueError, "not a Lexicon field type"):
                    gen.type_converter.determine_type(
                        "bad", lexicon["defs"]["main"]["properties"]["bad"], [], "Bad"
                    )

    def test_keyword_sanitization_and_field_collision_handling(self):
        self.assertEqual(sanitize_rust_ident("Self"), "Self_")
        self.assertEqual(sanitize_rust_ident("self"), "self_")
        self.assertEqual(sanitize_rust_ident("super"), "super_")
        self.assertEqual(sanitize_rust_ident("crate"), "crate_")
        self.assertEqual(sanitize_rust_ident("gen"), "r#gen")

        used = set()
        cases = [
            ("type", "r#type"),
            ("ref", "r#ref"),
            ("match", "r#match"),
            ("virtual", "r#virtual"),
            ("gen", "r#gen"),
            ("self", "self_"),
            ("Self", "self__"),
            ("super", "super_"),
            ("crate", "crate_"),
            ("createdAt", "created_at"),
            ("didDoc", "did_doc"),
            ("cid-link", "cid_link"),
            ("4ever", "_4ever"),
        ]
        for wire, expected in cases:
            with self.subTest(wire=wire):
                self.assertEqual(rust_field_ident(wire, used), expected)

        # Colliding wire names (`a-b` and `aB`) dedupe cleanly
        dedupe = set()
        self.assertEqual(rust_field_ident("a-b", dedupe), "a_b")
        self.assertEqual(rust_field_ident("aB", dedupe), "a_b_")

    def test_property_type_overrides_and_unused_error(self):
        lexicon = {
            "lexicon": 1,
            "id": "com.atproto.server.getSession",
            "defs": {
                "main": {
                    "type": "query",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {"didDoc": {"type": "unknown"}},
                        },
                    },
                }
            },
        }
        gen = _DummyRustGenerator(lexicon, property_type_overrides={"Output.didDoc": "petrel_core::DidDocument"})
        ty = gen.type_converter.determine_type(
            "didDoc", {"type": "unknown"}, [], "Output"
        )
        self.assertEqual(ty, "Option<petrel_core::DidDocument>")
        gen.type_converter.assert_all_overrides_used()

        bad_gen = _DummyRustGenerator(lexicon, property_type_overrides={"Output.missing": "Foo"})
        with self.assertRaisesRegex(ValueError, "match no generated property"):
            bad_gen.type_converter.assert_all_overrides_used()

    def test_recursive_scc_boxes_only_non_heap_cycles(self):
        detector = CycleDetector()
        # Self-recursive direct/Option ref -> MUST box
        self_rec = {
            "lexicon": 1,
            "id": "com.example.tree",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "parent": {"type": "ref", "ref": "#main"},
                        "children": {"type": "array", "items": {"type": "ref", "ref": "#main"}},
                    },
                }
            },
        }
        detector.add_type("com.example.tree", "main", self_rec["defs"]["main"])

        # Mutual recursion A <-> B -> MUST box one edge
        mutual = {
            "lexicon": 1,
            "id": "com.example.mutual",
            "defs": {
                "nodeA": {
                    "type": "object",
                    "required": ["b"],
                    "properties": {"b": {"type": "ref", "ref": "#nodeB"}},
                },
                "nodeB": {
                    "type": "object",
                    "properties": {"a": {"type": "ref", "ref": "#nodeA"}},
                },
            },
        }
        detector.add_type("com.example.mutual", "nodeA", mutual["defs"]["nodeA"])
        detector.add_type("com.example.mutual", "nodeB", mutual["defs"]["nodeB"])

        boxed = compute_rust_boxed_fields(detector.schemas_by_ref)
        self.assertIn(("com.example.tree", "parent"), boxed)
        # Vec<T> already breaks size recursion, so children is NOT boxed
        self.assertNotIn(("com.example.tree", "children"), boxed)
        # Optional field nodeB.a preferred over required nodeA.b
        self.assertIn(("com.example.mutual#nodeB", "a"), boxed)
        self.assertNotIn(("com.example.mutual#nodeA", "b"), boxed)

        gen = _DummyRustGenerator(self_rec, detector)
        self.assertEqual(
            gen.type_converter.determine_type(
                "parent", self_rec["defs"]["main"]["properties"]["parent"], [], "Tree", def_name="main"
            ),
            "Option<Box<Tree>>",
        )
        self.assertEqual(
            gen.type_converter.determine_type(
                "children", self_rec["defs"]["main"]["properties"]["children"], [], "Tree", def_name="main"
            ),
            "Option<Vec<Tree>>",
        )

    def test_known_collisions_external_and_record_def(self):
        external_lex = {
            "lexicon": 1,
            "id": "app.bsky.embed.external",
            "defs": {
                "main": {
                    "type": "object",
                    "required": ["external"],
                    "properties": {"external": {"type": "ref", "ref": "#external"}},
                },
                "external": {
                    "type": "object",
                    "required": ["uri"],
                    "properties": {"uri": {"type": "string", "format": "uri"}},
                },
            },
        }
        detector = CycleDetector()
        for dn, ds in external_lex["defs"].items():
            detector.add_type("app.bsky.embed.external", dn, ds)

        gen = _DummyRustGenerator(external_lex, detector)
        self.assertEqual(
            resolve_rust_def_type_name("app.bsky.embed.external", "main", lexicon_defs=external_lex["defs"]),
            "External",
        )
        self.assertEqual(
            resolve_rust_def_type_name("app.bsky.embed.external", "external", lexicon_defs=external_lex["defs"]),
            "ExternalDef",
        )
        self.assertEqual(gen.type_converter.convert_ref("#external"), "ExternalDef")
        self.assertEqual(gen.type_converter.convert_ref("#main"), "External")

        # Cross-lexicon reference to app.bsky.embed.external#external
        caller = {"lexicon": 1, "id": "app.bsky.feed.post", "defs": {"main": {"type": "object"}}}
        caller_gen = _DummyRustGenerator(caller, detector)
        self.assertEqual(
            caller_gen.type_converter.convert_ref("app.bsky.embed.external#external"),
            "crate::app::bsky::embed::external::ExternalDef",
        )

        # Defs named `record` in listRecords stay `Record`
        list_records = {
            "lexicon": 1,
            "id": "com.atproto.repo.listRecords",
            "defs": {
                "main": {"type": "query"},
                "record": {
                    "type": "object",
                    "required": ["uri"],
                    "properties": {"uri": {"type": "string", "format": "at-uri"}},
                },
            },
        }
        lr_gen = _DummyRustGenerator(list_records)
        self.assertEqual(lr_gen.type_converter.convert_ref("#record"), "Record")

    def test_emit_set_vs_reference_set_paths_and_mls_ds_native_fixes(self):
        detector = CycleDetector()
        strong_ref = {
            "lexicon": 1,
            "id": "com.atproto.repo.strongRef",
            "defs": {"main": {"type": "object", "properties": {"cid": {"type": "string", "format": "cid"}}}},
        }
        bytes_defs = {
            "lexicon": 1,
            "id": "blue.catbird.test.defs",
            "defs": {"artifactHash": {"type": "bytes"}},
        }
        space_lex = {
            "lexicon": 1,
            "id": "blue.catbird.circle",
            "defs": {"main": {"type": "space", "key": "tid", "collections": []}},
        }
        detector.add_type("com.atproto.repo.strongRef", "main", strong_ref["defs"]["main"])
        detector.add_type("blue.catbird.test.defs", "artifactHash", bytes_defs["defs"]["artifactHash"])
        detector.add_type("blue.catbird.circle", "main", space_lex["defs"]["main"])

        overlay_lex = {
            "lexicon": 1,
            "id": "blue.catbird.test.use",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "strong": {"type": "ref", "ref": "com.atproto.repo.strongRef"},
                        "hash": {"type": "ref", "ref": "blue.catbird.test.defs#artifactHash"},
                        "space": {"type": "ref", "ref": "blue.catbird.circle"},
                    },
                }
            },
        }
        gen = _DummyRustGenerator(
            overlay_lex,
            detector,
            emit_ids={"blue.catbird.test.use", "blue.catbird.test.defs", "blue.catbird.circle"},
            reference_crate="petrel_api",
        )
        self.assertEqual(
            gen.type_converter.convert_ref("com.atproto.repo.strongRef"),
            "petrel_api::com::atproto::repo::strong_ref::StrongRef",
        )
        # Named bytes ref is natively inlined to petrel_core::Bytes
        self.assertEqual(
            gen.type_converter.convert_ref("blue.catbird.test.defs#artifactHash"),
            "petrel_core::Bytes",
        )
        self.assertEqual(
            gen.type_converter.convert_ref("blue.catbird.circle"),
            "crate::blue::catbird::circle::Circle",
        )
        self.assertEqual(rust_module_path("com.atproto.repo.strongRef"), "com::atproto::repo::strong_ref")

        # Schemaless JSON output / raw bytes schema helpers (labyrinthRelay)
        self.assertTrue(is_schemaless_json_body({"encoding": "application/json"}))
        self.assertFalse(is_schemaless_json_body({"encoding": "application/json", "schema": {"type": "object"}}))
        self.assertTrue(is_raw_bytes_schema({"type": "bytes"}))

    def test_official_lexicon_invalid_vectors_are_rejected(self):
        vectors = REPO_ROOT / "Tests" / "PetrelLexiconTests" / "Vectors" / "lexicon" / "lexicon-invalid.json"
        if not vectors.exists():
            self.skipTest("lexicon-invalid.json not present in checkout")
        cases = json.loads(vectors.read_text(encoding="utf-8"))
        rejected = []
        for case in cases:
            try:
                validate_lexicon_schema(case["lexicon"])
            except Exception:
                rejected.append(case["name"])
        self.assertEqual(len(cases), 7)
        self.assertEqual(rejected, [c["name"] for c in cases])

    def test_prelude_type_names_are_disambiguated(self):
        self.assertEqual(
            resolve_rust_def_type_name("tools.ozone.setting.defs", "option"),
            "OptionDef",
        )
        self.assertEqual(
            resolve_rust_def_type_name(
                "tools.ozone.setting.defs",
                "option",
                lexicon_defs={"option": {"type": "object", "properties": {}}},
            ),
            "OptionDef",
        )


if __name__ == "__main__":
    unittest.main()
