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


def strict_ref_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.strictRefUnknownKeys",
        "defs": {
            "main": {
                "type": "procedure",
                "input": {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "required": ["requiredStrict"],
                        "properties": {
                            "requiredStrict": {
                                "type": "ref",
                                "ref": "#receipt",
                                "x-security-strict-decode": True,
                                "description": "Required strict receipt.",
                            },
                            "optionalStrict": {
                                "type": "ref",
                                "ref": "#receipt",
                                "x-security-strict-decode": True,
                                "description": "Optional strict receipt.",
                            },
                            "ordinary": {"type": "ref", "ref": "#receipt"},
                        },
                    },
                },
            },
            "receipt": {
                "type": "object",
                "required": ["sequence"],
                "properties": {
                    "sequence": {"type": "integer"},
                    "note": {"type": "string"},
                },
            },
            "envelope": {
                "type": "object",
                "required": ["requiredStrict"],
                "properties": {
                    "requiredStrict": {
                        "type": "ref",
                        "ref": "#receipt",
                        "x-security-strict-decode": True,
                    },
                    "ordinary": {"type": "ref", "ref": "#receipt"},
                },
            },
        },
    }


class StrictRefUnknownKeysTests(unittest.TestCase):
    def test_swift_strict_refs_reject_unknown_nested_keys_but_ordinary_ref_accepts(self):
        generated = SwiftCodeGenerator(strict_ref_lexicon()).convert()
        declarations = generated.split("extension ATProtoClient", 1)[0]
        source = textwrap.dedent(
            f"""
            public protocol ATProtocolCodable: Codable {{}}
            public protocol ATProtocolValue: Equatable, Hashable {{
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
            }}
            extension Int {{ public func toCBORValue() throws -> Any {{ self }} }}
            extension String {{ public func toCBORValue() throws -> Any {{ self }} }}

            {declarations}

            let decoder = JSONDecoder()
            let clean = Data(#"{{"requiredStrict":{{"sequence":1,"note":null}}}}"#.utf8)
            precondition(
                (try? decoder.decode(
                    BlueCatbirdTestStrictRefUnknownKeys.Input.self,
                    from: clean
                )) != nil
            )

            let requiredInjection = Data(
                #"{{"requiredStrict":{{"sequence":1,"extension":"attacker"}}}}"#.utf8
            )
            precondition(
                (try? decoder.decode(
                    BlueCatbirdTestStrictRefUnknownKeys.Input.self,
                    from: requiredInjection
                )) == nil
            )

            let optionalInjection = Data(
                #"{{"requiredStrict":{{"sequence":1}},"optionalStrict":{{"sequence":2,"extension":"attacker"}}}}"#.utf8
            )
            precondition(
                (try? decoder.decode(
                    BlueCatbirdTestStrictRefUnknownKeys.Input.self,
                    from: optionalInjection
                )) == nil
            )

            let ordinaryExtension = Data(
                #"{{"requiredStrict":{{"sequence":1}},"ordinary":{{"sequence":3,"extension":"compatible"}}}}"#.utf8
            )
            let decoded = try! decoder.decode(
                BlueCatbirdTestStrictRefUnknownKeys.Input.self,
                from: ordinaryExtension
            )
            precondition(decoded.ordinary?.sequence == 3)

            precondition(
                (try? decoder.decode(
                    BlueCatbirdTestStrictRefUnknownKeys.Envelope.self,
                    from: requiredInjection
                )) == nil
            )
            precondition(
                (try? decoder.decode(
                    BlueCatbirdTestStrictRefUnknownKeys.Envelope.self,
                    from: ordinaryExtension
                )) != nil
            )
            """
        )

        with tempfile.TemporaryDirectory() as directory:
            source_path = pathlib.Path(directory) / "StrictRef.swift"
            executable_path = pathlib.Path(directory) / "StrictRef"
            source_path.write_text(source)
            compile_result = subprocess.run(
                ["swiftc", str(source_path), "-o", str(executable_path)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run(
                [str(executable_path)], capture_output=True, text=True
            )
            self.assertEqual(run_result.returncode, 0, run_result.stderr)

    def test_kotlin_strict_refs_reject_unknown_nested_keys_with_production_json(self):
        generated = KotlinCodeGenerator(strict_ref_lexicon()).convert()
        declarations = generated.split("/**", 1)[0]
        fixture = textwrap.dedent(
            f'''
            package blue.catbird.petrel.generated

            import kotlinx.serialization.SerializationException
            import kotlinx.serialization.decodeFromString
            import kotlinx.serialization.json.Json
            import kotlin.test.Test
            import kotlin.test.assertEquals
            import kotlin.test.assertFailsWith

            class StrictRefGeneratedFixtureTest {{
                private val json = Json {{ ignoreUnknownKeys = true }}

                @Test
                fun strictRefsRejectUnknownNestedKeysAndOrdinaryRefAccepts() {{
                    val clean = json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysInput>(
                        """{{"requiredStrict":{{"sequence":1,"note":null}}}}"""
                    )
                    assertEquals(1, clean.requiredStrict.sequence)

                    assertFailsWith<SerializationException> {{
                        json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysInput>(
                            """{{"requiredStrict":{{"sequence":1,"extension":"attacker"}}}}"""
                        )
                    }}
                    assertFailsWith<SerializationException> {{
                        json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysInput>(
                            """{{"requiredStrict":{{"sequence":1}},"optionalStrict":{{"sequence":2,"extension":"attacker"}}}}"""
                        )
                    }}

                    val ordinary = json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysInput>(
                        """{{"requiredStrict":{{"sequence":1}},"ordinary":{{"sequence":3,"extension":"compatible"}}}}"""
                    )
                    assertEquals(3, ordinary.ordinary?.sequence)

                    assertFailsWith<SerializationException> {{
                        json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysEnvelope>(
                            """{{"requiredStrict":{{"sequence":1,"extension":"attacker"}}}}"""
                        )
                    }}
                    val envelope = json.decodeFromString<BlueCatbirdTestStrictRefUnknownKeysEnvelope>(
                        """{{"requiredStrict":{{"sequence":1}},"ordinary":{{"sequence":3,"extension":"compatible"}}}}"""
                    )
                    assertEquals(3, envelope.ordinary?.sequence)
                }}
            }}
            '''
        )

        with tempfile.TemporaryDirectory() as directory:
            fixture_dir = pathlib.Path(directory)
            (fixture_dir / "GeneratedStrictRef.kt").write_text(declarations)
            (fixture_dir / "StrictRefGeneratedFixtureTest.kt").write_text(fixture)
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
                    "--rerun-tasks",
                    "--tests",
                    "blue.catbird.petrel.generated.StrictRefGeneratedFixtureTest",
                ],
                cwd=GENERATOR_DIR.parent / "kotlin",
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
