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
        expected = {
            "blue.catbird.test.ordinaryObject": (
                "44c43e3dc58b6d5b1980d4f7a1ae09670ddbea922e3a9116b42f0a8cc03a7ef9"
            ),
            # Re-pinned by the sdk-green generator pass: typed XRPC errors on every endpoint,
            # undeclared-field round trip (extraFields) and the shared object template.
            # Re-pinned again when the output Content-Type check moved to
            # value(forHTTPHeaderField:) (case-insensitive); that line is the only change.
            "blue.catbird.test.ordinaryProcedure": (
                "3bbeee19de2026f67a82c2f2c3068f0a6951ab8a65d8c6e8b787cef39f004431"
            ),
            "blue.catbird.test.ordinaryRecord": (
                "538cb0bfa62f7f07c9d7478233ccde6c31c0d12ab4a6dfffe5ee65774f5fc2ee"
            ),
            "blue.catbird.test.ordinarySubscription": (
                "3c73629ea5b22d22e1a405e377e5c57e7341cd085d8bac60806fefe4126493eb"
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
