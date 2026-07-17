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
        expected = {
            "blue.catbird.test.ordinaryObject": (
                "ab7c83e886a644225cc4977c48e510734b1410ea879eed82369249eb82f442b5"
            ),
            "blue.catbird.test.ordinaryProcedure": (
                "0053edeca872ba324926fcc54a88d9d69e089ca0dbcae78411ed5f694606eb76"
            ),
            "blue.catbird.test.ordinaryRecord": (
                "525e1e4c87bab213f0c812b76c42de5d8a32a439d1327ca7eb1cb7335bc45657"
            ),
            "blue.catbird.test.ordinarySubscription": (
                "585974cdccc8726ba2b75fa60b015893bd6d4fda9b7c27a416a9b91d277f6f5c"
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
