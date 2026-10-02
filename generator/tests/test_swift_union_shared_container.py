import pathlib
import subprocess
import sys
import tempfile
import textwrap
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from cycle_detector import CycleDetector
from swift_code_generator import SwiftCodeGenerator
from tests.swift_runtime_stubs import LEXICON_DECODING_STUBS


def union_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.unionShare",
        "defs": {
            "main": {
                "type": "record",
                "key": "tid",
                "record": {
                    "type": "object",
                    "required": ["embed", "items"],
                    "properties": {
                        "embed": {
                            "type": "union",
                            "refs": ["#alpha", "#beta", "blue.catbird.test.external#gamma", "blue.catbird.test.unknownNsid#nope"],
                        },
                        "items": {
                            "type": "array",
                            "items": {"type": "union", "refs": ["#alpha", "#empty"]},
                        },
                        "tags": {"type": "array", "items": {"type": "string"}},
                        "counts": {"type": "array", "items": {"type": "integer"}},
                    },
                },
            },
            "alpha": {
                "type": "object",
                "required": ["text"],
                "properties": {"text": {"type": "string"}, "labels": {"type": "array", "items": {"type": "string"}}},
            },
            "beta": {"type": "object", "properties": {"n": {"type": "integer"}}},
            "empty": {"type": "object", "properties": {}},
        },
    }


def registry():
    detector = CycleDetector()
    detector.add_type(
        "blue.catbird.test.external",
        "gamma",
        {"type": "object", "properties": {"x": {"type": "string"}}},
    )
    return detector


