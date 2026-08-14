"""Kotlin emission for named top-level defs that aren't objects.

`convert_ref` resolves a ref to ANY def into `{Class}{PascalCaseFragment}`, so
every def shape that can be the target of a ref must produce a declaration
carrying exactly that name. Union, bytes, and plain-string defs had no branch in
`generate_lex_definitions`, which minted 19 undeclared type names across the
`blue.catbird.chat` overlay.
"""
import pathlib
import re
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from cycle_detector import CycleDetector
from kotlin_code_generator import KotlinCodeGenerator


def named_defs_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.defs",
        "defs": {
            "signedTransition": {
                "type": "union",
                "refs": ["#signedCommit", "#signedPolicy"],
                "closed": True,
            },
            "signedCommit": {
                "type": "object",
                "properties": {"commit": {"type": "string"}},
            },
            "signedPolicy": {
                "type": "object",
                "properties": {"policy": {"type": "string"}},
            },
            "artifactHash": {"type": "bytes", "minLength": 32, "maxLength": 32},
            "bareDid": {"type": "string", "format": "did"},
            "canonicalDatetime": {"type": "string", "format": "datetime"},
            "operationId": {"type": "string", "minLength": 36, "maxLength": 36},
            "closedKind": {"type": "string", "enum": ["a", "b"]},
            "openKind": {"type": "string", "knownValues": ["c", "d"]},
            "carrier": {
                "type": "object",
                "required": ["transition", "hash", "did", "when", "op"],
                "properties": {
                    "transition": {"type": "ref", "ref": "#signedTransition"},
                    "hash": {"type": "ref", "ref": "#artifactHash"},
                    "did": {"type": "ref", "ref": "#bareDid"},
                    "when": {"type": "ref", "ref": "#canonicalDatetime"},
                    "op": {"type": "ref", "ref": "#operationId"},
                },
            },
        },
    }


def subscription_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.subscribeEvents",
        "defs": {
            "main": {
                "type": "subscription",
                "message": {
                    "schema": {
                        "type": "ref",
                        "ref": "blue.catbird.test.defs#subscriptionMessage",
                    }
                },
            }
        },
    }


def subscription_defs_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.defs",
        "defs": {
            "subscriptionMessage": {
                "type": "union",
                "refs": ["#eventEnvelope", "#typingEvent"],
                "closed": True,
            },
            "eventEnvelope": {
                "type": "object",
                "properties": {"cursor": {"type": "string"}},
            },
            "typingEvent": {
                "type": "object",
                "properties": {"convoId": {"type": "string"}},
            },
        },
    }


def declared_names(source):
    """Every top-level type name the generated Kotlin declares."""
    pattern = r"\b(?:data class|class|sealed interface|sealed class|typealias|enum class|object)\s+([A-Za-z_][A-Za-z0-9_]*)"
    return set(re.findall(pattern, source))


