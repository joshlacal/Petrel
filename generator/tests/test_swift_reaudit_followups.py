"""Generator follow-ups from the Lexicon and Bluesky-helper re-audits.

lex-21  query parameter `default`s become initializer defaults (sent on the wire)
lex-24  cursor-paginated queries conform to the XRPCPages protocols
r-1     an inline object never takes the Swift name of another type in its lexicon
r-5     a malformed optional field read leniently is kept for re-encoding
r-6     text/event-stream queries go through the portable runtime, not URLSession.bytes
bsky r-1  the client-global report labeler setters are deprecated
"""

import pathlib
import re
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from main import render_atproto_client
from swift_code_generator import SwiftCodeGenerator


def query_lexicon(properties, output_properties=None, encoding="application/json", required=None):
    parameters = {"type": "params", "properties": properties}
    if required:
        parameters["required"] = required
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.query",
        "defs": {
            "main": {
                "type": "query",
                "parameters": parameters,
                "output": {
                    "encoding": encoding,
                    "schema": {"type": "object", "properties": output_properties or {}},
                },
            },
        },
    }


def squash(code):
    return re.sub(r"\s+", " ", code)


class ParameterDefaultTests(unittest.TestCase):
    """lex-21: the Lexicon says a client should send a parameter's default."""

    def test_defaults_become_initializer_defaults(self):
        generated = squash(SwiftCodeGenerator(query_lexicon({
            "limit": {"type": "integer", "default": 50},
            "unreadOnly": {"type": "boolean", "default": False},
            "sort": {"type": "string", "enum": ["top", "latest"], "default": "latest"},
            "scope": {"type": "string", "knownValues": ["instance", "personal"], "default": "instance"},
            "quote": {"type": "string", "default": "a \"b\""},
            "cursor": {"type": "string"},
        })).convert())

        self.assertIn("limit: Int? = 50,", generated)
        self.assertIn("unreadOnly: Bool? = false,", generated)
        self.assertIn("sort: ParametersSort? = .value_latest,", generated)
        self.assertIn('scope: String? = "instance",', generated)
        self.assertIn('quote: String? = "a \\"b\\"",', generated)
        self.assertIn("cursor: String? = nil )", generated)

    def test_required_parameter_with_default_is_still_defaulted(self):
        generated = squash(SwiftCodeGenerator(query_lexicon(
            {"limit": {"type": "integer", "default": 10}}, required=["limit"],
        )).convert())

        self.assertIn("limit: Int = 10 )", generated)

    def test_subscription_convenience_signature_uses_the_default(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.subscribe",
            "defs": {
                "main": {
                    "type": "subscription",
                    "parameters": {"type": "params", "properties": {"limit": {"type": "integer", "default": 7}}},
                    "message": {"schema": {"type": "union", "refs": ["#event"]}},
                },
                "event": {"type": "object", "properties": {}},
            },
        }
        generated = squash(SwiftCodeGenerator(lexicon).convert())

        self.assertIn("public func subscribe( limit: Int? = 7 )", generated)

    def test_default_of_the_wrong_type_is_rejected(self):
        for schema in (
            {"type": "integer", "default": "50"},
            {"type": "integer", "default": True},
            {"type": "boolean", "default": 0},
            {"type": "string", "default": 3},
        ):
            with self.subTest(schema=schema):
                with self.assertRaisesRegex(ValueError, r"blue\.catbird\.test\.query.*'value'.*default"):
                    SwiftCodeGenerator(query_lexicon({"value": schema})).convert()

    def test_enum_default_outside_the_enum_is_rejected(self):
        lexicon = query_lexicon({"value": {"type": "string", "enum": ["a"], "default": "b"}})

        with self.assertRaisesRegex(ValueError, r"'value'.*default 'b'.*enum"):
            SwiftCodeGenerator(lexicon).convert()


class PaginationConformanceTests(unittest.TestCase):
    """lex-24: a query with a `cursor` parameter and output field pages with XRPCPages."""

    def test_cursor_query_conforms(self):
        generated = squash(SwiftCodeGenerator(query_lexicon(
            {"limit": {"type": "integer", "default": 50}, "cursor": {"type": "string"}, "default": {"type": "string"}},
            {"cursor": {"type": "string"}, "items": {"type": "array", "items": {"type": "string"}}},
        )).convert())

        self.assertIn(
            "extension BlueCatbirdTestQuery.Parameters: XRPCCursorPaginatedParameters { "
            "public func withCursor(_ cursor: String?) -> Self { "
            "Self(limit: limit, cursor: cursor, `default`: `default`) } }",
            generated,
        )
        self.assertIn("extension BlueCatbirdTestQuery.Output: XRPCCursorPaginatedOutput {}", generated)

    def test_no_conformance_without_both_cursors(self):
        cases = {
            "no output cursor": query_lexicon({"cursor": {"type": "string"}}, {"items": {"type": "string"}}),
            "no parameter cursor": query_lexicon({"limit": {"type": "integer"}}, {"cursor": {"type": "string"}}),
            "required cursor": query_lexicon({"cursor": {"type": "string"}}, {"cursor": {"type": "string"}}, required=["cursor"]),
            "typed cursor": query_lexicon({"cursor": {"type": "string", "format": "tid"}}, {"cursor": {"type": "string"}}),
        }
        for name, lexicon in cases.items():
            with self.subTest(name):
                generated = SwiftCodeGenerator(lexicon).convert()
                self.assertNotIn("XRPCCursorPaginated", generated)


