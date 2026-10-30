import asyncio
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import textwrap
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from swift_code_generator import SwiftCodeGenerator

from main import generate_swift_from_lexicons_recursive

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

BSKY_QUERY_LEXICON = {
    "lexicon": 1,
    "id": "app.bsky.feed.getPostThread",
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
                    "required": ["thread"],
                    "properties": {"thread": {"type": "string"}},
                },
            },
            "errors": [{"name": "NotFound"}],
        }
    },
}

APPLY_WRITES_LEXICON = {
    "lexicon": 1,
    "id": "com.example.repo.applyWrites",
    "defs": {
        "main": {
            "type": "procedure",
            "input": {
                "encoding": "application/json",
                "schema": {
                    "type": "object",
                    "required": ["request"],
                    "properties": {
                        "request": {"type": "ref", "ref": "#writeEnvelope"},
                    },
                },
            },
            "output": {
                "encoding": "application/json",
                "schema": {"type": "ref", "ref": "#result"},
            },
        },
        "writeEnvelope": {
            "type": "object",
            "required": ["writes"],
            "properties": {
                "writes": {
                    "type": "array",
                    "items": {
                        "type": "union",
                        "refs": ["#create", "#delete"],
                    },
                },
            },
        },
        "create": {
            "type": "object",
            "required": ["collection", "value"],
            "properties": {
                "collection": {"type": "string", "format": "nsid"},
                "rkey": {"type": "string", "format": "record-key"},
                "value": {"type": "unknown"},
            },
        },
        "delete": {
            "type": "object",
            "required": ["collection", "rkey"],
            "properties": {
                "collection": {"type": "string", "format": "nsid"},
                "rkey": {"type": "string", "format": "record-key"},
            },
        },
        "result": {
            "type": "object",
            "properties": {
                "cursor": {"type": "string", "format": "record-key"},
            },
        },
    },
}

DIRECT_INPUT_LEXICON = {
    "lexicon": 1,
    "id": "com.example.repo.createRecord",
    "defs": {
        "main": {
            "type": "procedure",
            "input": {
                "encoding": "application/json",
                "schema": {
                    "type": "object",
                    "required": ["collection", "value"],
                    "properties": {
                        "collection": {"type": "string", "format": "nsid"},
                        "rkey": {"type": "string", "format": "record-key"},
                        "value": {"type": "unknown"},
                    },
                },
            },
        },
    },
}


