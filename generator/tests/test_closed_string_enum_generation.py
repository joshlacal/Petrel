import json
import pathlib
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from swift_code_generator import SwiftCodeGenerator


CASES = ["prepare", "commit", "abort", "force-commit", "force_abort"]
ADVERSARIAL_CASES = [
    "a.b",
    "ab",
    "a-b",
    "a_b",
    "class",
    "1start",
    "雪",
    'say"hi',
    "path\\tail",
    "cash$money",
]


def procedure_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.mls.finalizeGroupChange",
        "defs": {
            "main": {
                "type": "procedure",
                "input": {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "required": ["action", "receipt"],
                        "properties": {
                            "action": {"type": "string", "enum": CASES},
                            "receipt": {
                                "type": "ref",
                                "ref": "#receipt",
                                "x-security-strict-decode": True,
                            },
                            "optionalStrict": {
                                "type": "ref",
                                "ref": "#receipt",
                                "x-security-strict-decode": True,
                            },
                            "optionalOrdinary": {"type": "ref", "ref": "#receipt"},
                        },
                    },
                },
            },
            "receipt": {
                "type": "object",
                "required": ["sequence"],
                "properties": {"sequence": {"type": "integer"}},
            },
        },
    }


def definitions_lexicon(enum_key="enum"):
    return {
        "lexicon": 1,
        "id": "blue.catbird.mls.defs",
        "defs": {
            "mode": {"type": "string", enum_key: CASES},
            "envelope": {
                "type": "object",
                "required": ["mode", "inlineMode"],
                "properties": {
                    "mode": {"type": "ref", "ref": "#mode"},
                    "inlineMode": {"type": "string", "enum": CASES},
                },
            },
        },
    }


def known_values_golden_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.golden.defs",
        "defs": {
            "mode": {
                "type": "string",
                "knownValues": ["alpha", "beta-value", "app.bsky.test#token"],
            }
        },
    }


def conflicting_context_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.mls.conflict",
        "defs": {
            "main": {
                "type": "procedure",
                "input": {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "required": ["action", "namedAction"],
                        "properties": {
                            "action": {"type": "string", "enum": ["inline-only"]},
                            "namedAction": {"type": "ref", "ref": "#inputAction"},
                        },
                    },
                },
            },
            "inputAction": {"type": "string", "enum": ["named-only"]},
        },
    }


def rendered_name_collision_lexicon():
    lexicon = conflicting_context_lexicon()
    lexicon["defs"]["input"] = {
        "type": "object",
        "required": ["action"],
        "properties": {"action": {"type": "string", "enum": ["other-context"]}},
    }
    return lexicon


def named_ref_procedure_lexicon(input_ref="#mode", output_ref="blue.catbird.test.named#mode"):
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.named",
        "defs": {
            "main": {
                "type": "procedure",
                "input": {
                    "encoding": "application/json",
                    "schema": {"type": "ref", "ref": input_ref},
                },
                "output": {
                    "encoding": "application/json",
                    "schema": {"type": "ref", "ref": output_ref},
                },
            },
            "mode": {"type": "string", "enum": ["on", "off"]},
            "envelope": {
                "type": "object",
                "required": ["local", "qualified"],
                "properties": {
                    "local": {"type": "ref", "ref": "#mode"},
                    "qualified": {
                        "type": "ref",
                        "ref": "blue.catbird.test.named#mode",
                    },
                },
            },
        },
    }