class InlineObjectNameTests(unittest.TestCase):
    """r-1: def `view` with inline property `meta` and a named def `viewMeta`."""

    LEXICON = {
        "lexicon": 1,
        "id": "blue.catbird.test.clash",
        "defs": {
            "view": {
                "type": "object",
                "properties": {"meta": {"type": "object", "properties": {"inline": {"type": "string"}}}},
            },
            "viewMeta": {"type": "object", "properties": {"named": {"type": "string"}}},
        },
    }

    def test_inline_object_does_not_take_a_named_definition_type_name(self):
        generated = SwiftCodeGenerator(self.LEXICON).convert()

        self.assertEqual(len(re.findall(r"public struct ViewMeta\b", generated)), 1)
        self.assertIn("public struct ViewMetaObject", generated)
        self.assertIn("public let meta: ViewMetaObject?", generated)
        # The named definition keeps its name: other lexicons reference it as Container.ViewMeta.
        named = generated[generated.index("public struct ViewMeta:"):]
        self.assertIn("public let named: String?", named[:named.index("public init(")])

    def test_inline_objects_of_unrelated_properties_that_still_collide_are_disambiguated(self):
        lexicon = {
            "lexicon": 1,
            "id": "blue.catbird.test.clash",
            "defs": {
                "view": {"type": "object", "properties": {
                    "meta": {"type": "object", "properties": {"x": {"type": "string"}}},
                }},
                "viewMeta": {"type": "object", "properties": {}},
                "viewMetaObject": {"type": "object", "properties": {}},
            },
        }
        generated = SwiftCodeGenerator(lexicon).convert()

        self.assertIn("public let meta: ViewMetaObject2?", generated)
        for name in ("ViewMeta", "ViewMetaObject", "ViewMetaObject2"):
            self.assertEqual(len(re.findall(rf"public struct {name}\b", generated)), 1, name)


class MalformedOptionalFieldTests(unittest.TestCase):
    """r-5: lenient decoding drops a malformed optional value from the property but
    keeps the raw value, so writing the object back does not lose it."""

    LEXICON = {
        "lexicon": 1,
        "id": "blue.catbird.test.record",
        "defs": {
            "main": {
                "type": "record",
                "key": "tid",
                "record": {
                    "type": "object",
                    "required": ["text"],
                    "properties": {"text": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}},
                },
            },
        },
    }

    def test_lenient_record_keeps_malformed_fields(self):
        generated = squash(SwiftCodeGenerator(self.LEXICON).convert())

        self.assertIn("var malformedFields: Swift.Set<String> = []", generated)
        self.assertIn('malformedFields.insert("tags")', generated)
        self.assertIn(
            "ATProtocolValueContainer.decodeExtraFields(from: decoder, knownKeys: Self.knownFieldKeys, keepingMalformed: malformedFields)",
            generated,
        )
        self.assertIn(
            "ATProtocolValueContainer.encodeExtraFields(extraFields, to: encoder, unlessSet: hasValue(forField:))",
            generated,
        )
        self.assertIn(
            "ATProtocolValueContainer.addingExtraFields(extraFields, to: map, unlessSet: hasValue(forField:))",
            generated,
        )
        self.assertIn('case "tags": return self.tags != nil', generated)


class ServerSentEventsTests(unittest.TestCase):
    """r-6: the SSE query must compile on Linux and go through NetworkService."""

    def test_event_stream_query_uses_runtime_helper(self):
        generated = SwiftCodeGenerator(query_lexicon(
            {"cursor": {"type": "string"}}, {"text": {"type": "string"}}, encoding="text/event-stream",
        )).convert()

        self.assertNotIn("URLSession", generated)
        self.assertNotIn(".bytes(for:", generated)
        self.assertIn("networkService.serverSentEvents(", squash(generated))
        self.assertIn("as: BlueCatbirdTestQuery.Output.self", squash(generated))


class ReportLabelerDeprecationTests(unittest.TestCase):
    """bsky r-1: these write `atproto-proxy` into headers shared by every request."""

    def test_global_report_labeler_setters_are_deprecated(self):
        generated = render_atproto_client("")
        for name in ("setReportLabeler(did: String)", "clearReportLabeler()"):
            with self.subTest(name):
                start = generated.index(f"public func {name}")
                preamble = generated[generated.rfind("}", 0, start):start]
                self.assertIn("@available(*, deprecated", preamble)
                self.assertIn("createModerationReport(_:labeler:)", preamble)


if __name__ == "__main__":
    unittest.main()