def generated_struct(source, name, next_name=None):
    start = source.index(f"public struct {name}:")
    if next_name is None:
        return source[start:]
    end = source.index(f"public struct {next_name}:", start)
    return source[start:end]


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

    def test_server_contracts_are_namespace_scoped(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = pathlib.Path(temp_dir)
            lexicons_dir = temp_path / "lexicons"
            output_dir = temp_path / "output"
            lexicons_dir.mkdir()
            output_dir.mkdir()

            (lexicons_dir / "com.atproto.space.getRecord.json").write_text(
                json.dumps(QUERY_LEXICON),
                encoding="utf-8",
            )
            (lexicons_dir / "app.bsky.feed.getPostThread.json").write_text(
                json.dumps(BSKY_QUERY_LEXICON),
                encoding="utf-8",
            )

            asyncio.run(
                generate_swift_from_lexicons_recursive(
                    str(lexicons_dir),
                    str(output_dir),
                    emit_server_contracts=["com.atproto.space", "com.atproto.simplespace"],
                )
            )

            space_file = output_dir / "Lexicons/Com/Atproto/ComAtprotoSpaceGetRecord.swift"
            bsky_file = output_dir / "Lexicons/App/Bsky/AppBskyFeedGetPostThread.swift"

            self.assertTrue(space_file.exists(), f"Expected {space_file} to exist")
            self.assertTrue(bsky_file.exists(), f"Expected {bsky_file} to exist")

            space_code = space_file.read_text(encoding="utf-8")
            bsky_code = bsky_file.read_text(encoding="utf-8")

            self.assertIn("public protocol ServerHandler", space_code)
            self.assertIn("public static let endpointDescriptor", space_code)

            self.assertNotIn("public protocol ServerHandler", bsky_code)
            self.assertNotIn("public static let endpointDescriptor", bsky_code)

    def test_server_contract_input_reachable_optional_field_is_presence_aware(self):
        generated = SwiftCodeGenerator(
            APPLY_WRITES_LEXICON,
            emit_server_contracts=True,
        ).convert()
        create = generated_struct(generated, "Create", "Delete")

        self.assertIn("if container.contains(.rkey) {", create)
        self.assertIn(
            "guard try !container.decodeNil(forKey: .rkey) else {",
            create,
        )
        self.assertIn(
            "self.rkey = try container.decode(RecordKey.self, forKey: .rkey)",
            create,
        )
        self.assertNotIn("decodeIfPresent(RecordKey.self, forKey: .rkey)", create)
        self.assertNotIn("LogManager.", create)
        self.assertNotIn(r"\(error)", create)

    def test_server_contract_output_only_optional_field_remains_permissive(self):
        generated = SwiftCodeGenerator(
            APPLY_WRITES_LEXICON,
            emit_server_contracts=True,
        ).convert()
        result = generated_struct(generated, "Result")

        self.assertIn(
            "self.cursor = try container.decodeIfPresent(RecordKey.self, forKey: .cursor)",
            result,
        )
        self.assertIn("degrading to nil", result)

    def test_server_contract_direct_optional_input_is_presence_aware(self):
        generated = SwiftCodeGenerator(
            DIRECT_INPUT_LEXICON,
            emit_server_contracts=True,
        ).convert()
        input_struct = generated_struct(generated, "Input")

        self.assertIn("if container.contains(.rkey) {", input_struct)
        self.assertIn(
            "guard try !container.decodeNil(forKey: .rkey) else {",
            input_struct,
        )
        self.assertIn(
            "self.rkey = try container.decode(RecordKey.self, forKey: .rkey)",
            input_struct,
        )
        self.assertNotIn("decodeIfPresent(RecordKey.self, forKey: .rkey)", input_struct)

    def test_server_contract_flag_false_preserves_ordinary_generation_bytes(self):
        ordinary = SwiftCodeGenerator(APPLY_WRITES_LEXICON).convert()
        explicit_false = SwiftCodeGenerator(
            APPLY_WRITES_LEXICON,
            emit_server_contracts=False,
        ).convert()

        self.assertEqual(ordinary, explicit_false)
        # Updated following G1 template hardening (F8 metadata stripping & F27 context escaping)
        self.assertEqual(
            hashlib.sha256(ordinary.encode("utf-8")).hexdigest(),
            "7139da5752c79fc9e21913eef3782b608129ca2596568f3eb041a7219dc09290",
        )

    def test_server_contract_flag_false_preserves_direct_input_bytes(self):
        ordinary = SwiftCodeGenerator(DIRECT_INPUT_LEXICON).convert()
        explicit_false = SwiftCodeGenerator(
            DIRECT_INPUT_LEXICON,
            emit_server_contracts=False,
        ).convert()

        self.assertEqual(ordinary, explicit_false)
        # Updated following G1 template hardening (F8 metadata stripping & F27 context escaping)
        self.assertEqual(
            hashlib.sha256(ordinary.encode("utf-8")).hexdigest(),
            "66e6f0b0c4294726a9fee4543bc7197826749c61827838d2fc859c7478cb3720",
        )

    def test_server_contract_presence_aware_decoders_compile_and_reject_malformed_values(self):
        nested_generated = SwiftCodeGenerator(
            APPLY_WRITES_LEXICON,
            emit_server_contracts=True,
        ).convert()
        create = generated_struct(nested_generated, "Create", "Delete")
        result_start = nested_generated.index("public struct Result:")
        result_end = nested_generated.index("public struct Input:", result_start)
        result = nested_generated[result_start:result_end]

        direct_generated = SwiftCodeGenerator(
            DIRECT_INPUT_LEXICON,
            emit_server_contracts=True,
        ).convert()
        direct_start = direct_generated.index("public struct Input:")
        direct_end = direct_generated.index(
            "public struct XRPCMethodDescriptor:",
            direct_start,
        )
        direct_input = direct_generated[direct_start:direct_end]

        source = textwrap.dedent(
            f"""
            import Foundation

            public protocol ATProtocolCodable: Codable {{}}
            public protocol ATProtocolValue: Codable, Equatable, Hashable {{
                func isEqual(to other: any ATProtocolValue) -> Bool
                func toCBORValue() throws -> Any
            }}
            public struct OrderedCBORMap {{
                public init() {{}}
                public func adding(key: String, value: Any) -> Self {{ self }}
            }}
            public enum LogManager {{
                public static func logWarning(_ message: String) {{}}
            }}
            public struct NSID: Codable, Equatable, Hashable {{
                public let value: String
                public init(from decoder: Decoder) throws {{
                    value = try decoder.singleValueContainer().decode(String.self)
                }}
                public func encode(to encoder: Encoder) throws {{
                    var container = encoder.singleValueContainer()
                    try container.encode(value)
                }}
                public func toCBORValue() throws -> Any {{ value }}
            }}
            public struct RecordKey: Codable, Equatable, Hashable {{
                public let value: String
                public init(from decoder: Decoder) throws {{
                    let decoded = try decoder.singleValueContainer().decode(String.self)
                    guard !decoded.isEmpty, !decoded.contains("/"), !decoded.contains(" ") else {{
                        throw DecodingError.dataCorrupted(
                            .init(
                                codingPath: decoder.codingPath,
                                debugDescription: "invalid record key"
                            )
                        )
                    }}
                    value = decoded
                }}
                public func encode(to encoder: Encoder) throws {{
                    var container = encoder.singleValueContainer()
                    try container.encode(value)
                }}
                public func toCBORValue() throws -> Any {{ value }}
            }}
            public struct ATProtocolValueContainer: ATProtocolValue {{
                public let value: String
                public init(from decoder: Decoder) throws {{
                    value = try decoder.singleValueContainer().decode(String.self)
                }}
                public func encode(to encoder: Encoder) throws {{
                    var container = encoder.singleValueContainer()
                    try container.encode(value)
                }}
                public func isEqual(to other: any ATProtocolValue) -> Bool {{
                    (other as? Self) == self
                }}
                public func toCBORValue() throws -> Any {{ value }}
            }}

            public struct NestedFixture {{
            {create}
            {result}
            }}

            public struct DirectFixture {{
            {direct_input}
            }}

            let decoder = JSONDecoder()
            let omitted = try! decoder.decode(
                NestedFixture.Create.self,
                from: Data(#"{{"collection":"com.example.test","value":"ok"}}"#.utf8)
            )
            precondition(omitted.rkey == nil)

            for malformed in [
                #"{{"collection":"com.example.test","rkey":null,"value":"ok"}}"#,
                #"{{"collection":"com.example.test","rkey":7,"value":"ok"}}"#,
                #"{{"collection":"com.example.test","rkey":"bad/key","value":"ok"}}"#,
            ] {{
                precondition(
                    (try? decoder.decode(
                        NestedFixture.Create.self,
                        from: Data(malformed.utf8)
                    )) == nil
                )
            }}

            let outputOnly = try! decoder.decode(
                NestedFixture.Result.self,
                from: Data(#"{{"cursor":"bad/key"}}"#.utf8)
            )
            precondition(outputOnly.cursor == nil)

            let directOmitted = try! decoder.decode(
                DirectFixture.Input.self,
                from: Data(#"{{"collection":"com.example.test","value":"ok"}}"#.utf8)
            )
            precondition(directOmitted.rkey == nil)
            for malformed in [
                #"{{"collection":"com.example.test","rkey":null,"value":"ok"}}"#,
                #"{{"collection":"com.example.test","rkey":7,"value":"ok"}}"#,
                #"{{"collection":"com.example.test","rkey":"bad/key","value":"ok"}}"#,
            ] {{
                precondition(
                    (try? decoder.decode(
                        DirectFixture.Input.self,
                        from: Data(malformed.utf8)
                    )) == nil
                )
            }}
            """
        )

        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "StrictServerInput.swift"
            executable_path = pathlib.Path(directory) / "StrictServerInput"
            source_path.write_text(source)
            compile_result = subprocess.run(
                [
                    "xcrun",
                    "--toolchain",
                    "XcodeDefault",
                    "swiftc",
                    str(source_path),
                    "-o",
                    str(executable_path),
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run(
                [str(executable_path)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(run_result.returncode, 0, run_result.stderr)


if __name__ == "__main__":
    unittest.main()
