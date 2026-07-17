import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator
from kotlin_code_generator import KotlinCodeGenerator


class SwiftOptionalLocalRefOutputTests(unittest.TestCase):
    def test_optional_local_ref_emits_definition_and_output_codec(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.receipt",
            "defs": {
                "main": {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["success"],
                            "properties": {
                                "success": {"type": "boolean"},
                                "receipt": {
                                    "type": "ref",
                                    "ref": "#sequencerReceipt",
                                    "x-security-strict-decode": True,
                                },
                            },
                        },
                    },
                },
                "sequencerReceipt": {
                    "type": "object",
                    "required": ["sequencerTerm"],
                    "properties": {"sequencerTerm": {"type": "integer"}},
                },
            },
        }

        generated = SwiftCodeGenerator(lexicon).convert()
        self.assertIn("public struct SequencerReceipt", generated)
        self.assertIn("public let receipt: SequencerReceipt?", generated)
        self.assertIn("decodeIfPresent(SequencerReceipt.self, forKey: .receipt)", generated)
        self.assertNotIn("property 'receipt' — degrading to nil", generated)
        self.assertIn("encodeIfPresent(receipt, forKey: .receipt)", generated)
        self.assertIn("case receipt", generated)

    def test_required_security_strict_ref_uses_required_decode(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.receipt",
            "defs": {
                "main": {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["receipt"],
                            "properties": {
                                "receipt": {
                                    "type": "ref",
                                    "ref": "#sequencerReceipt",
                                    "x-security-strict-decode": True,
                                }
                            },
                        },
                    },
                },
                "sequencerReceipt": {"type": "object", "properties": {}},
            },
        }

        generated = SwiftCodeGenerator(lexicon).convert()
        self.assertIn("public let receipt: SequencerReceipt", generated)
        self.assertIn("decode(SequencerReceipt.self, forKey: .receipt)", generated)
        self.assertNotIn("An error occurred during the Swift code generation", generated)

    def test_kotlin_kdoc_is_narrowed_to_security_strict_referenced_definition(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.receipt",
            "defs": {
                "main": {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "receipt": {
                                    "type": "ref",
                                    "ref": "#sequencerReceipt",
                                    "x-security-strict-decode": True,
                                }
                            },
                        },
                    },
                },
                "sequencerReceipt": {
                    "type": "object",
                    "properties": {
                        "epoch": {"type": "integer", "description": "Accepted epoch."}
                    },
                },
                "ordinary": {
                    "type": "object",
                    "properties": {
                        "label": {"type": "string", "description": "Ordinary label."}
                    },
                },
            },
        }

        generated = KotlinCodeGenerator(lexicon).convert()
        self.assertIn("/** Accepted epoch. */\n        @SerialName", generated)
        self.assertNotIn("        /** Ordinary label. */", generated)

    def test_missing_local_output_ref_fails_generation(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.receipt",
            "defs": {
                "main": {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "receipt": {"type": "ref", "ref": "#missing"}
                            },
                        },
                    },
                }
            },
        }
        with self.assertRaisesRegex(ValueError, "references missing local definition"):
            SwiftCodeGenerator(lexicon).convert()

    def test_null_and_malformed_output_schema_do_not_crash_generation(self):
        for schema in (None, "not-an-object"):
            lexicon = {
                "lexicon": 1,
                "id": "blue.catbird.test.empty",
                "defs": {
                    "main": {
                        "type": "procedure",
                        "output": {"encoding": "application/json", "schema": schema},
                    }
                },
            }
            generated = SwiftCodeGenerator(lexicon).convert()
            self.assertIn("public struct BlueCatbirdTestEmpty", generated)

    def test_malformed_output_property_is_ignored(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.empty",
            "defs": {
                "main": {
                    "type": "procedure",
                    "output": {
                        "encoding": "application/json",
                        "schema": {"type": "object", "properties": {"bad": None}},
                    },
                }
            },
        }
        generated = SwiftCodeGenerator(lexicon).convert()
        self.assertIn("public struct BlueCatbirdTestEmpty", generated)

    def test_missing_top_level_and_array_item_local_refs_fail_generation(self):
        schemas = (
            {"type": "ref", "ref": "#missing"},
            {
                "type": "object",
                "properties": {
                    "receipts": {
                        "type": "array",
                        "items": {"type": "ref", "ref": "#missing"},
                    }
                },
            },
        )
        for schema in schemas:
            lexicon = {
                "lexicon": 1,
                "id": "blue.catbird.test.receipt",
                "defs": {
                    "main": {
                        "type": "procedure",
                        "output": {"encoding": "application/json", "schema": schema},
                    }
                },
            }
            with self.assertRaisesRegex(ValueError, "references missing local definition"):
                SwiftCodeGenerator(lexicon).convert()


if __name__ == "__main__":
    unittest.main()