class UnionSharedContainerTests(unittest.TestCase):
    def test_object_variants_share_the_union_keyed_container(self):
        generated = SwiftCodeGenerator(union_lexicon(), registry()).convert()

        self.assertIn("let container = try decoder.container(keyedBy: LexiconCodingKey.self)", generated)
        self.assertIn('let typeValue = try container.decode(String.self, forKey: "$type")', generated)
        # Local and registered external object refs reuse the container.
        self.assertIn("let value = try BlueCatbirdTestUnionShare.Alpha(_lexiconContainer: container)", generated)
        self.assertIn("let value = try BlueCatbirdTestUnionShare.Beta(_lexiconContainer: container)", generated)
        self.assertIn("let value = try BlueCatbirdTestExternal.Gamma(_lexiconContainer: container)", generated)
        # An unresolvable ref keeps the plain Decodable entry point.
        self.assertIn("let value = try BlueCatbirdTestUnknownNsid.Nope(from: decoder)", generated)
        # Unknown $type still decodes the whole object dynamically from the decoder.
        self.assertIn("let unknownValue = try ATProtocolValueContainer(from: decoder)", generated)

    def test_struct_decoders_expose_container_entry_and_keep_init_from_decoder(self):
        generated = SwiftCodeGenerator(union_lexicon(), registry()).convert()

        self.assertIn(
            "self = try .init(_lexiconContainer: decoder.container(keyedBy: LexiconCodingKey.self))",
            generated,
        )
        # SwiftFormat's enumNamespaces rule keeps a namespace `struct` from becoming an `enum`
        # when any nested type contains `self.init(` or `Self(`. Delegating that way would flip
        # public namespaces such as AppBskyFeedDefs from enum to struct, so the wrapper assigns.
        self.assertNotIn("self.init(", generated)
        self.assertNotIn("Self(", generated)
        self.assertIn(
            "public init(_lexiconContainer container: KeyedDecodingContainer<LexiconCodingKey>) throws {",
            generated,
        )
        # Encoding keeps the per-type CodingKeys enum.
        self.assertIn("var container = encoder.container(keyedBy: CodingKeys.self)", generated)

    def test_primitive_arrays_use_concrete_element_decoders(self):
        generated = SwiftCodeGenerator(union_lexicon(), registry()).convert()
        normalized = {line.strip() for line in generated.splitlines()}

        self.assertIn(
            'self.tags = try container.decodeIfPresent(_LexiconStringArray.self, forKey: "tags")?.values',
            normalized,
        )
        self.assertIn(
            'self.counts = try container.decodeIfPresent(_LexiconIntArray.self, forKey: "counts")?.values',
            normalized,
        )
        self.assertNotIn("[String].self", generated)
        self.assertNotIn("[Int].self", generated)

    def test_shared_container_union_runtime_contract(self):
        generated = SwiftCodeGenerator(union_lexicon(), registry()).convert()
        declarations = generated.split("extension ATProtoClient", 1)[0]
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
                public init(minimumCapacity: Int) {{}}
                public mutating func append(key: String, value: Any) {{}}
                public static func unionVariant(typeIdentifier: String, payload: Any) -> Self {{ Self() }}
                public var entries: [(String, Any)] {{ [] }}
                public func adding(key: String, value: Any) -> Self {{ self }}
            }}
            public enum LogManager {{
                public static func logError(_ message: String) {{}}
                public static func logWarning(_ message: String) {{}}
                public static func logDebug(_ message: String) {{}}
            }}
{LEXICON_DECODING_STUBS}
            public struct ATProtocolValueContainer: ATProtocolValue, Sendable {{
                public init(from decoder: Decoder) throws {{ _ = try decoder.container(keyedBy: LexiconCodingKey.self) }}
                public func encode(to encoder: Encoder) throws {{}}
                public func isEqual(to other: any ATProtocolValue) -> Bool {{ false }}
                public func toCBORValue() throws -> Any {{ 0 }}
            }}
            public enum BlueCatbirdTestExternal {{
                public struct Gamma: ATProtocolCodable, ATProtocolValue, Sendable {{
                    public let x: String?
                    public init(from decoder: Decoder) throws {{
                        self = try .init(_lexiconContainer: decoder.container(keyedBy: LexiconCodingKey.self))
                    }}
                    public init(_lexiconContainer container: KeyedDecodingContainer<LexiconCodingKey>) throws {{
                        x = try container.decodeIfPresent(String.self, forKey: "x")
                    }}
                    public func encode(to encoder: Encoder) throws {{}}
                    public func isEqual(to other: any ATProtocolValue) -> Bool {{ false }}
                    public func toCBORValue() throws -> Any {{ 0 }}
                }}
            }}
            public enum BlueCatbirdTestUnknownNsid {{
                public struct Nope: ATProtocolCodable, ATProtocolValue, Sendable {{
                    public init(from decoder: Decoder) throws {{}}
                    public func encode(to encoder: Encoder) throws {{}}
                    public func isEqual(to other: any ATProtocolValue) -> Bool {{ false }}
                    public func toCBORValue() throws -> Any {{ 0 }}
                }}
            }}
            extension Array {{ public func toCBORValue() throws -> Any {{ self }} }}
            extension Int {{ public func toCBORValue() throws -> Any {{ self }} }}
            extension String {{ public func toCBORValue() throws -> Any {{ self }} }}

            {declarations}

            typealias Alpha = BlueCatbirdTestUnionShare.Alpha
            typealias EmbedUnion = BlueCatbirdTestUnionShare.BlueCatbirdTestUnionShareEmbedUnion
            let decoder = JSONDecoder()
            func describe(_ body: () throws -> Any) -> String {{
                do {{ return "ok \\(try body())" }} catch {{ return "\\(error)" }}
            }}
            let inputs = [
                #"{{"$type":"blue.catbird.test.unionShare#alpha","text":"hi","labels":["a","b"]}}"#,
                #"{{"$type":"blue.catbird.test.unionShare#alpha"}}"#,
                #"{{"$type":"blue.catbird.test.unionShare#alpha","text":5}}"#,
                #"{{"$type":"blue.catbird.test.unionShare#alpha","text":"hi","labels":["a",1]}}"#,
            ]
            for input in inputs {{
                let data = Data(input.utf8)
                let viaUnion = describe {{
                    guard case let .blueCatbirdTestUnionShareAlpha(value) = try decoder.decode(EmbedUnion.self, from: data) else {{
                        return "wrong case"
                    }}
                    return value
                }}
                let direct = describe {{ try decoder.decode(Alpha.self, from: data) }}
                precondition(viaUnion == direct, "\\(input): \\(viaUnion) != \\(direct)")
            }}
            let missingType = describe {{ try decoder.decode(EmbedUnion.self, from: Data(#"{{"text":"hi"}}"#.utf8)) }}
            precondition(missingType.contains(#"CodingKeys(stringValue: "$type", intValue: nil)"#), missingType)
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "UnionShare.swift"
            executable_path = pathlib.Path(directory) / "UnionShare"
            source_path.write_text(source)
            compile_result = subprocess.run(
                ["xcrun", "--toolchain", "XcodeDefault", "swiftc", str(source_path), "-o", str(executable_path)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run([str(executable_path)], capture_output=True, text=True)
            self.assertEqual(run_result.returncode, 0, run_result.stderr)


if __name__ == "__main__":
    unittest.main()
