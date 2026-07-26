import pathlib
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from swift_code_generator import SwiftCodeGenerator


SPACE_LEXICON = {
    "lexicon": 1,
    "id": "com.atproto.simplespace.space",
    "defs": {
        "main": {
            "type": "space",
            "key": "tid",
            "name": "Simple Space",
            "collections": ["app.bsky.feed.post", "app.bsky.graph.list"],
        }
    },
}

QUERY_LEXICON = {
    "lexicon": 1,
    "id": "com.atproto.space.getRecord",
    "defs": {
        "main": {
            "type": "query",
            "parameters": {
                "type": "params",
                "required": ["uri"],
                "properties": {"uri": {"type": "string"}},
            },
            "output": {
                "encoding": "application/json",
                "schema": {
                    "type": "object",
                    "required": ["value"],
                    "properties": {"value": {"type": "string"}},
                },
            },
            "errors": [{"name": "RecordNotFound"}],
        }
    },
}


class PermissionedDataGenerationTests(unittest.TestCase):
    def test_swift_space_primary_type_emits_descriptor(self):
        generated = SwiftCodeGenerator(SPACE_LEXICON).convert()
        self.assertIn("public struct SpaceDeclarationDescriptor", generated)
        self.assertIn('nsid: "com.atproto.simplespace.space"', generated)
        self.assertIn('collections: ["app.bsky.feed.post", "app.bsky.graph.list"]', generated)

    def test_kotlin_space_primary_type_emits_descriptor(self):
        generated = KotlinCodeGenerator(SPACE_LEXICON).convert()
        self.assertIn("data class SpaceDeclarationDescriptor", generated)
        self.assertIn('nsid = "com.atproto.simplespace.space"', generated)

    def test_server_contracts_are_opt_in_and_typed(self):
        ordinary = SwiftCodeGenerator(QUERY_LEXICON).convert()
        generated = SwiftCodeGenerator(QUERY_LEXICON, emit_server_contracts=True).convert()
        self.assertNotIn("protocol ServerHandler", ordinary)
        self.assertIn("public static let endpointDescriptor", generated)
        self.assertIn("public protocol ServerHandler", generated)
        self.assertIn("parameters: Parameters, input: Void", generated)
        self.assertIn("async throws -> Output", generated)


if __name__ == "__main__":
    unittest.main()
