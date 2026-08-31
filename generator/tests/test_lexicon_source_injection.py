import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator
from kotlin_code_generator import KotlinCodeGenerator
from cycle_detector import CycleDetector
import templates
import kotlin_templates


class LexiconSourceInjectionTests(unittest.TestCase):
    def setUp(self):
        self.cycle_detector = CycleDetector()

    def test_reject_invalid_nsid_or_names(self):
        """Adversarial schemas with invalid NSIDs, def names, or properties must be rejected or sanitized."""
        invalid_nsids = [
            "com..atproto",
            "com/atproto/repo",
            "com.atproto.repo;rm -rf /",
            "com.atproto.repo\nobject Injection",
            "com.atproto.repo\\nested",
            "com.atproto.repo#def",
            "",
            "../../../etc/passwd",
        ]
        for bad_id in invalid_nsids:
            lexicon = {
                "lexicon": 1,
                "id": bad_id,
                "defs": {"main": {"type": "object", "properties": {"prop": {"type": "string"}}}},
            }
            with self.subTest(bad_id=bad_id):
                with self.assertRaises(ValueError):
                    SwiftCodeGenerator(lexicon, self.cycle_detector).convert()

    def test_reject_invalid_property_and_error_names(self):
        """Adversarial schemas with invalid property names or error names must be rejected."""
        invalid_names = [
            'prop"name',
            "prop\\name",
            "prop\nname",
            "prop;injection",
            "prop $(injection)",
            "prop ${injection}",
            "prop\\(injection)",
            "prop.subprop",
            "prop-hyphen-in-identifier",
            "",
        ]
        for bad_name in invalid_names:
            lexicon_prop = {
                "lexicon": 1,
                "id": "com.atproto.test.badprop",
                "defs": {
                    "main": {
                        "type": "object",
                        "properties": {bad_name: {"type": "string"}},
                    }
                },
            }
            with self.subTest(bad_prop=bad_name):
                with self.assertRaises(ValueError):
                    SwiftCodeGenerator(lexicon_prop, self.cycle_detector).convert()

            lexicon_error = {
                "lexicon": 1,
                "id": "com.atproto.test.baderror",
                "defs": {
                    "main": {
                        "type": "query",
                        "errors": [{"name": bad_name}],
                    }
                },
            }
            with self.subTest(bad_error=bad_name):
                with self.assertRaises(ValueError):
                    SwiftCodeGenerator(lexicon_error, self.cycle_detector).convert()

    def test_comment_and_string_literal_escaping_in_swift(self):
        """Adversarial description / error / doc comments containing */, newlines, quotes, or Swift string interpolation \\() must be escaped."""
        adversarial_description = "A comment with */ and // and \n newline and quote \" and interpolation \\(1+1)"
        lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.adversarial",
            "description": adversarial_description,
            "defs": {
                "main": {
                    "type": "query",
                    "description": adversarial_description,
                    "errors": [
                        {"name": "BadError", "description": adversarial_description}
                    ],
                }
            },
        }
        swift_code = SwiftCodeGenerator(lexicon, self.cycle_detector).convert()
        # Verify no unescaped */ closes a block comment prematurely or breaks doc comments
        self.assertNotIn("/*", swift_code)
        # Verify literal string in error does not break syntax or interpolate
        self.assertNotIn("\\(1+1)", swift_code)

    def test_comment_and_string_literal_escaping_in_kotlin(self):
        """Adversarial description / error in Kotlin containing */, newlines, quotes, or Kotlin string interpolation $ / ${} must be escaped."""
        adversarial_description = "A comment with */ and \n newline and quote \" and interpolation $foo and ${bar.baz()}"
        lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.adversarial",
            "description": adversarial_description,
            "defs": {
                "main": {
                    "type": "query",
                    "description": adversarial_description,
                    "errors": [
                        {"name": "BadError", "description": adversarial_description}
                    ],
                }
            },
        }
        kotlin_code = KotlinCodeGenerator(lexicon, self.cycle_detector).convert()
        # Kotlin comments or string literals shouldn't have raw unescaped interpolation or broken comment blocks
        # Any $ or ${ must be escaped as \$ or \${
        # Raw unescaped ${bar.baz()} or $foo must not appear without backslash escaping
        self.assertNotIn(" ${bar.baz()}", kotlin_code)
        self.assertNotIn(" $foo", kotlin_code)
        self.assertIn(r"\${bar.baz()}", kotlin_code)
        self.assertIn(r"\$foo", kotlin_code)
        # Verify no unescaped */ inside the /** */ comment block or // line comments
        comment_blocks = [line for line in kotlin_code.splitlines() if line.startswith(" * ") or line.startswith("// ")]
        for line in comment_blocks:
            self.assertNotIn("*/", line)
    def test_keyword_and_identifier_sanitization_in_swift_and_kotlin(self):
        """Properties and defs that are keywords in Swift or Kotlin must be safely escaped."""
        lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.keywords",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "default": {"type": "string"},
                        "class": {"type": "string"},
                        "package": {"type": "string"},
                        "val": {"type": "integer"},
                        "self": {"type": "boolean"},
                        "Any": {"type": "string"},
                    },
                }
            },
        }
        swift_code = SwiftCodeGenerator(lexicon, self.cycle_detector).convert()
        self.assertIn("`default`", swift_code)
        self.assertIn("`class`", swift_code)
        self.assertIn("`self`", swift_code)

        kotlin_code = KotlinCodeGenerator(lexicon, self.cycle_detector).convert()
        self.assertIn("`class`", kotlin_code)
        self.assertIn("`package`", kotlin_code)
        self.assertIn("`val`", kotlin_code)
        self.assertNotIn("`default`", kotlin_code)

    def test_comment_escaping_in_all_templates_and_contexts(self):
        """Every template context (properties, records, knownValues, subscriptions, definitions) must escape comments."""
        malicious_doc = "Doc with */ and /* and \n newline break"
        # 1. Swift knownValuesEnum
        from enum_generator import EnumGenerator
        swift_gen = SwiftCodeGenerator({
            "lexicon": 1,
            "id": "com.atproto.test.knownvalues",
            "defs": {"main": {"type": "object"}},
        }, self.cycle_detector)
        enum_gen = EnumGenerator(swift_gen)
        enum_gen.generate_enum_from_known_values("TestEnum", ["val1"], {"val1": malicious_doc})
        self.assertNotIn("*/", swift_gen.enums)
        self.assertNotIn("\n//  newline", swift_gen.enums)

        # 2. Swift subscription
        sub_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.subscribe",
            "defs": {
                "main": {
                    "type": "subscription",
                    "description": malicious_doc,
                    "message": {"schema": {"type": "ref", "ref": "#msg"}},
                },
                "msg": {"type": "object", "properties": {"a": {"type": "string"}}},
            },
        }
        swift_sub = SwiftCodeGenerator(sub_lexicon, self.cycle_detector).convert()
        self.assertNotIn("*/", swift_sub)

        # 3. Kotlin properties, record, lexiconDefinitions, subscription
        kt_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.comprehensive",
            "description": "Multi\nLine\nTop\nDescription",
            "defs": {
                "main": {
                    "type": "record",
                    "description": malicious_doc,
                    "record": {
                        "type": "object",
                        "properties": {
                            "prop1": {"type": "string", "description": malicious_doc},
                        },
                    },
                },
                "customDef": {
                    "type": "object",
                    "description": malicious_doc,
                    "properties": {
                        "field1": {"type": "string", "description": malicious_doc},
                    },
                },
                "customAlias": {
                    "type": "string",
                    "description": malicious_doc,
                },
            },
        }
        kt_code = KotlinCodeGenerator(kt_lexicon, self.cycle_detector).convert()
        # Verify package is not preceded by bare * from multi-line description
        self.assertNotIn("\n* Line\n", kt_code)
        # 4. Kotlin subscription with non-decodable variant
        kt_sub_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.subnondecodable",
            "defs": {
                "main": {
                    "type": "subscription",
                    "message": {
                        "schema": {
                            "type": "union",
                            "refs": ["#segment"],
                        }
                    },
                },
                "segment": {
                    "type": "bytes",
                },
            },
        }
        kt_sub_code = KotlinCodeGenerator(kt_sub_lexicon, self.cycle_detector).convert()
        self.assertIn('// "#segment" -> payload type `ComAtprotoTestSubnondecodableSegment` is', kt_sub_code)
        self.assertIn('// not a @Serializable class', kt_sub_code)
        # 5. Verify line comment escaping when non-decodable variant tag contains newlines
        sub_rendered = kotlin_templates.KotlinTemplateManager().subscription_template.render(
            receiver_type="TestNamespace",
            function_name="subscribeTest",
            has_parameters=False,
            parameters_type=None,
            message_type="TestMessage",
            message_union="TestMessageUnion",
            is_union=True,
            variants=[{
                "header_tag": "multi\nline\ntag",
                "short_name": "Segment",
                "payload_type": "Bytes",
                "decodable": False,
            }],
        )
        self.assertNotIn("* line", sub_rendered)
        self.assertNotIn("* tag", sub_rendered)
        self.assertIn('// "multi\n// line\n// tag" -> payload type `Bytes` is', sub_rendered)

    def test_blob_upload_procedure_fails_closed_template_contract(self):
        """Blob upload procedure must render guard ImageMetadataStripper.stripMetadata with fail-closed throw and preserve opt-out."""
        upload_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.repo.uploadBlob",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "*/*",
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {"blob": {"type": "blob"}},
                        },
                    },
                }
            },
        }
        swift_code = SwiftCodeGenerator(upload_lexicon, self.cycle_detector).convert()
        self.assertIn("stripMetadata: Bool = true", swift_code)
        self.assertIn("if stripMetadata {", swift_code)
        self.assertIn("guard let strippedData = ImageMetadataStripper.stripMetadata(from: dataToUpload) else {", swift_code)
        self.assertIn("throw NetworkError.metadataStrippingFailed", swift_code)
        self.assertIn("dataToUpload = strippedData", swift_code)

    def test_string_literal_escaping_in_all_templates_and_contexts(self):
        """String-literal contexts (encodings, knownValues, union refs, @SerialName) must escape quotes, backslashes, and interpolation."""
        adversarial_str = 'test"payload\\(1+1)$foo${bar.baz()}'
        
        # 1. Swift Procedure and Query with adversarial encodings
        proc_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.procEncoding",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": adversarial_str,
                    },
                    "output": {
                        "encoding": adversarial_str,
                        "schema": {"type": "object", "properties": {"res": {"type": "string"}}},
                    },
                }
            },
        }
        swift_proc = SwiftCodeGenerator(proc_lexicon, self.cycle_detector).convert()
        self.assertNotIn(f'"{adversarial_str}"', swift_proc)
        self.assertIn(r'test\"payload\\(1+1)$foo${bar.baz()}', swift_proc)

        # 2. Kotlin Procedure and Query with adversarial encodings
        kt_proc = KotlinCodeGenerator(proc_lexicon, self.cycle_detector).convert()
        self.assertNotIn(f'"{adversarial_str}"', kt_proc)
        self.assertIn(r'test\"payload\\(1+1)\$foo\${bar.baz()}', kt_proc)

        # 3. Swift and Kotlin knownValues
        from enum_generator import EnumGenerator
        swift_gen = SwiftCodeGenerator({
            "lexicon": 1,
            "id": "com.atproto.test.knownValuesLiteral",
            "defs": {"main": {"type": "object"}},
        }, self.cycle_detector)
        enum_gen = EnumGenerator(swift_gen)
        enum_gen.generate_enum_from_known_values("TestLiteralEnum", [adversarial_str], {adversarial_str: "doc"})
        self.assertNotIn(f'rawValue: "{adversarial_str}"', swift_gen.enums)
        self.assertIn(r'rawValue: "test\"payload\\(1+1)$foo${bar.baz()}"', swift_gen.enums)

        from kotlin_enum_generator import KotlinEnumGenerator
        kt_gen = KotlinCodeGenerator({
            "lexicon": 1,
            "id": "com.atproto.test.knownValuesLiteral",
            "defs": {"main": {"type": "object"}},
        }, self.cycle_detector)
        kt_enum_gen = KotlinEnumGenerator(kt_gen)
        kt_enum_gen.generate_enum_class_from_known_values("TestKtLiteralEnum", [adversarial_str])
        self.assertNotIn(f'@SerialName("{adversarial_str}")', kt_gen.enum_classes)
        self.assertIn(r'@SerialName("test\"payload\\(1+1)\$foo\${bar.baz()}")', kt_gen.enum_classes)

        # 4. Kotlin property with $
        dollar_prop_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.dollarProp",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "$type": {"type": "string"},
                    },
                }
            },
        }
        kt_dollar_code = KotlinCodeGenerator(dollar_prop_lexicon, self.cycle_detector).convert()
        self.assertNotIn('@SerialName("$type")', kt_dollar_code)
        self.assertIn(r'@SerialName("\$type")', kt_dollar_code)

        # 5. Swift Union Array and Enum with adversarial ref
        union_lexicon = {
            "lexicon": 1,
            "id": "com.atproto.test.unionLiteral",
            "defs": {
                "main": {
                    "type": "object",
                    "properties": {
                        "unionProp": {
                            "type": "union",
                            "refs": ["com.atproto.test.targetDef", "com.atproto.test.otherDef"],
                        }
                    }
                },
                "targetDef": {"type": "object", "properties": {"a": {"type": "string"}}},
                "otherDef": {"type": "object", "properties": {"b": {"type": "string"}}},
            }
        }
        kt_union_code = KotlinCodeGenerator(union_lexicon, self.cycle_detector).convert()
        self.assertIn('it["\\$type"]', kt_union_code)

    def test_reject_invalid_refs_in_all_schema_positions(self):
        """Adversarial schemas with invalid ref or refs (containing newlines, injection statements, bad NSIDs) must be rejected."""
        from base_code_generator import validate_lexicon_schema
        invalid_refs = [
            "#bad\ncode()",
            "com.example.bad\n// injected\nval x = 1",
            "#bad space",
            "invalid..nsid",
            "com.bad#char/slash",
            "#injected\nfunc foo() {}",
            "#123startWithDigit",
            "#",
            "",
            "com.example.foo#",
            "com.example.foo#bad name",
            "com.example.foo#123",
        ]
        for bad_ref in invalid_refs:
            # 1. Def level ref
            lex_def_ref = {
                "lexicon": 1,
                "id": "com.atproto.test.badref",
                "defs": {"main": {"type": "ref", "ref": bad_ref}},
            }
            with self.assertRaises(ValueError):
                validate_lexicon_schema(lex_def_ref)
            with self.assertRaises(ValueError):
                SwiftCodeGenerator(lex_def_ref, self.cycle_detector).convert()
            with self.assertRaises(ValueError):
                KotlinCodeGenerator(lex_def_ref, self.cycle_detector).convert()

            # 2. Def level union refs
            lex_def_union = {
                "lexicon": 1,
                "id": "com.atproto.test.badref",
                "defs": {"main": {"type": "union", "refs": ["#validDef", bad_ref]}, "validDef": {"type": "object"}},
            }
            with self.assertRaises(ValueError):
                validate_lexicon_schema(lex_def_union)
            with self.assertRaises(ValueError):
                SwiftCodeGenerator(lex_def_union, self.cycle_detector).convert()
            with self.assertRaises(ValueError):
                KotlinCodeGenerator(lex_def_union, self.cycle_detector).convert()

            # 3. Property level ref
            lex_prop_ref = {
                "lexicon": 1,
                "id": "com.atproto.test.badref",
                "defs": {"main": {"type": "object", "properties": {"item": {"type": "ref", "ref": bad_ref}}}},
            }
            with self.assertRaises(ValueError):
                validate_lexicon_schema(lex_prop_ref)
            with self.assertRaises(ValueError):
                SwiftCodeGenerator(lex_prop_ref, self.cycle_detector).convert()
            with self.assertRaises(ValueError):
                KotlinCodeGenerator(lex_prop_ref, self.cycle_detector).convert()

            # 4. Property level union refs
            lex_prop_union = {
                "lexicon": 1,
                "id": "com.atproto.test.badref",
                "defs": {"main": {"type": "object", "properties": {"item": {"type": "union", "refs": [bad_ref]}}}},
            }
            with self.assertRaises(ValueError):
                validate_lexicon_schema(lex_prop_union)
            with self.assertRaises(ValueError):
                SwiftCodeGenerator(lex_prop_union, self.cycle_detector).convert()
            with self.assertRaises(ValueError):
                KotlinCodeGenerator(lex_prop_union, self.cycle_detector).convert()

            # 5. Array items ref / union refs
            lex_array_items = {
                "lexicon": 1,
                "id": "com.atproto.test.badref",
                "defs": {"main": {"type": "array", "items": {"type": "union", "refs": [bad_ref]}}},
            }
            with self.assertRaises(ValueError):
                validate_lexicon_schema(lex_array_items)
            with self.assertRaises(ValueError):
                SwiftCodeGenerator(lex_array_items, self.cycle_detector).convert()
            with self.assertRaises(ValueError):
                KotlinCodeGenerator(lex_array_items, self.cycle_detector).convert()
if __name__ == "__main__":
    unittest.main()
