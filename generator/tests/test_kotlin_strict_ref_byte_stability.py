import hashlib
import pathlib
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from swift_code_generator import SwiftCodeGenerator


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


class KotlinStrictRefByteStabilityTests(unittest.TestCase):
    def test_ordinary_shapes_remain_byte_identical_to_pre_strict_ref_output(self):
        expected = {
            "blue.catbird.test.ordinaryObject": (
                "c303c5861aca580e0b4cefe039d4baf61ff83e1987409018ef2d40e02dfbe555"
            ),
            "blue.catbird.test.ordinaryProcedure": (
                "e98d210867d277a196514a84b68645986a3b90208dbd92bb106b72d80f26397d"
            ),
            "blue.catbird.test.ordinaryRecord": (
                "fa2daf5fd2f4d3a0a2187cd14ea617cd607720468e0ae972338b91fd40810b06"
            ),
            "blue.catbird.test.ordinarySubscription": (
                "6d74e3328f5403ca07e6b105714a678783afc48349014cfd32442b8e9cf0d9e1"
            ),
        }
        for lexicon in ordinary_lexicons():
            with self.subTest(lexicon=lexicon["id"]):
                generated = KotlinCodeGenerator(lexicon).convert().encode()
                self.assertEqual(
                    hashlib.sha256(generated).hexdigest(), expected[lexicon["id"]]
                )

    def test_ordinary_swift_shapes_remain_byte_identical_to_pre_strict_ref_output(self):
        # Re-pinned for re-audit r-5 (all four): lenient objects keep a malformed optional
        # value in extraFields (malformedFields, keepingMalformed:, unlessSet:,
        # hasValue(forField:)); no other line changed.
        # Re-pinned (all four) for Swift/Kotlin wire parity with Rust (Petrel#108): every
        # non-record object with extraFields keeps a decoded nested `$type` in the private
        # wireTypeTag (decodeTypeTag / encodeTypeTag / addingTypeTag); no other line changed.
        expected = {
            "blue.catbird.test.ordinaryObject": (
                "7a0394093a26e34d4a14f62470fb95f736710783436ee278278d7d73195423b0"
            ),
            # Re-pinned by the sdk-green generator pass: typed XRPC errors on every endpoint,
            # undeclared-field round trip (extraFields) and the shared object template.
            # Re-pinned again when the output Content-Type check moved to
            # value(forHTTPHeaderField:) (case-insensitive); that line is the only change.
            "blue.catbird.test.ordinaryProcedure": (
                "2c7ca1d0c755a682f4c0f0d8b89264c6235de85cb0c76659fa629525ccc9018a"
            ),
            "blue.catbird.test.ordinaryRecord": (
                "fbdd23fb7fae0add2811df93558d1b5dce28ff59600712430b56fcf3bd2578e0"
            ),
            "blue.catbird.test.ordinarySubscription": (
                "7910aa0c4b9bd459be103a8b50c5aae35d1ae7149e5616093ce34f13256ace13"
            ),
        }
        for lexicon in ordinary_lexicons():
            with self.subTest(lexicon=lexicon["id"]):
                generated = SwiftCodeGenerator(lexicon).convert().encode()
                self.assertEqual(
                    hashlib.sha256(generated).hexdigest(), expected[lexicon["id"]]
                )


if __name__ == "__main__":
    unittest.main()
