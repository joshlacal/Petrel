import pathlib
import sys
import unittest
from unittest import mock

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator


STRING_FORMATS = [
    "datetime", "uri", "at-uri", "space-ref", "at-identifier", "cid",
    "did", "handle", "nsid", "tid", "record-key", "language",
]


def query_lexicon(properties):
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.query",
        "defs": {
            "main": {
                "type": "query",
                "parameters": {"type": "params", "properties": properties},
                "output": {
                    "encoding": "application/json",
                    "schema": {"type": "object", "properties": {}},
                },
            },
        },
    }


class SwiftQueryParameterEncodabilityTests(unittest.TestCase):
    """`Parametrizable.asQueryItems()` cannot send a leaf type without a query
    encoding, so the generator must refuse to emit one rather than ship an
    endpoint whose parameter never reaches the server."""

    def test_every_lexicon_parameter_kind_generates(self):
        properties = {
            "flag": {"type": "boolean"},
            "limit": {"type": "integer"},
            "cursor": {"type": "string"},
            "sort": {"type": "string", "enum": ["top", "latest"]},
            "sorts": {"type": "array", "items": {"type": "string", "enum": ["a", "b"]}},
            "counts": {"type": "array", "items": {"type": "integer"}},
        }
        for fmt in STRING_FORMATS:
            name = fmt.replace("-", "_")
            properties[name] = {"type": "string", "format": fmt}
            properties[name + "_list"] = {"type": "array", "items": {"type": "string", "format": fmt}}

        generated = SwiftCodeGenerator(query_lexicon(properties)).convert()

        self.assertIn("public let cid: CID?", generated)
        self.assertIn("public let datetime: ATProtocolDate?", generated)
        self.assertIn("public let space_ref_list: [SpaceRef]?", generated)

    def test_unknown_parameter_is_rejected(self):
        lexicon = query_lexicon({"filter": {"type": "unknown"}})

        with self.assertRaisesRegex(ValueError, r"blue\.catbird\.test\.query.*'filter'"):
            SwiftCodeGenerator(lexicon).convert()

    def test_format_whose_swift_type_has_no_query_encoding_is_rejected(self):
        # Reproduces the shape of the CID bug: a string format maps to a Swift type
        # that asQueryItems() has no encoding for.
        lexicon = query_lexicon({"cid": {"type": "string", "format": "cid"}})
        without_cid = {"String", "Int", "Bool"}

        with mock.patch("swift_code_generator.QUERY_ENCODABLE_SWIFT_TYPES", without_cid, create=True):
            with self.assertRaisesRegex(ValueError, r"'cid'.*CID"):
                SwiftCodeGenerator(lexicon).convert()


if __name__ == "__main__":
    unittest.main()
