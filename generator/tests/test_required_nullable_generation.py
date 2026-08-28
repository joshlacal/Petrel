import json
import pathlib
import subprocess
import sys
import tempfile
import textwrap
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
FIXTURE_DIR = pathlib.Path(__file__).resolve().parent / "fixtures"
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from swift_code_generator import SwiftCodeGenerator


def required_nullable_lexicon():
    return json.loads((FIXTURE_DIR / "required_nullable.json").read_text())


class RequiredNullableGenerationTests(unittest.TestCase):
    def test_swift_snapshot_distinguishes_required_nullable_from_optional(self):
        generated = SwiftCodeGenerator(required_nullable_lexicon()).convert()

        expected_lines = (
            "public let nullableScalar: String?",
            "public let nullableCID: CID?",
            "public let requiredCount: Int",
            "public let optionalNote: String?",
            "guard container.contains(.nullableScalar) else {",
            "guard container.contains(.nullableCID) else {",
            "self.nullableScalar = try container.decodeIfPresent(String.self, forKey: .nullableScalar)",
            "self.nullableCID = try container.decodeIfPresent(CID.self, forKey: .nullableCID)",
            "self.requiredCount = try container.decode(Int.self, forKey: .requiredCount)",
            "self.optionalNote = try container.decodeIfPresent(String.self, forKey: .optionalNote)",
            "try container.encode(nullableScalar, forKey: .nullableScalar)",
            "try container.encode(nullableCID, forKey: .nullableCID)",
            "try container.encode(requiredCount, forKey: .requiredCount)",
            "try container.encodeIfPresent(optionalNote, forKey: .optionalNote)",
            "nullableScalar: String?, nullableCID: CID?, requiredCount: Int, optionalNote: String? = nil",
        )
        normalized = {line.strip() for line in generated.splitlines()}
        for line in expected_lines:
            with self.subTest(line=line):
                self.assertIn(line, normalized)

        self.assertNotIn(
            "try container.encodeIfPresent(nullableScalar, forKey: .nullableScalar)",
            normalized,
        )
        self.assertNotIn(
            "try container.encodeIfPresent(nullableCID, forKey: .nullableCID)",
            normalized,
        )
        self.assertNotIn(
            "nullableScalar: String? = nil",
            generated,
        )
        self.assertNotIn(
            "nullableCID: CID? = nil",
            generated,
        )
    def test_kotlin_snapshot_distinguishes_required_nullable_from_optional(self):
        generated = KotlinCodeGenerator(required_nullable_lexicon()).convert()

        for fragment in (
            "val nullableScalar: String?",
            "val nullableCID: CID?",
            "val requiredCount: Int",
            "val optionalNote: String? = null",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, generated)

        self.assertNotIn("val nullableScalar: String? = null", generated)
        self.assertNotIn("val nullableCID: CID? = null", generated)

    def test_swift_required_nullable_json_runtime_contract(self):
        generated = SwiftCodeGenerator(required_nullable_lexicon()).convert()
        declarations = generated.split("extension ATProtoClient", 1)[0]
        source = textwrap.dedent(
            f"""
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
                public static func logError(_ message: String) {{}}
                public static func logWarning(_ message: String) {{}}
                public static func logDebug(_ message: String) {{}}
            }}
            public struct CID: Codable, Equatable, Hashable {{
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
            extension Array {{
                public func toCBORValue() throws -> Any {{ self }}
            }}
            extension Int {{
                public func toCBORValue() throws -> Any {{ self }}
            }}
            extension String {{
                public func toCBORValue() throws -> Any {{ self }}
            }}

            {declarations}

            typealias Entry = BlueCatbirdTestRequiredNullable.OpEntry
            let decoder = JSONDecoder()
            let nullData = Data(
                #"{{"nullableScalar":null,"nullableCID":null,"requiredCount":1}}"#.utf8
            )
            let decoded = try! decoder.decode(Entry.self, from: nullData)
            precondition(decoded.nullableScalar == nil)
            precondition(decoded.nullableCID == nil)
            precondition(decoded.requiredCount == 1)
            precondition(decoded.optionalNote == nil)

            let encoded = try! JSONEncoder().encode(decoded)
            let object = try! JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            precondition(object["nullableScalar"] is NSNull)
            precondition(object["nullableCID"] is NSNull)
            precondition(object["requiredCount"] as? Int == 1)
            precondition(object["optionalNote"] == nil)

            let missingNullableScalar = Data(
                #"{{"nullableCID":null,"requiredCount":1}}"#.utf8
            )
            do {{
                _ = try decoder.decode(Entry.self, from: missingNullableScalar)
                preconditionFailure("missing nullableScalar unexpectedly decoded")
            }} catch DecodingError.keyNotFound(let key, _) {{
                precondition(key.stringValue == "nullableScalar")
            }} catch {{
                preconditionFailure("unexpected nullableScalar error: \\(error)")
            }}

            let missingNullableCID = Data(
                #"{{"nullableScalar":null,"requiredCount":1}}"#.utf8
            )
            do {{
                _ = try decoder.decode(Entry.self, from: missingNullableCID)
                preconditionFailure("missing nullableCID unexpectedly decoded")
            }} catch DecodingError.keyNotFound(let key, _) {{
                precondition(key.stringValue == "nullableCID")
            }} catch {{
                preconditionFailure("unexpected nullableCID error: \\(error)")
            }}

            let missingNonNullable = Data(
                #"{{"nullableScalar":null,"nullableCID":null}}"#.utf8
            )
            precondition((try? decoder.decode(Entry.self, from: missingNonNullable)) == nil)

            let malformedNullable = Data(
                #"{{"nullableScalar":null,"nullableCID":7,"requiredCount":1}}"#.utf8
            )
            precondition((try? decoder.decode(Entry.self, from: malformedNullable)) == nil)

            let defaultConstructed = Entry(
                nullableScalar: "test",
                nullableCID: nil,
                requiredCount: 2
            )
            precondition(defaultConstructed.nullableScalar == "test")
            precondition(defaultConstructed.nullableCID == nil)
            precondition(defaultConstructed.requiredCount == 2)
            precondition(defaultConstructed.optionalNote == nil)

            let explicitConstructed = Entry(
                nullableScalar: "test",
                nullableCID: nil,
                requiredCount: 2,
                optionalNote: "custom"
            )
            precondition(explicitConstructed.optionalNote == "custom")
            """
        )

        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "RequiredNullable.swift"
            executable_path = pathlib.Path(directory) / "RequiredNullable"
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
                [str(executable_path)], capture_output=True, text=True
            )
            self.assertEqual(run_result.returncode, 0, run_result.stderr)


if __name__ == "__main__":
    unittest.main()