class KotlinNamedDefGenerationTests(unittest.TestCase):
    def setUp(self):
        self.source = KotlinCodeGenerator(named_defs_lexicon()).convert()

    def test_named_union_def_emits_sealed_interface_under_the_ref_resolved_name(self):
        # Not the property-union `{Struct}{Prop}Union` form — refs resolve to
        # the bare `{Class}{Def}` name, locally and cross-lexicon alike.
        self.assertIn(
            "sealed interface BlueCatbirdTestDefsSignedTransition", self.source
        )
        self.assertNotIn("BlueCatbirdTestDefsSignedTransitionUnion", self.source)

    def test_named_union_def_carries_every_variant_and_its_wire_tag(self):
        self.assertIn(
            "data class SignedCommit(val value: blue.catbird.petrel.generated.BlueCatbirdTestDefsSignedCommit)",
            self.source,
        )
        self.assertIn(
            "data class SignedPolicy(val value: blue.catbird.petrel.generated.BlueCatbirdTestDefsSignedPolicy)",
            self.source,
        )
        self.assertIn('"blue.catbird.test.defs#signedCommit" ->', self.source)
        self.assertIn('"blue.catbird.test.defs#signedPolicy" ->', self.source)

    def test_bytes_def_aliases_to_bytes(self):
        self.assertIn("typealias BlueCatbirdTestDefsArtifactHash = Bytes", self.source)

    def test_plain_string_defs_alias_to_their_format_mapped_type(self):
        self.assertIn("typealias BlueCatbirdTestDefsBareDid = DID", self.source)
        self.assertIn(
            "typealias BlueCatbirdTestDefsCanonicalDatetime = ATProtocolDate",
            self.source,
        )
        self.assertIn("typealias BlueCatbirdTestDefsOperationId = String", self.source)

    def test_enum_bearing_string_defs_still_win_over_the_scalar_alias(self):
        # Branch ordering guard: `string` + enum/knownValues must keep emitting
        # enum classes rather than falling into the plain-scalar typealias.
        self.assertNotIn("typealias BlueCatbirdTestDefsClosedKind", self.source)
        self.assertNotIn("typealias BlueCatbirdTestDefsOpenKind", self.source)
        self.assertIn("BlueCatbirdTestDefsDefsClosedKind", self.source)
        self.assertIn("BlueCatbirdTestDefsOpenKind", self.source)

    def test_every_name_minted_by_convert_ref_is_actually_declared(self):
        # The invariant the defect broke: a ref must never name a type that no
        # declaration provides.
        generator = KotlinCodeGenerator(named_defs_lexicon())
        source = generator.convert()
        declared = declared_names(source)
        for def_name in named_defs_lexicon()["defs"]:
            with self.subTest(definition=def_name):
                self.assertIn(
                    generator.type_converter.convert_ref(f"#{def_name}"), declared
                )


class KotlinRefTypedSubscriptionMessageTests(unittest.TestCase):
    def setUp(self):
        registry = CycleDetector()
        for name, schema in subscription_defs_lexicon()["defs"].items():
            registry.add_type("blue.catbird.test.defs", name, schema)
        self.source = KotlinCodeGenerator(
            subscription_lexicon(), cycle_detector=registry
        ).convert()

    def test_ref_message_aliases_instead_of_emitting_an_empty_class(self):
        self.assertIn(
            "typealias BlueCatbirdTestSubscribeEventsMessage = "
            "BlueCatbirdTestDefsSubscriptionMessage",
            self.source,
        )
        self.assertNotIn("class BlueCatbirdTestSubscribeEventsMessage\n", self.source)

    def test_flow_decodes_the_target_unions_variants(self):
        # Refs inside the target def are fragments of ITS lexicon, so they must
        # be qualified before conversion — otherwise they'd resolve against the
        # subscription lexicon and name types that don't exist.
        self.assertIn(
            "kotlinx.coroutines.flow.Flow<BlueCatbirdTestSubscribeEventsMessage>",
            self.source,
        )
        self.assertIn(
            '"#eventEnvelope" -> BlueCatbirdTestDefsSubscriptionMessage.EventEnvelope(',
            self.source,
        )
        self.assertIn(
            "blue.catbird.petrel.generated.BlueCatbirdTestDefsEventEnvelope.serializer()",
            self.source,
        )
        self.assertNotIn("BlueCatbirdTestSubscribeEventsEventEnvelope", self.source)

    def test_synthetic_error_and_unexpected_variants_extend_the_target_union(self):
        self.assertIn(
            "data class BlueCatbirdTestDefsSubscriptionMessageError(val name: String, "
            "val message: String?) : BlueCatbirdTestDefsSubscriptionMessage",
            self.source,
        )
        self.assertIn(
            "BlueCatbirdTestDefsSubscriptionMessageUnexpected(frame.header.t, frame.payload)",
            self.source,
        )


if __name__ == "__main__":
    unittest.main()
