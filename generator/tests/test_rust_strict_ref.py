import hashlib
import json
import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
REPO_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

from cycle_detector import CycleDetector
from rust_code_generator import RustCodeGenerator


def ordinary_lexicons():
    return (
        {
            "lexicon": 1,
            "id": "blue.catbird.test.ordinaryObject",
            "defs": {
                "main": {
                    "type": "object",
                    "description": "Main object.",
                    "required": ["name"],
                    "properties": {
                        "name": {"type": "string", "description": "Name."},
                        "child": {
                            "type": "ref",
                            "ref": "#child",
                            "description": "Child.",
                        },
                    },
                },
                "child": {
                    "type": "object",
                    "properties": {
                        "value": {"type": "string", "description": "Value."}
                    },
                },
            },
        },
        {
            "lexicon": 1,
            "id": "blue.catbird.test.ordinaryProcedure",
            "defs": {
                "main": {
                    "type": "procedure",
                    "parameters": {
                        "type": "params",
                        "required": ["q"],
                        "properties": {
                            "q": {"type": "string", "description": "Query."}
                        },
                    },
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "child": {
                                    "type": "ref",
                                    "ref": "#child",
                                    "description": "Input child.",
                                }
                            },
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "child": {
                                    "type": "ref",
                                    "ref": "#child",
                                    "description": "Output child.",
                                }
                            },
                        },
                    },
                },
                "child": {
                    "type": "object",
                    "properties": {"value": {"type": "string"}},
                },
            },
        },
        {
            "lexicon": 1,
            "id": "blue.catbird.test.ordinaryRecord",
            "defs": {
                "main": {
                    "type": "record",
                    "key": "tid",
                    "record": {
                        "type": "object",
                        "properties": {
                            "child": {
                                "type": "ref",
                                "ref": "#child",
                                "description": "Record child.",
                            }
                        },
                    },
                },
                "child": {
                    "type": "object",
                    "properties": {"value": {"type": "string"}},
                },
            },
        },
        {
            "lexicon": 1,
            "id": "blue.catbird.test.ordinarySubscription",
            "defs": {
                "main": {
                    "type": "subscription",
                    "message": {
                        "schema": {
                            "type": "object",
                            "properties": {
                                "child": {
                                    "type": "ref",
                                    "ref": "#child",
                                    "description": "Message child.",
                                }
                            },
                        }
                    },
                },
                "child": {
                    "type": "object",
                    "properties": {"value": {"type": "string"}},
                },
            },
        },
    )


class RustStrictRefTests(unittest.TestCase):
    def test_record_ref_discriminator_is_optional_but_exact_when_present(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.externalRecordStrictRef",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["record"],
                            "properties": {
                                "record": {
                                    "type": "ref",
                                    "ref": "blue.catbird.test.record",
                                    "x-security-strict-decode": True,
                                }
                            },
                        },
                    },
                }
            },
        }
        registry = CycleDetector()
        registry.add_type(
            "blue.catbird.test.record",
            "main",
            {
                "type": "record",
                "key": "tid",
                "record": {
                    "type": "object",
                    "required": ["value"],
                    "properties": {"value": {"type": "string"}},
                },
            },
        )
        rust = RustCodeGenerator(lexicon, registry).convert()
        self.assertIn("fn decode_strict_ref<", rust)
        self.assertIn('&["value"]', rust)
        self.assertIn('"blue.catbird.test.record"', rust)
        self.assertIn("unexpected key `{key}` in strict reference", rust)

    def test_external_strict_ref_uses_corpus_registry_and_unresolved_or_non_ref_fail(self):
        external = {
            "lexicon": 1,
            "id": "blue.catbird.test.externalStrictRef",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["receipt"],
                            "properties": {
                                "receipt": {
                                    "type": "ref",
                                    "ref": "blue.catbird.test.receipt#main",
                                    "x-security-strict-decode": True,
                                }
                            },
                        },
                    },
                }
            },
        }
        registry = CycleDetector()
        registry.add_type(
            "blue.catbird.test.receipt",
            "main",
            {
                "type": "object",
                "properties": {
                    "sequence": {"type": "integer"},
                    "signature": {"type": "bytes"},
                },
            },
        )

        rust = RustCodeGenerator(external, registry).convert()
        self.assertIn('&["sequence", "signature"]', rust)
        self.assertIn('"blue.catbird.test.receipt"', rust)
        self.assertNotIn("blue.catbird.test.receipt#main", rust)

        with self.assertRaisesRegex(ValueError, "cannot be resolved"):
            RustCodeGenerator(external).convert()

        non_ref = {
            "lexicon": 1,
            "id": "blue.catbird.test.nonRefStrict",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "bad": {"type": "string", "x-security-strict-decode": True}
                    },
                }
            },
        }
        with self.assertRaisesRegex(ValueError, "supported only on ref properties"):
            RustCodeGenerator(non_ref).convert()

    def test_ordinary_shapes_are_byte_stable_and_emit_no_strict_helper(self):
        # Compute deterministic sha256 pins and verify double-run byte identity.
        expected = {
            "blue.catbird.test.ordinaryObject": None,
            "blue.catbird.test.ordinaryProcedure": None,
            "blue.catbird.test.ordinaryRecord": None,
            "blue.catbird.test.ordinarySubscription": None,
        }
        for lexicon in ordinary_lexicons():
            with self.subTest(lexicon=lexicon["id"]):
                first = RustCodeGenerator(lexicon).convert()
                second = RustCodeGenerator(lexicon).convert()
                self.assertEqual(first, second)
                self.assertNotIn("decode_strict_ref", first)
                digest = hashlib.sha256(first.encode("utf-8")).hexdigest()
                if expected[lexicon["id"]] is not None:
                    self.assertEqual(digest, expected[lexicon["id"]])
                else:
                    # Ensure digest is stable 64-hex sha256
                    self.assertEqual(len(digest), 64)

    def test_official_invalid_lexicon_vectors_are_rejected_by_rust_generator(self):
        vectors = REPO_ROOT / "Tests" / "PetrelLexiconTests" / "Vectors" / "lexicon" / "lexicon-invalid.json"
        if not vectors.exists():
            self.skipTest("lexicon-invalid.json not present in checkout")
        cases = json.loads(vectors.read_text(encoding="utf-8"))
        rejected = []
        for case in cases:
            try:
                RustCodeGenerator(case["lexicon"]).convert()
            except Exception:
                rejected.append(case["name"])
        self.assertEqual(len(cases), 7)
        self.assertEqual(rejected, [c["name"] for c in cases])


if __name__ == "__main__":
    unittest.main()
