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
    emit_xrpc_error_parsing: bool = False,
    has_errors: bool = True,
) -> str:
    main = {
        "type": endpoint_type,
    }
    if has_errors:
        main["errors"] = [
            {
                "name": error_name,
                "description": error_description,
            }
        ]
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
        },
        emit_xrpc_error_parsing=emit_xrpc_error_parsing,
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

    def assert_declared_error_throw(self, generated: str, error_type: str):
        """Non-2xx throws the declared typed error, else the generic envelope error."""
        self.assertEqual(generated.count("ATProtoErrorParser.xrpcError("), 1)
        self.assertRegex(
            generated,
            re.compile(
                r"guard \(200\.\.\.299\)\.contains\(responseCode\) else \{\s*"
                r"throw ATProtoErrorParser\.xrpcError\(data: responseData, response: response, "
                rf"declaredErrors: {re.escape(error_type)}\.Error\.self\)\s*\}}",
                re.DOTALL,
            ),
        )

    def assert_generic_error_throw(self, generated: str):
        self.assertEqual(generated.count("ATProtoErrorParser.xrpcError("), 1)
        self.assertRegex(
            generated,
            re.compile(
                r"guard \(200\.\.\.299\)\.contains\(responseCode\) else \{\s*"
                r"throw ATProtoErrorParser\.xrpcError\(data: responseData, response: response\)\s*\}",
                re.DOTALL,
            ),
        )

    def assert_uses_http_error_response_transport(self, generated: str):
        self.assertEqual(
            generated.count("performRequestReturningHTTPErrorResponses("),
            1,
        )
        # The plain transport throws a bare status code for 402-499 and never
        # hands the body back, so no generated call may use it.
        self.assertNotIn("networkService.performRequest(", generated)

    def assert_never_swallows_a_response(self, generated: str):
        self.assertNotIn("return (responseCode, nil)", generated)
        self.assertNotIn("LogManager.logError", generated)

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

    def test_query_throws_declared_error_and_undecodable_success(self):
        self.assert_uses_http_error_response_transport(self.query)
        self.assert_declared_error_throw(self.query, "BlueCatbirdTestLookupEmoji")
        self.assert_never_swallows_a_response(self.query)
        guard_index = self.query.index("guard (200...299).contains(responseCode)")
        decode_index = self.query.index("JSONDecoder().decode(")
        self.assertLess(guard_index, decode_index)
        self.assertIn(
            "throw XRPCResponseDecodingError(endpoint: endpoint, statusCode: responseCode, underlying: error)",
            self.query[decode_index:],
        )

    def test_output_procedure_throws_declared_error_and_undecodable_success(self):
        self.assert_uses_http_error_response_transport(self.output_procedure)
        self.assert_declared_error_throw(
            self.output_procedure, "BlueCatbirdTestSaveDestination"
        )
        self.assert_never_swallows_a_response(self.output_procedure)
        decode_index = self.output_procedure.index("JSONDecoder().decode(")
        self.assertIn(
            "throw XRPCResponseDecodingError(endpoint: endpoint, statusCode: responseCode, underlying: error)",
            self.output_procedure[decode_index:],
        )

    def test_outputless_procedure_throws_declared_error_before_returning_status(self):
        self.assert_uses_http_error_response_transport(self.outputless_procedure)
        self.assert_declared_error_throw(
            self.outputless_procedure, "BlueCatbirdTestInvalidateToken"
        )
        guard_index = self.outputless_procedure.index(
            "guard (200...299).contains(responseCode)"
        )
        return_index = self.outputless_procedure.index("return responseCode")
        self.assertLess(guard_index, return_index)
        self.assertNotIn("XRPCResponseDecodingError", self.outputless_procedure)

    def test_endpoints_without_declared_errors_still_throw_the_envelope(self):
        """Every endpoint surfaces {error, message}, whatever the manifest says.

        `emit_xrpc_error_parsing` used to gate this per namespace; it is accepted
        for manifest compatibility and no longer changes the output.
        """
        for endpoint_type, lexicon_id, has_output in (
            ("query", "blue.catbird.test.listItems", True),
            ("procedure", "blue.catbird.test.saveDestination", True),
            ("procedure", "blue.catbird.test.invalidateToken", False),
        ):
            for flag in (False, True):
                with self.subTest(endpoint=lexicon_id, flag=flag):
                    generated = render_endpoint(
                        lexicon_id,
                        endpoint_type,
                        "",
                        "",
                        has_output=has_output,
                        has_errors=False,
                        emit_xrpc_error_parsing=flag,
                    )
                    self.assert_uses_http_error_response_transport(generated)
                    self.assert_generic_error_throw(generated)
                    self.assert_never_swallows_a_response(generated)
                    self.assertNotIn("Error.self", generated)

    def test_query_without_output_returns_the_status_code(self):
        generated = render_endpoint(
            "blue.catbird.test.ping",
            "query",
            "",
            "",
            has_output=False,
            has_errors=False,
        )
        self.assertIn("public func ping() async throws -> Int {", generated)
        self.assertNotIn("None", generated)
        self.assert_generic_error_throw(generated)
        self.assertIn("return responseCode", generated)


if __name__ == "__main__":
    unittest.main()
