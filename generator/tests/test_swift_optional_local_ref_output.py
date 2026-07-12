import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator


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
                                "receipt": {"type": "ref", "ref": "#sequencerReceipt"},
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
        self.assertIn("encodeIfPresent(receipt, forKey: .receipt)", generated)
        self.assertIn("case receipt", generated)

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
        generated = SwiftCodeGenerator(lexicon).convert()
        self.assertIn("references missing local definition", generated)


if __name__ == "__main__":
    unittest.main()