class ClosedStringEnumGenerationTests(unittest.TestCase):
    @staticmethod
    def _kotlin_literal(value):
        return json.dumps(value, ensure_ascii=True).replace("$", "\\$")

    def _run_kotlin_enum_fixture(self, enum_source, enum_name, wire_values):
        literals = ", ".join(self._kotlin_literal(value) for value in wire_values)
        fixture = textwrap.dedent(
            f"""
            package blue.catbird.petrel.generated.fixture

            import kotlinx.serialization.*
            import kotlinx.serialization.json.Json
            import kotlin.test.Test
            import kotlin.test.assertEquals
            import kotlin.test.assertFailsWith

            {enum_source}

            class ClosedEnumGeneratedFixtureTest {{
                @Test
                fun roundTripsKnownValuesAndRejectsUnknown() {{
                    val json = Json
                    for (wireValue in listOf({literals})) {{
                        val encodedWire = json.encodeToString(wireValue)
                        val decoded = json.decodeFromString<{enum_name}>(encodedWire)
                        assertEquals(encodedWire, json.encodeToString(decoded))
                    }}
                    assertFailsWith<SerializationException> {{
                        json.decodeFromString<{enum_name}>("\\\"unknown\\\"")
                    }}
                }}
            }}
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture_dir = pathlib.Path(directory)
            (fixture_dir / "ClosedEnumGeneratedFixtureTest.kt").write_text(fixture)
            init_script = fixture_dir / "fixture.init.gradle"
            init_script.write_text(
                """
                allprojects {
                    plugins.withId('org.jetbrains.kotlin.jvm') {
                        kotlin.sourceSets.test.kotlin.srcDir(System.getProperty('fixtureDir'))
                    }
                }
                """
            )
            result = subprocess.run(
                [
                    str(GENERATOR_DIR.parent / "kotlin" / "gradlew"),
                    "-I",
                    str(init_script),
                    f"-DfixtureDir={fixture_dir}",
                    "test",
                    "--tests",
                    "blue.catbird.petrel.generated.fixture.ClosedEnumGeneratedFixtureTest",
                ],
                cwd=GENERATOR_DIR.parent / "kotlin",
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def _run_kotlin_named_ref_fixture(self, generated):
        declarations = generated.split("/**", 1)[0]
        fixture = textwrap.dedent(
            """
            package blue.catbird.petrel.generated

            import kotlinx.serialization.encodeToString
            import kotlinx.serialization.json.Json
            import kotlin.test.Test
            import kotlin.test.assertEquals

            class NamedRefGeneratedFixtureTest {
                @Test
                fun namedRefsCompileAndRoundTrip() {
                    val envelope = BlueCatbirdTestNamedEnvelope(
                        local = BlueCatbirdTestNamedDefsMode.value_on,
                        qualified = BlueCatbirdTestNamedDefsMode.value_off,
                    )
                    val decodedEnvelope = Json.decodeFromString<BlueCatbirdTestNamedEnvelope>(
                        Json.encodeToString(envelope)
                    )
                    assertEquals(envelope, decodedEnvelope)

                    val input = BlueCatbirdTestNamedInput(BlueCatbirdTestNamedDefsMode.value_on)
                    assertEquals(input, Json.decodeFromString(Json.encodeToString(input)))

                    val output: BlueCatbirdTestNamedOutput = BlueCatbirdTestNamedDefsMode.value_off
                    assertEquals(output, Json.decodeFromString(Json.encodeToString(output)))
                }
            }
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture_dir = pathlib.Path(directory)
            (fixture_dir / "GeneratedNamedRef.kt").write_text(declarations)
            (fixture_dir / "NamedRefGeneratedFixtureTest.kt").write_text(fixture)
            init_script = fixture_dir / "fixture.init.gradle"
            init_script.write_text(
                """
                allprojects {
                    plugins.withId('org.jetbrains.kotlin.jvm') {
                        kotlin.sourceSets.test.kotlin.srcDir(System.getProperty('fixtureDir'))
                    }
                }
                """
            )
            result = subprocess.run(
                [
                    str(GENERATOR_DIR.parent / "kotlin" / "gradlew"),
                    "-I",
                    str(init_script),
                    f"-DfixtureDir={fixture_dir}",
                    "test",
                    "--tests",
                    "blue.catbird.petrel.generated.NamedRefGeneratedFixtureTest",
                ],
                cwd=GENERATOR_DIR.parent / "kotlin",
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def _run_swift_named_ref_fixture(self, generated):
        declarations = generated.split("extension ATProtoClient", 1)[0]
        source = textwrap.dedent(
            f"""
            public protocol ATProtocolCodable: Codable {{}}
            public protocol ATProtocolValue {{
                func isEqual(to other: any ATProtocolValue) -> Bool
                func toCBORValue() throws -> Any
            }}
            public struct OrderedCBORMap {{
                public init() {{}}
                public func adding(key: String, value: Any) -> Self {{ self }}
            }}
            public enum LogManager {{
                public static func logError(_ message: String) {{}}
            }}

            {declarations}

            let envelope = BlueCatbirdTestNamed.Envelope(
                local: .value_on,
                qualified: .value_off
            )
            let envelopeData = try! JSONEncoder().encode(envelope)
            let decodedEnvelope = try! JSONDecoder().decode(
                BlueCatbirdTestNamed.Envelope.self,
                from: envelopeData
            )
            precondition(decodedEnvelope == envelope)

            let input = BlueCatbirdTestNamed.Input(data: .value_on)
            let inputData = try! JSONEncoder().encode(input)
            precondition(
                try! JSONDecoder().decode(BlueCatbirdTestNamed.Input.self, from: inputData).data
                    == .value_on
            )

            let output: BlueCatbirdTestNamed.Output = .value_off
            precondition(output.rawValue == "off")
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "NamedRef.swift"
            executable_path = pathlib.Path(directory) / "NamedRef"
            source_path.write_text(source)
            compile_result = subprocess.run(
                [
                    "xcrun", "--toolchain", "XcodeDefault", "swiftc",
                    str(source_path), "-o", str(executable_path),
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run([str(executable_path)], capture_output=True, text=True)
            self.assertEqual(run_result.returncode, 0, run_result.stderr)

    def test_required_annotated_ref_is_strict_and_optional_controls_are_unchanged(self):
        generated = SwiftCodeGenerator(procedure_lexicon()).convert()

        self.assertNotIn("An error occurred during the Swift code generation", generated)
        self.assertIn("public let receipt: Receipt", generated)
        self.assertIn(
            "decodeStrictReference(Receipt.self, from: container, forKey: .receipt, "
            "allowedKeys: [\"sequence\"])",
            generated,
        )
        self.assertIn(
            "decodeStrictReference(Receipt.self, from: container, forKey: "
            ".optionalStrict, allowedKeys: [\"sequence\"])",
            generated,
        )
        self.assertNotIn("property 'optionalStrict' — degrading to nil", generated)
        self.assertIn("decodeIfPresent(Receipt.self, forKey: .optionalOrdinary)", generated)

    def test_inline_closed_enum_is_typed_in_swift_and_kotlin(self):
        swift = SwiftCodeGenerator(procedure_lexicon()).convert()
        kotlin = KotlinCodeGenerator(procedure_lexicon()).convert()

        self.assertIn("public let action: InputAction", swift)
        self.assertIn("public enum InputAction", swift)
        self.assertNotIn("public let action: String", swift)
        self.assertIn("val action: BlueCatbirdMlsFinalizeGroupChangeInputAction", kotlin)
        self.assertIn("enum class BlueCatbirdMlsFinalizeGroupChangeInputAction", kotlin)
        self.assertNotIn("val action: String", kotlin)

    def test_closed_enum_declares_exact_wire_cases_and_rejects_unknown(self):
        swift = SwiftCodeGenerator(procedure_lexicon()).convert()
        kotlin = KotlinCodeGenerator(procedure_lexicon()).convert()

        for value in CASES:
            self.assertEqual(swift.count(f'= "{value}"'), 1)
            self.assertEqual(kotlin.count(f'@SerialName("{value}")'), 1)
        self.assertIn("enum InputAction: String, Codable", swift)
        self.assertNotIn("init(rawValue: String)", swift)
        self.assertNotIn("case unexpected", swift)
        self.assertNotIn("Unexpected", kotlin)

    def test_swift_closed_enum_cbor_is_raw_wire_value(self):
        generated = SwiftCodeGenerator(procedure_lexicon()).convert()
        enum_start = generated.index("public enum InputAction")
        enum_end = generated.find("\npublic ", enum_start + 1)
        enum_source = generated[enum_start:enum_end if enum_end != -1 else None]
        self.assertIn("return rawValue", enum_source)

    def test_swift_closed_enum_round_trips_all_cases_and_rejects_unknown_at_runtime(self):
        generator = SwiftCodeGenerator(procedure_lexicon())
        generator.convert()
        source = textwrap.dedent(
            f"""
            import Foundation

            public protocol ATProtocolCodable: Codable {{}}
            public protocol ATProtocolValue {{
                func isEqual(to other: any ATProtocolValue) -> Bool
                func toCBORValue() throws -> Any
            }}

            {generator.enums}

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            for wireValue in {json.dumps(CASES)} {{
                let data = Data("\\\"\\(wireValue)\\\"".utf8)
                let decoded = try! decoder.decode(InputAction.self, from: data)
                precondition(String(data: try! encoder.encode(decoded), encoding: .utf8) == "\\\"\\(wireValue)\\\"")
                precondition((try! decoded.toCBORValue()) as? String == wireValue)
            }}
            let unknown = Data("\\\"unknown\\\"".utf8)
            precondition((try? decoder.decode(InputAction.self, from: unknown)) == nil)
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "ClosedEnum.swift"
            executable_path = pathlib.Path(directory) / "ClosedEnum"
            source_path.write_text(source)
            subprocess.run(
                [
                    "xcrun", "--toolchain", "XcodeDefault", "swiftc",
                    str(source_path), "-o", str(executable_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            result = subprocess.run([str(executable_path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_inline_enums_work_in_output_and_array_contexts(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.mls.contexts",
            "defs": {
                "main": {
                    "type": "query",
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["action", "history"],
                            "properties": {
                                "action": {"type": "string", "enum": CASES},
                                "history": {
                                    "type": "array",
                                    "items": {"type": "string", "enum": CASES},
                                },
                            },
                        },
                    },
                }
            },
        }
        swift = SwiftCodeGenerator(lexicon).convert()
        kotlin = KotlinCodeGenerator(lexicon).convert()

        self.assertIn("public let action: OutputAction", swift)
        self.assertIn("public let history: [OutputHistory]", swift)
        self.assertEqual(swift.count("public enum OutputAction"), 1)
        self.assertEqual(swift.count("public enum OutputHistory"), 1)
        self.assertIn("val action: BlueCatbirdMlsContextsOutputAction", kotlin)
        self.assertIn("val history: List<BlueCatbirdMlsContextsOutputHistory>", kotlin)
        self.assertEqual(kotlin.count("enum class BlueCatbirdMlsContextsOutputAction"), 1)
        self.assertEqual(kotlin.count("enum class BlueCatbirdMlsContextsOutputHistory"), 1)

    def test_named_and_inline_enums_are_context_qualified_and_emitted_once(self):
        swift = SwiftCodeGenerator(definitions_lexicon()).convert()
        kotlin = KotlinCodeGenerator(definitions_lexicon()).convert()

        self.assertEqual(swift.count("public enum DefsMode"), 1)
        self.assertEqual(swift.count("public enum EnvelopeInlineMode"), 1)
        self.assertIn("public let mode: DefsMode", swift)
        self.assertIn("public let inlineMode: EnvelopeInlineMode", swift)
        self.assertEqual(kotlin.count("enum class BlueCatbirdMlsDefsDefsMode"), 1)
        self.assertEqual(kotlin.count("enum class BlueCatbirdMlsDefsEnvelopeInlineMode"), 1)
        self.assertIn("val mode: BlueCatbirdMlsDefsDefsMode", kotlin)
        self.assertIn("val inlineMode: BlueCatbirdMlsDefsEnvelopeInlineMode", kotlin)

    def test_named_closed_enum_refs_compile_for_local_and_qualified_property_input_output_paths(self):
        ref_pairs = [
            ("#mode", "blue.catbird.test.named#mode"),
            ("blue.catbird.test.named#mode", "#mode"),
        ]
        for input_ref, output_ref in ref_pairs:
            with self.subTest(language="swift", input_ref=input_ref, output_ref=output_ref):
                generated = SwiftCodeGenerator(
                    named_ref_procedure_lexicon(input_ref, output_ref)
                ).convert()
                self.assertIn("public let local: DefsMode", generated)
                self.assertIn("public let qualified: DefsMode", generated)
                self.assertIn("public let data: DefsMode", generated)
                self.assertIn("public typealias Output = DefsMode", generated)
                self._run_swift_named_ref_fixture(generated)

            with self.subTest(language="kotlin", input_ref=input_ref, output_ref=output_ref):
                generated = KotlinCodeGenerator(
                    named_ref_procedure_lexicon(input_ref, output_ref)
                ).convert()
                enum_name = "BlueCatbirdTestNamedDefsMode"
                self.assertIn(f"val local: {enum_name}", generated)
                self.assertIn(f"val qualified: {enum_name}", generated)
                self.assertIn(f"val `data`: {enum_name}", generated)
                self.assertIn(f"typealias BlueCatbirdTestNamedOutput = {enum_name}", generated)
                self._run_kotlin_named_ref_fixture(generated)

    def test_procedure_revisit_uses_one_enum_definition_and_same_signature_type(self):
        generated = SwiftCodeGenerator(procedure_lexicon()).convert()
        self.assertEqual(generated.count("public enum InputAction"), 1)
        self.assertIn("action: InputAction", generated)
        self.assertNotRegex(generated, r"action: (?!InputAction)[A-Za-z]+Action")

    def test_known_values_output_is_byte_identical_to_existing_path(self):
        fixtures = pathlib.Path(__file__).parent / "fixtures"
        swift = SwiftCodeGenerator(known_values_golden_lexicon()).convert()
        kotlin = KotlinCodeGenerator(known_values_golden_lexicon()).convert()

        self.assertEqual(swift, (fixtures / "known_values_base.swift.golden").read_text())
        self.assertEqual(kotlin, (fixtures / "known_values_base.kt.golden").read_text())

    def test_inline_and_named_conflicting_vocabularies_have_distinct_types_and_refs(self):
        swift = SwiftCodeGenerator(conflicting_context_lexicon()).convert()
        kotlin = KotlinCodeGenerator(conflicting_context_lexicon()).convert()

        self.assertIn("public let action: InputAction", swift)
        self.assertIn("public let namedAction: DefsInputAction", swift)
        self.assertEqual(swift.count("public enum InputAction"), 1)
        self.assertEqual(swift.count("public enum DefsInputAction"), 1)
        self.assertIn('= "inline-only"', swift)
        self.assertIn('= "named-only"', swift)

        prefix = "BlueCatbirdMlsConflict"
        self.assertIn(f"val action: {prefix}InputAction", kotlin)
        self.assertIn(f"val namedAction: {prefix}DefsInputAction", kotlin)
        self.assertEqual(kotlin.count(f"enum class {prefix}InputAction"), 1)
        self.assertEqual(kotlin.count(f"enum class {prefix}DefsInputAction"), 1)
        self.assertIn('@SerialName("inline-only")', kotlin)
        self.assertIn('@SerialName("named-only")', kotlin)

    def test_distinct_contexts_that_render_the_same_type_name_fail_explicitly(self):
        with self.assertRaisesRegex(ValueError, "closed enum type name collision"):
            SwiftCodeGenerator(rendered_name_collision_lexicon()).convert()
        with self.assertRaisesRegex(ValueError, "closed enum type name collision"):
            KotlinCodeGenerator(rendered_name_collision_lexicon()).convert()

    def test_duplicate_or_non_string_wire_values_fail_explicitly(self):
        for invalid_values in (["same", "same"], ["valid", 7]):
            lexicon = procedure_lexicon()
            lexicon["defs"]["main"]["input"]["schema"]["properties"]["action"]["enum"] = invalid_values
            with self.assertRaisesRegex(ValueError, "duplicate wire values|list of strings"):
                SwiftCodeGenerator(lexicon).convert()
            with self.assertRaisesRegex(ValueError, "duplicate wire values|list of strings"):
                KotlinCodeGenerator(lexicon).convert()

    def test_adversarial_cases_are_injective_escaped_and_compile_in_both_languages(self):
        lexicon = procedure_lexicon()
        lexicon["defs"]["main"]["input"]["schema"]["properties"]["action"]["enum"] = ADVERSARIAL_CASES

        swift_generator = SwiftCodeGenerator(lexicon)
        swift_generator.convert()
        swift_source = textwrap.dedent(
            f"""
            import Foundation
            public protocol ATProtocolCodable: Codable {{}}
            public protocol ATProtocolValue {{
                func isEqual(to other: any ATProtocolValue) -> Bool
                func toCBORValue() throws -> Any
            }}
            {swift_generator.enums}
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            for encodedWire in {json.dumps([json.dumps(value, ensure_ascii=False) for value in ADVERSARIAL_CASES], ensure_ascii=False)} {{
                let data = Data(encodedWire.utf8)
                let decoded = try! decoder.decode(InputAction.self, from: data)
                precondition(try! encoder.encode(decoded) == data)
            }}
            precondition((try? decoder.decode(InputAction.self, from: Data("\\\"unknown\\\"".utf8))) == nil)
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "AdversarialClosedEnum.swift"
            executable_path = pathlib.Path(directory) / "AdversarialClosedEnum"
            source_path.write_text(swift_source)
            compile_result = subprocess.run(
                [
                    "xcrun", "--toolchain", "XcodeDefault", "swiftc",
                    str(source_path), "-o", str(executable_path),
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run([str(executable_path)], capture_output=True, text=True)
            self.assertEqual(run_result.returncode, 0, run_result.stderr)

        kotlin_generator = KotlinCodeGenerator(lexicon)
        kotlin_generator.convert()
        enum_name = "BlueCatbirdMlsFinalizeGroupChangeInputAction"
        self._run_kotlin_enum_fixture(kotlin_generator.enum_classes, enum_name, ADVERSARIAL_CASES)

    def test_invalid_strict_annotation_propagates_in_both_generators(self):
        lexicon = procedure_lexicon()
        annotation = lexicon["defs"]["main"]["input"]["schema"]["properties"]["action"]
        annotation["x-security-strict-decode"] = True

        with self.assertRaisesRegex(ValueError, "only on ref properties"):
            SwiftCodeGenerator(lexicon).convert()
        with self.assertRaisesRegex(ValueError, "only on ref properties"):
            KotlinCodeGenerator(lexicon).convert()


if __name__ == "__main__":
    unittest.main()
