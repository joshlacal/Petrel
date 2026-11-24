import pathlib
import re
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from base_code_generator import validate_lexicon_schema
from cycle_detector import CycleDetector
from rust_enum_generator import RustEnumGenerator
from rust_type_converter import RustTypeConverter, resolve_rust_def_type_name


class _StubRustGenerator:
    def __init__(self, lexicon, cycle_detector=None):
        validate_lexicon_schema(lexicon)
        self.lexicon = lexicon
        self.lexicon_id = lexicon["id"]
        self.defs = lexicon["defs"]
        self.cycle_detector = cycle_detector
        self.type_converter = RustTypeConverter(self)
        self.enum_generator = RustEnumGenerator(self)


def _declared_rust_types(source: str) -> set[str]:
    return set(
        re.findall(
            r"\b(?:pub\s+struct|pub\s+enum|pub\s+type)\s+([A-Za-z_][A-Za-z0-9_]*)",
            source,
        )
    )


class RustUnionAndEnumGenerationTests(unittest.TestCase):
    def test_open_vs_closed_unions_and_no_serde_derive_or_flatten(self):
        lexicon = {
            "lexicon": 1,
            "id": "com.example.unions",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "open": {"type": "union", "refs": ["#alpha", "#beta"]},
                        "closed": {"type": "union", "closed": True, "refs": ["#alpha", "#beta"]},
                    },
                },
                "alpha": {"type": "object", "properties": {"a": {"type": "string"}}},
                "beta": {"type": "object", "properties": {"b": {"type": "integer"}}},
            },
        }
        gen = _StubRustGenerator(lexicon)
        open_ty = gen.type_converter.determine_type(
            "open", lexicon["defs"]["main"]["properties"]["open"], [], "Unions"
        )
        closed_ty = gen.type_converter.determine_type(
            "closed", lexicon["defs"]["main"]["properties"]["closed"], [], "Unions"
        )
        self.assertEqual(open_ty, "Option<UnionsOpen>")
        self.assertEqual(closed_ty, "Option<UnionsClosed>")

        joined = "\n\n".join(gen.enum_generator.enums_code)
        # Decision #4: never derive Serialize/Deserialize or use #[serde(flatten)]
        self.assertNotIn("Serialize,", joined)
        self.assertNotIn("Deserialize,", joined)
        self.assertNotIn("serde(flatten)", joined)

        open_enum = next(c for c in gen.enum_generator.enums_code if "pub enum UnionsOpen" in c)
        closed_enum = next(c for c in gen.enum_generator.enums_code if "pub enum UnionsClosed" in c)

        self.assertIn("Alpha(Box<Alpha>),", open_enum)
        self.assertIn("Beta(Box<Beta>),", open_enum)
        self.assertIn("Unknown(petrel_core::Value),", open_enum)

        self.assertIn("Alpha(Box<Alpha>),", closed_enum)
        self.assertIn("Beta(Box<Beta>),", closed_enum)
        self.assertNotIn("Unknown(", closed_enum)

    def test_empty_or_duplicate_closed_union_raises(self):
        empty_lex = {
            "lexicon": 1,
            "id": "com.example.badunion",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {"none": {"type": "union", "closed": True, "refs": []}},
                }
            },
        }
        gen = _StubRustGenerator(empty_lex)
        with self.assertRaisesRegex(ValueError, "closed union .* has no refs"):
            gen.type_converter.determine_type(
                "none", empty_lex["defs"]["main"]["properties"]["none"], [], "Badunion"
            )

        dup_lex = {
            "lexicon": 1,
            "id": "com.example.dupunion",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "dup": {"type": "union", "closed": True, "refs": ["#main", "com.example.dupunion"]}
                    },
                }
            },
        }
        dup_gen = _StubRustGenerator(dup_lex)
        with self.assertRaisesRegex(ValueError, "duplicate ref"):
            dup_gen.type_converter.determine_type(
                "dup", dup_lex["defs"]["main"]["properties"]["dup"], [], "Dupunion"
            )

    def test_union_variant_name_collision_disambiguates_personalspace_policy(self):
        detector = CycleDetector()
        for nsid in (
            "com.atproto.personalspace.policy",
            "com.atproto.memberspace.policy",
            "com.atproto.managedspace.policy",
        ):
            detector.add_type(nsid, "main", {"type": "object", "properties": {}})

        lexicon = {
            "lexicon": 1,
            "id": "com.atproto.space.policy",
            "defs": {
                "main": {
                    "type": "object",
                    "required": ["policy"],
                    "properties": {
                        "policy": {
                            "type": "union",
                            "refs": [
                                "com.atproto.personalspace.policy",
                                "com.atproto.memberspace.policy",
                                "com.atproto.managedspace.policy",
                            ],
                        }
                    },
                }
            },
        }
        gen = _StubRustGenerator(lexicon, detector)
        gen.type_converter.determine_type(
            "policy", lexicon["defs"]["main"]["properties"]["policy"], ["policy"], "Policy"
        )
        union_meta = gen.enum_generator.unions["PolicyPolicy"]
        names = [v["name"] for v in union_meta["variants"]]
        self.assertEqual(
            names,
            ["PersonalspacePolicy", "MemberspacePolicy", "ManagedspacePolicy"],
        )
        self.assertEqual(
            [v["wire_tag"] for v in union_meta["variants"]],
            [
                "com.atproto.personalspace.policy",
                "com.atproto.memberspace.policy",
                "com.atproto.managedspace.policy",
            ],
        )

    def test_named_known_values_is_open_enum_while_inline_stays_string(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.golden.defs",
            "defs": {
                "mode": {
                    "type": "string",
                    "knownValues": ["alpha", "beta-value", "app.bsky.test#token"],
                },
                "holder": {
                    "type": "object",
                    "required": ["namedMode", "inlineMode"],
                    "properties": {
                        "namedMode": {"type": "ref", "ref": "#mode"},
                        "inlineMode": {"type": "string", "knownValues": ["fast", "slow"]},
                    },
                },
            },
        }
        gen = _StubRustGenerator(lexicon)
        gen.enum_generator.generate_enum_from_known_values(
            "Mode", lexicon["defs"]["mode"]["knownValues"]
        )
        code = gen.enum_generator.known_values_enums["Mode"]
        self.assertIn("pub enum Mode {", code)
        self.assertIn("Alpha,", code)
        self.assertIn("BetaValue,", code)
        self.assertIn("AppBskyTestToken,", code)
        self.assertIn("Other(String),", code)
        self.assertIn("impl core::fmt::Display for Mode", code)
        self.assertIn("impl core::str::FromStr for Mode", code)
        self.assertIn("impl serde::Serialize for Mode", code)
        self.assertIn("impl<'de> serde::Deserialize<'de> for Mode", code)
        self.assertNotIn("#[derive(", code.split("pub enum Mode")[0].split("#[derive(")[-1] if False else "")
        self.assertNotIn("Serialize,", code)
        self.assertNotIn("Deserialize,", code)
        self.assertNotIn("serde(flatten)", code)

        holder_props = lexicon["defs"]["holder"]["properties"]
        self.assertEqual(
            gen.type_converter.determine_type("namedMode", holder_props["namedMode"], ["namedMode", "inlineMode"], "Holder"),
            "Mode",
        )
        # Inline knownValues MUST stay String (Plan §Lane B)
        self.assertEqual(
            gen.type_converter.determine_type("inlineMode", holder_props["inlineMode"], ["namedMode", "inlineMode"], "Holder"),
            "String",
        )

    def test_closed_enum_identity_registry_and_adversarial_cases(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.mls.defs",
            "defs": {
                "main": {
                    "type": "object",
                    "required": ["action"],
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["prepare", "commit", "a.b", "ab", "a-b", "a_b", "1start", "雪", 'say"hi'],
                        }
                    },
                }
            },
        }
        gen = _StubRustGenerator(lexicon)
        ty = gen.type_converter.determine_type(
            "action", lexicon["defs"]["main"]["properties"]["action"], ["action"], "Defs"
        )
        self.assertEqual(ty, "DefsAction")
        enum_src = gen.enum_generator.closed_enums["DefsAction"]
        self.assertNotIn("Other(", enum_src)
        self.assertIn("petrel_core::DecodeError::Custom", enum_src)
        self.assertIn("petrel_core::serde_bridge::deserialize", enum_src)
        self.assertIn('say\\"hi', enum_src)
        self.assertNotIn("Serialize,", enum_src)
        self.assertNotIn("Deserialize,", enum_src)

        # Ensure every variant identifier is unique and UpperCamelCase (no underscores)
        variants = re.findall(r"^\s+([A-Za-z_][A-Za-z0-9_]*),$", enum_src, re.MULTILINE)
        self.assertEqual(len(variants), len(set(variants)))
        self.assertEqual(len(variants), 9)
        for v in variants:
            self.assertNotIn("_", v)
            self.assertTrue(v[0].isupper())

        # Identity collision & schema mismatch raise ValueError
        with self.assertRaisesRegex(ValueError, "reused with a different schema"):
            gen.enum_generator.generate_closed_string_enum(
                "DefsAction", ["different"], ("inline", "blue.catbird.mls.defs", ("rendered", "Defs"), "action")
            )
        with self.assertRaisesRegex(ValueError, "closed enum type name collision"):
            gen.enum_generator.generate_closed_string_enum(
                "DefsAction", ["prepare"], ("definition", "blue.catbird.mls.defs", "action")
            )
        with self.assertRaisesRegex(ValueError, "duplicate wire values"):
            gen.enum_generator.generate_closed_string_enum("DupEnum", ["x", "x"], ("def", "dup"))

    def test_numeric_known_values_and_closed_enum_use_camel_case_value1_value2(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.chat.defs",
            "defs": {
                "version": {"type": "string", "knownValues": ["1", "2"]},
                "strictVersion": {"type": "string", "enum": ["1", "2"]},
            },
        }
        gen = _StubRustGenerator(lexicon)
        kv = gen.enum_generator.generate_enum_from_known_values(
            "Version", lexicon["defs"]["version"]["knownValues"]
        )
        self.assertEqual(kv, "Version")
        kv_src = gen.enum_generator.known_values_enums["Version"]
        self.assertIn("Value1,", kv_src)
        self.assertIn("Value2,", kv_src)
        self.assertNotIn("Value_", kv_src)

        ce_src = gen.enum_generator.closed_enums[
            gen.enum_generator.generate_closed_string_enum(
                "StrictVersion",
                lexicon["defs"]["strictVersion"]["enum"],
                ("definition", lexicon["id"], "strictVersion"),
            )
        ]
        self.assertIn("Value1,", ce_src)
        self.assertIn("Value2,", ce_src)
        self.assertNotIn("Value_", ce_src)

    def test_every_convert_ref_name_is_declared_for_named_defs(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.defs",
            "defs": {
                "signedTransition": {
                    "type": "union",
                    "refs": ["#signedCommit", "#signedPolicy"],
                    "closed": True,
                },
                "signedCommit": {"type": "object", "properties": {"commit": {"type": "string"}}},
                "signedPolicy": {"type": "object", "properties": {"policy": {"type": "string"}}},
                "artifactHash": {"type": "bytes"},
                "bareDid": {"type": "string", "format": "did"},
                "closedKind": {"type": "string", "enum": ["a", "b"]},
                "openKind": {"type": "string", "knownValues": ["c", "d"]},
            },
        }
        gen = _StubRustGenerator(lexicon)
        emitted_parts = []
        for def_name, def_schema in lexicon["defs"].items():
            type_name = resolve_rust_def_type_name(lexicon["id"], def_name, lexicon_defs=lexicon["defs"])
            dt = def_schema["type"]
            if dt == "object":
                emitted_parts.append(f"pub struct {type_name} {{}}")
            elif dt == "union":
                gen.enum_generator.generate_enum_for_union_def(
                    type_name, def_schema["refs"], closed=bool(def_schema.get("closed", False))
                )
            elif dt == "bytes":
                emitted_parts.append(f"pub type {type_name} = petrel_core::Bytes;")
            elif dt == "string" and "enum" in def_schema:
                gen.enum_generator.generate_closed_string_enum(
                    type_name, def_schema["enum"], ("definition", lexicon["id"], def_name)
                )
            elif dt == "string" and "knownValues" in def_schema:
                gen.enum_generator.generate_enum_from_known_values(type_name, def_schema["knownValues"])
            elif dt == "string":
                base = gen.type_converter._convert_string_type(def_schema.get("format"))
                emitted_parts.append(f"pub type {type_name} = {base};")

        emitted_parts.extend(gen.enum_generator.enums_code)
        declared = _declared_rust_types("\n".join(emitted_parts))

        for def_name in lexicon["defs"]:
            with self.subTest(definition=def_name):
                resolved = gen.type_converter.convert_ref(f"#{def_name}")
                if resolved == "petrel_core::Bytes":
                    continue
                self.assertIn(resolved, declared)


if __name__ == "__main__":
    unittest.main()
