import pathlib
import re
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator


def render_endpoint(
    lexicon_id: str,
    endpoint_type: str,
    error_name: str,
    error_description: str,
    *,
    has_output: bool,
) -> str:
    main = {
        "type": endpoint_type,
        "errors": [
            {
                "name": error_name,
                "description": error_description,
            }
        ],
    }
    if has_output:
        main["output"] = {
            "encoding": "application/json",
            "schema": {
                "type": "object",
                "required": ["ok"],
                "properties": {"ok": {"type": "boolean"}},
            },
        }

    return SwiftCodeGenerator(
        {
            "lexicon": 1,
            "id": lexicon_id,
            "defs": {"main": main},
        }
    ).convert()


class SwiftEndpointErrorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.query = render_endpoint(
            "blue.catbird.test.lookupEmoji",
            "query",
            "EmojiNotFound",
            "No matching emoji exists.",
            has_output=True,
        )
        cls.output_procedure = render_endpoint(
            "blue.catbird.test.saveDestination",
            "procedure",
            "DestinationExists",
            "The destination already exists.",
            has_output=True,
        )
        cls.outputless_procedure = render_endpoint(
            "blue.catbird.test.invalidateToken",
            "procedure",
            "InvalidToken",
            "The token cannot be invalidated.",
            has_output=False,
        )

    def assert_exact_parser_call(self, generated: str, error_type: str):
        self.assertEqual(generated.count("ATProtoErrorParser.parse("), 1)
        self.assertRegex(
            generated,
            re.compile(
                r"ATProtoErrorParser\.parse\(\s*"
                r"data: responseData,\s*"
                r"statusCode: responseCode,\s*"
                rf"errorType: {re.escape(error_type)}\.Error\.self\s*\)",
                re.DOTALL,
            ),
        )

    def test_error_wire_values_are_declared_names_and_descriptions_are_docs_only(self):
        cases = (
            (
                self.query,
                "emojiNotFound",
                "EmojiNotFound",
                "No matching emoji exists.",
            ),
            (
                self.output_procedure,
                "destinationExists",
                "DestinationExists",
                "The destination already exists.",
            ),
            (
                self.outputless_procedure,
                "invalidToken",
                "InvalidToken",
                "The token cannot be invalidated.",
            ),
        )

        for generated, case_name, wire_name, description in cases:
            with self.subTest(wire_name=wire_name):
                self.assertIn(f'case {case_name} = "{wire_name}"', generated)
                self.assertNotIn(f'"{wire_name}.{description}"', generated)
                description_lines = [
                    line.strip()
                    for line in generated.splitlines()
                    if description in line
                ]
                self.assertEqual(description_lines, [f"/// {description}"])

    def test_generated_error_accessors_return_the_exact_wire_value(self):
        for generated in (
            self.query,
            self.output_procedure,
            self.outputless_procedure,
        ):
            with self.subTest():
                self.assertRegex(
                    generated,
                    re.compile(
                        r"public var description: String \{\s*"
                        r"return self\.rawValue\s*\}",
                        re.DOTALL,
                    ),
                )
                self.assertRegex(
                    generated,
                    re.compile(
                        r"public var errorName: String \{\s*"
                        r"return self\.rawValue\s*\}",
                        re.DOTALL,
                    ),
                )

    def test_query_parses_one_declared_error_then_preserves_tuple_fallback(self):
        self.assert_exact_parser_call(
            self.query,
            "BlueCatbirdTestLookupEmoji",
        )
        success_index = self.query.index(
            "if (200...299).contains(responseCode)"
        )
        non_success_index = self.query.index("} else {", success_index)
        parser_index = self.query.index("ATProtoErrorParser.parse(")
        fallback_index = self.query.index("return (responseCode, nil)", parser_index)
        self.assertLess(non_success_index, parser_index)
        self.assertLess(parser_index, fallback_index)
        self.assertIn("throw atprotoError", self.query[parser_index:fallback_index])

    def test_output_procedure_parses_one_declared_error_then_preserves_tuple_fallback(self):
        self.assert_exact_parser_call(
            self.output_procedure,
            "BlueCatbirdTestSaveDestination",
        )
        success_index = self.output_procedure.index(
            "if (200...299).contains(responseCode)"
        )
        non_success_index = self.output_procedure.index("} else {", success_index)
        parser_index = self.output_procedure.index("ATProtoErrorParser.parse(")
        fallback_index = self.output_procedure.index(
            "return (responseCode, nil)",
            parser_index,
        )
        self.assertLess(non_success_index, parser_index)
        self.assertLess(parser_index, fallback_index)
        self.assertIn(
            "throw atprotoError",
            self.output_procedure[parser_index:fallback_index],
        )

    def test_outputless_procedure_captures_body_and_parses_only_non_success(self):
        self.assertIn(
            "let (responseData, response) = try await networkService.performRequest",
            self.outputless_procedure,
        )
        self.assertNotIn(
            "let (_, response) = try await networkService.performRequest",
            self.outputless_procedure,
        )
        self.assert_exact_parser_call(
            self.outputless_procedure,
            "BlueCatbirdTestInvalidateToken",
        )
        non_success_index = self.outputless_procedure.index(
            "if !(200...299).contains(responseCode)"
        )
        parser_index = self.outputless_procedure.index("ATProtoErrorParser.parse(")
        fallback_index = self.outputless_procedure.index(
            "return responseCode",
            parser_index,
        )
        self.assertLess(non_success_index, parser_index)
        self.assertLess(parser_index, fallback_index)
        self.assertIn(
            "throw atprotoError",
            self.outputless_procedure[parser_index:fallback_index],
        )


if __name__ == "__main__":
    unittest.main()
