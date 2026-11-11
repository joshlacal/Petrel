"""Generator behaviour for lexicons Petrel does not ship.

The corpus bundled with Petrel is uniform: four-segment NSIDs, no hyphens, no inline
objects, no union bodies. Third-party lexicons are not, so every shape the Lexicon
specification allows gets a test here. The same shapes are compiled and exercised at
runtime by the fixture module (Tests/LexiconFixture, Tests/PetrelLexiconFixtureTests).
"""
import asyncio
import contextlib
import io
import json
import os
import pathlib
import re
import sys
import tempfile
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

from base_code_generator import validate_lexicon_schema
from cycle_detector import CycleDetector
from main import (
    CORE_LEXICON_DIR,
    CORE_REFERENCE_TOKEN,
    build_namespace_hierarchy,
    generate_swift_from_lexicons_recursive,
    generate_swift_namespace_classes,
    generate_swift_overlay_namespaces,
    lower_camel,
    namespace_segments,
    resolve_reference_dirs,
)
from swift_code_generator import SwiftCodeGenerator
from utils import (
    convert_ref,
    convert_to_camel_case,
    namespace_type_name,
    namespace_type_path,
    normalize_ref,
    swift_member_name,
)


def lexicon(lexicon_id, defs):
    return {"lexicon": 1, "id": lexicon_id, "defs": defs}


def render(lexicon_id, defs, **options):
    with contextlib.redirect_stdout(io.StringIO()):
        return SwiftCodeGenerator(lexicon(lexicon_id, defs), **options).convert()


def object_def(properties=None, **extra):
    return {"type": "object", "properties": properties or {}, **extra}


QUERY = {"type": "query", "output": {"encoding": "application/json", "schema": object_def({"ok": {"type": "boolean"}})}}


class NamespaceDepthTests(unittest.TestCase):
    """lex-6: the namespace tree and the method extensions agree at any NSID depth."""

    def test_namespace_is_every_segment_but_the_name(self):
        self.assertEqual(namespace_segments("com.example.getRoot"), ["com", "example"])
        self.assertEqual(namespace_segments("app.bsky.feed.getTimeline"), ["app", "bsky", "feed"])
        self.assertEqual(
            namespace_segments("fm.example.alpha.feed.getPlay"),
            ["fm", "example", "alpha", "feed"],
        )

    def test_hierarchy_has_one_node_per_namespace_segment_and_none_for_the_name(self):
        hierarchy = build_namespace_hierarchy([
            "com.example.getRoot",
            "com.example.widget.getThing",
            "fm.example.alpha.beta.gamma.getDeep",
        ])
        self.assertEqual(
            hierarchy,
            {
                "com": {"example": {"widget": {}}},
                "fm": {"example": {"alpha": {"beta": {"gamma": {}}}}},
            },
        )

    def test_method_extension_targets_the_node_the_tree_declares(self):
        for lexicon_id, expected in (
            ("com.example.getRoot", "ATProtoClient.Com.Example"),
            ("com.example.widget.getThing", "ATProtoClient.Com.Example.Widget"),
            ("fm.example.alpha.beta.gamma.getDeep", "ATProtoClient.Fm.Example.Alpha.Beta.Gamma"),
        ):
            with self.subTest(lexicon_id=lexicon_id):
                generated = render(lexicon_id, {"main": QUERY})
                self.assertIn(f"extension {expected} {{", generated)
                tree = generate_swift_namespace_classes(build_namespace_hierarchy([lexicon_id]))
                path = expected.split(".")[1:]
                for depth, name in enumerate(path):
                    self.assertIn(f"{'    ' * depth}public struct {name}: Sendable {{", tree)
                # The name segment is a method, never a namespace.
                leaf = convert_to_camel_case(lexicon_id.split(".")[-1])
                self.assertNotIn(f"public struct {leaf}:", tree)

    def test_overlay_extends_the_deepest_existing_core_node(self):
        emitted = build_namespace_hierarchy(["com.atproto.extra.deep.getThing"])
        reference = build_namespace_hierarchy(["com.atproto.repo.getRecord"])
        code = generate_swift_overlay_namespaces(emitted, reference)
        self.assertIn("public extension ATProtoClient.Com.Atproto {", code)
        self.assertIn("var extra: Extra { Extra(networkService: networkService) }", code)
        self.assertIn("public struct Deep: Sendable {", code)


class IdentifierTests(unittest.TestCase):
    """Hyphens and leading digits are legal in NSID authority segments."""

    def test_type_names(self):
        self.assertEqual(convert_to_camel_case("com.my-site.feed.getPost"), "ComMySiteFeedGetPost")
        self.assertEqual(convert_to_camel_case("io.4ever.thing"), "Io4everThing")
        self.assertEqual(convert_to_camel_case("4chan.lex.thing"), "_4chanLexThing")
        self.assertEqual(convert_to_camel_case("my-def"), "MyDef")
        # Unchanged for every name in the bundled corpus.
        self.assertEqual(convert_to_camel_case("app.bsky.feed.getTimeline"), "AppBskyFeedGetTimeline")
        self.assertEqual(convert_to_camel_case("viewerState"), "ViewerState")

    def test_member_names(self):
        self.assertEqual(swift_member_name("created-at"), "createdAt")
        self.assertEqual(swift_member_name("cid-link"), "cidLink")
        self.assertEqual(swift_member_name("4ever"), "_4ever")
        self.assertEqual(swift_member_name("createdAt"), "createdAt")
        self.assertEqual(swift_member_name("snake_case"), "snake_case")
        self.assertEqual(swift_member_name("URL"), "URL")

    def test_namespace_names_never_collide_with_their_accessor_or_a_reserved_type(self):
        self.assertEqual(namespace_type_name("my-site"), "MySite")
        self.assertEqual(lower_camel("my-site"), "mySite")
        # `_4ever` for both the struct and the property would be ambiguous.
        self.assertEqual(namespace_type_name("4ever"), "N4ever")
        self.assertEqual(lower_camel("4ever"), "_4ever")
        self.assertEqual(namespace_type_name("type"), "Type_")
        self.assertEqual(namespace_type_name("protocol"), "Protocol_")
        self.assertEqual(lower_camel("default"), "`default`")
        self.assertEqual(
            namespace_type_path("io.my-site.4ever.type.getThing"),
            "Io.MySite.N4ever.Type_",
        )

    def test_whole_nsid_and_ref_agree_on_the_container_name(self):
        nsid = "io.my-site.4ever.deep.submitThing"
        self.assertEqual(convert_ref(f"{nsid}#thing"), f"{convert_to_camel_case(nsid)}.Thing")
        self.assertEqual(convert_ref(nsid), convert_to_camel_case(nsid))

    def test_hyphenated_property_keeps_its_wire_name(self):
        validate_lexicon_schema(lexicon("com.example.thing", {"main": object_def({"cid-link": {"type": "cid-link"}})}))
        generated = render(
            "com.example.thing",
            {"main": object_def({"created-at": {"type": "string"}, "default": {"type": "boolean"}}, required=["created-at"])},
        )
        self.assertIn("public let createdAt: String", generated)
        self.assertIn('case createdAt = "created-at"', generated)
        self.assertIn('map = map.adding(key: "created-at", value: createdAtValue)', generated)
        self.assertIn('["$type", "created-at", "default"]', generated)
        self.assertIn("public let `default`: Bool?", generated)
        self.assertRegex(generated, r"case `default`\n")

    def test_property_names_that_could_escape_a_literal_are_still_rejected(self):
        for name in ('a"b', "a b", "a\\(b)", "a\nb", ""):
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    validate_lexicon_schema(lexicon("com.example.thing", {"main": object_def({name: {"type": "string"}})}))

    def test_query_parameter_with_a_non_identifier_name_declares_its_wire_name(self):
        generated = render(
            "com.example.getThing",
            {"main": {"type": "query", "parameters": {"type": "params", "properties": {
                "max-age": {"type": "integer"}, "limit": {"type": "integer"}}}}},
        )
        self.assertIn("public let maxAge: Int?", generated)
        self.assertIn('["maxAge": "max-age"]', generated)
        plain = render(
            "com.example.getThing",
            {"main": {"type": "query", "parameters": {"type": "params", "properties": {"limit": {"type": "integer"}}}}},
        )
        self.assertNotIn("queryParameterNames", plain)


class RefNormalizationTests(unittest.TestCase):
    """lex-19: `nsid#main` and `nsid` are the same ref; `$type` never carries `#main`."""

    def test_normalize_ref(self):
        self.assertEqual(normalize_ref("#post", "com.example.feed"), "com.example.feed#post")
        self.assertEqual(normalize_ref("#main", "com.example.feed"), "com.example.feed")
        self.assertEqual(normalize_ref("com.example.note#main", "com.example.feed"), "com.example.note")
        self.assertEqual(normalize_ref("com.example.note", "com.example.feed"), "com.example.note")
        self.assertEqual(normalize_ref("com.example.defs#view", "com.example.feed"), "com.example.defs#view")

    def test_union_variant_written_with_main_resolves_to_the_container(self):
        generated = render(
            "com.example.feed",
            {"main": object_def({"item": {"type": "union", "refs": ["com.example.note#main", "#main", "com.example.defs#view"]}})},
        )
        self.assertIn("case comExampleNote(ComExampleNote)", generated)
        self.assertIn("case comExampleFeed(ComExampleFeed)", generated)
        self.assertIn('case "com.example.note":', generated)
        self.assertIn('case "com.example.feed":', generated)
        self.assertNotIn("#main", generated)
        self.assertNotIn(".Main", generated)

    def test_subscription_message_type_ids_are_normalized(self):
        generated = render(
            "com.example.subscribe",
            {
                "main": {"type": "subscription", "message": {"schema": {"type": "union", "refs": ["#created", "com.example.note#main"]}}},
                "created": object_def({"seq": {"type": "integer"}}),
            },
        )
        self.assertIn('"com.example.subscribe#created",', generated)
        self.assertIn('"com.example.note",', generated)
        self.assertIn("public enum Message: Codable, Sendable, XRPCSubscriptionMessage {", generated)


class UnionTests(unittest.TestCase):
    def test_open_union_keeps_unknown_variants_and_closed_union_rejects_them(self):
        defs = {
            "main": object_def({
                "open": {"type": "union", "refs": ["#a"]},
                "closed": {"type": "union", "closed": True, "refs": ["#a", "#b"]},
            }),
            "a": object_def(),
            "b": object_def(),
        }
        generated = render("com.example.thing", defs)
        open_union = generated[generated.index("public enum ComExampleThingOpenUnion"):]
        open_union = open_union[: open_union.index("\n}\n")]
        closed_union = generated[generated.index("public enum ComExampleThingClosedUnion"):]
        closed_union = closed_union[: closed_union.index("\n}\n")]

        self.assertIn("case unexpected(ATProtocolValueContainer)", open_union)
        self.assertIn("self = .unexpected(unknownValue)", open_union)
        self.assertNotIn("unexpected", closed_union)
        self.assertIn("is not a member of this closed union", closed_union)

    def test_closed_union_with_one_member_has_no_unreachable_default(self):
        generated = render(
            "com.example.thing",
            {"main": object_def({"only": {"type": "union", "closed": True, "refs": ["#a"]}}), "a": object_def()},
        )
        union = generated[generated.index("public enum ComExampleThingOnlyUnion"):]
        equality = union[union.index("public static func =="): union.index("public func isEqual")]
        self.assertNotIn("default:", equality)

    def test_empty_closed_union_is_an_invalid_schema(self):
        with self.assertRaisesRegex(ValueError, "closed union .* has no refs"):
            render("com.example.thing", {"main": object_def({"none": {"type": "union", "closed": True, "refs": []}})})

    def test_union_output_and_input_are_the_union_itself(self):
        """lex-10: a union body used to generate an empty struct and drop the body."""
        generated = render(
            "com.example.submit",
            {
                "main": {
                    "type": "procedure",
                    "input": {"encoding": "application/json", "schema": {"type": "union", "refs": ["#a", "#b"]}},
                    "output": {"encoding": "application/json", "schema": {"type": "union", "refs": ["#a"]}},
                },
                "a": object_def(),
                "b": object_def(),
            },
        )
        self.assertIn("public typealias Input = InputUnion", generated)
        self.assertIn("public typealias Output = OutputUnion", generated)
        self.assertIn("public enum InputUnion:", generated)
        self.assertIn("public enum OutputUnion:", generated)
        self.assertNotIn("public struct Input", generated)
        self.assertNotIn("public struct Output", generated)
        self.assertIn("try JSONEncoder().encode(input)", generated)
        self.assertIn("JSONDecoder().decode(ComExampleSubmit.Output.self, from: responseData)", generated)

    def test_ref_input_is_the_referenced_type_not_a_wrapper(self):
        """v-1: `struct Input { data: Ref }` put `{"data": {...}}` on the wire."""
        generated = render(
            "com.example.submit",
            {
                "main": {"type": "procedure", "input": {"encoding": "application/json", "schema": {"type": "ref", "ref": "#thing"}}},
                "thing": object_def({"name": {"type": "string"}}),
            },
        )
        self.assertIn("public typealias Input = Thing", generated)
        self.assertNotIn("public let data:", generated)
        self.assertIn("input: ComExampleSubmit.Input", generated)


class ObjectShapeTests(unittest.TestCase):
    def test_inline_object_is_a_nested_struct_named_after_its_owner(self):
        """lex-23: an inline object used to be an untyped dictionary."""
        generated = render(
            "com.example.defs",
            {"view": object_def({
                "meta": object_def({"label": {"type": "string"}, "origin": object_def({"country": {"type": "string"}})}, required=["label"]),
                "parts": {"type": "array", "items": object_def({"sku": {"type": "string"}})},
                "bag": {"type": "object"},
            }, required=["meta"])},
        )
        self.assertIn("public let meta: ViewMeta", generated)
        self.assertIn("public let parts: [ViewParts]?", generated)
        self.assertIn("public struct ViewMeta: ATProtocolCodable, ATProtocolValue {", generated)
        self.assertIn("public let origin: ViewMetaOrigin?", generated)
        self.assertIn("public struct ViewMetaOrigin: ATProtocolCodable, ATProtocolValue {", generated)
        self.assertIn("public struct ViewParts: ATProtocolCodable, ATProtocolValue {", generated)
        # No declared properties: an open dictionary, not an empty struct.
        self.assertIn("public let bag: [String: ATProtocolValueContainer]?", generated)
        # An inline object has no name, so it has no `$type`.
        meta = generated[generated.index("public struct ViewMeta:"):]
        meta = meta[: meta.index("private enum CodingKeys")]
        self.assertNotIn("typeIdentifier", meta)

    def test_objects_and_records_keep_undeclared_fields(self):
        """lex-15."""
        generated = render(
            "com.example.note",
            {
                "main": {"type": "record", "key": "tid", "record": object_def({"text": {"type": "string"}}, required=["text"])},
                "detail": object_def({"more": {"type": "string"}}),
            },
        )
        self.assertEqual(generated.count("public let extraFields: [String: ATProtocolValueContainer]"), 2)
        self.assertEqual(generated.count("ATProtocolValueContainer.decodeExtraFields(from: decoder, knownKeys: Self.knownFieldKeys)"), 2)
        self.assertEqual(generated.count("ATProtocolValueContainer.encodeExtraFields(extraFields, to: encoder)"), 2)
        self.assertEqual(generated.count("ATProtocolValueContainer.addingExtraFields(extraFields, to: map)"), 2)
        self.assertIn('private static let knownFieldKeys: Swift.Set<String> = ["$type", "text"]', generated)
        self.assertIn("hasher.combine(extraFields)", generated)
        self.assertIn("return self.extraFields == other.extraFields", generated)

    def test_xrpc_bodies_do_not_carry_undeclared_fields(self):
        generated = render(
            "com.example.submit",
            {"main": {
                "type": "procedure",
                "input": {"encoding": "application/json", "schema": object_def({"a": {"type": "string"}})},
                "output": {"encoding": "application/json", "schema": object_def({"b": {"type": "string"}})},
            }},
        )
        self.assertNotIn("extraFields", generated)

    def test_a_declared_property_named_extraFields_wins_the_name(self):
        generated = render("com.example.thing", {"main": object_def({"extraFields": {"type": "string"}})})
        self.assertIn("public let extraFields: String?", generated)
        self.assertIn("public let undeclaredFields: [String: ATProtocolValueContainer]", generated)

    def test_record_writes_its_type_and_a_named_object_does_not(self):
        """lex-22: data reached through a plain ref should not carry `$type`."""
        generated = render(
            "com.example.note",
            {
                "main": {"type": "record", "key": "literal:self", "record": object_def({"text": {"type": "string"}})},
                "detail": object_def({"more": {"type": "string"}}),
            },
        )
        record, detail = generated.split("public struct Detail:", 1)
        self.assertIn("try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)", record)
        self.assertIn('map = map.adding(key: "$type", value: Self.typeIdentifier)', record)
        self.assertNotIn("forKey: .typeIdentifier", detail)
        self.assertNotIn('key: "$type"', detail)
        self.assertIn('public static let typeIdentifier = "com.example.note#detail"', detail)
        self.assertIn('LexiconRecordKeyType(lexiconValue: "literal:self")', record)

    def test_optional_and_nullable_property_is_tri_state(self):
        """lex-16: absent, null and a value are three wire states."""
        generated = render(
            "com.example.thing",
            {"main": object_def(
                {"swap": {"type": "string", "format": "cid"}, "must": {"type": "string"}, "may": {"type": "string"}},
                required=["must"], nullable=["swap", "must"],
            )},
        )
        self.assertIn("public let swap: ATProtoNullable<CID>?", generated)
        self.assertIn("swap: ATProtoNullable<CID>? = nil,", generated)
        self.assertIn("if try container.decodeNil(forKey: .swap) {", generated)
        self.assertIn("try container.encodeIfPresent(self.swap, forKey: .swap)", generated)
        # Required and nullable stays a plain optional whose key must be present.
        self.assertIn("public let must: String?", generated)
        self.assertIn("guard container.contains(.must) else {", generated)
        # Optional and not nullable: null is rejected in strict mode.
        self.assertIn("try container.decodeIfPresent(String.self, forKey: .may, rejectingNull: strict)", generated)

    def test_cid_link_is_a_link_and_a_cid_format_string_is_a_string(self):
        """lex-4."""
        generated = render(
            "com.example.thing",
            {
                "main": object_def({
                    "link": {"type": "cid-link"},
                    "links": {"type": "array", "items": {"type": "cid-link"}},
                    "viaRef": {"type": "ref", "ref": "#head"},
                    "text": {"type": "string", "format": "cid"},
                }),
                "head": {"type": "cid-link"},
            },
        )
        self.assertIn("public let link: ATProtoLink?", generated)
        self.assertIn("public let links: [ATProtoLink]?", generated)
        self.assertIn("public let viaRef: ATProtoLink?", generated)
        self.assertIn("public let text: CID?", generated)
        self.assertIn("public typealias Head = ATProtoLink", generated)

    def test_types_outside_the_lexicon_language_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "'number', which is not a Lexicon field type"):
            render("com.example.thing", {"main": object_def({"ratio": {"type": "number"}})})

    def test_unknown_named_didDoc_is_untyped_unless_the_manifest_overrides_it(self):
        defs = {"main": {"type": "query", "output": {"encoding": "application/json", "schema": object_def({"didDoc": {"type": "unknown"}})}}}
        self.assertIn("public let didDoc: ATProtocolValueContainer?", render("com.example.getSession", defs))
        overridden = render(
            "com.example.getSession", defs, property_type_overrides={"Output.didDoc": "DIDDocument"},
        )
        self.assertIn("public let didDoc: DIDDocument?", overridden)

    def test_an_override_that_matches_nothing_fails_generation(self):
        with self.assertRaisesRegex(ValueError, "match no generated property"):
            render("com.example.thing", {"main": object_def({"a": {"type": "unknown"}})},
                   property_type_overrides={"Output.didDoc": "DIDDocument"})


class NonObjectDefinitionTests(unittest.TestCase):
    def test_token_definitions_are_constants(self):
        """lex-11."""
        generated = render(
            "com.example.defs",
            {
                "statusActive": {"type": "token", "description": "In service."},
                "default": {"type": "token"},
                "typeIdentifier": {"type": "token"},
            },
        )
        self.assertIn('/// In service.\npublic static let statusActive = "com.example.defs#statusActive"', generated)
        self.assertIn('public static let `default` = "com.example.defs#default"', generated)
        self.assertIn('public static let typeIdentifierToken = "com.example.defs#typeIdentifier"', generated)

    def test_siblings_of_a_non_object_main_are_generated(self):
        """v-5: they used to be dropped."""
        for main in (
            {"type": "token"},
            {"type": "string", "knownValues": ["a"]},
            {"type": "array", "items": {"type": "string"}},
            {"type": "permission-set", "permissions": []},
        ):
            with self.subTest(main=main["type"]):
                generated = render("com.example.kind", {"main": main, "detail": object_def({"note": {"type": "string"}})})
                self.assertIn("public struct Detail: ATProtocolCodable, ATProtocolValue {", generated)

    def test_scalar_and_array_definitions_have_a_type_refs_can_name(self):
        generated = render(
            "com.example.defs",
            {
                "sizes": {"type": "array", "items": {"type": "integer"}},
                "count": {"type": "integer"},
                "flag": {"type": "boolean"},
                "holder": object_def({"sizes": {"type": "ref", "ref": "#sizes"}}),
            },
        )
        self.assertIn("public typealias Sizes = [Int]", generated)
        self.assertIn("public typealias Count = Int", generated)
        self.assertIn("public typealias Flag = Bool", generated)
        self.assertIn("public let sizes: Sizes?", generated)

    def test_ref_to_a_scalar_main_resolves_to_its_alias(self):
        detector = CycleDetector()
        detector.add_type("com.example.kind", "main", {"type": "string", "knownValues": ["a"]})
        generated = render(
            "com.example.thing",
            {"main": object_def({"kind": {"type": "ref", "ref": "com.example.kind"}})},
            cycle_detector=detector,
        )
        self.assertIn("public let kind: ComExampleKind.Main?", generated)

    def test_permission_set_is_a_typed_constant(self):
        """lex-9: it used to be an empty stub."""
        generated = render(
            "com.example.authBasic",
            {"main": {
                "type": "permission-set",
                "title": "Basic", "title:es": "Básico",
                "detail": 'Say "hi"',
                "permissions": [
                    {"type": "permission", "resource": "repo", "collection": ["com.example.note"], "action": ["create"]},
                    {"type": "permission", "resource": "rpc", "lxm": ["com.example.getThing"], "inheritAud": True},
                    {"type": "permission", "resource": "hologram", "beam": "wide"},
                ],
            }},
        )
        self.assertIn("public static let permissionSet = LexiconPermissionSet(", generated)
        self.assertIn('nsid: "com.example.authBasic",', generated)
        self.assertIn('title: "Basic",', generated)
        self.assertIn('titleLang: ["es": "Básico"],', generated)
        self.assertIn('detail: "Say \\"hi\\"",', generated)
        self.assertIn(
            'LexiconPermission(resource: "repo", parameters: ["collection": ["com.example.note"], "action": ["create"]], inheritAud: false)',
            generated,
        )
        self.assertIn(
            'LexiconPermission(resource: "rpc", parameters: ["lxm": ["com.example.getThing"]], inheritAud: true)',
            generated,
        )
        # A resource this generator does not know is kept, not dropped.
        self.assertIn('LexiconPermission(resource: "hologram", parameters: ["beam": ["wide"]], inheritAud: false)', generated)


class OverlayManifestTests(unittest.TestCase):
    def test_petrel_core_token_resolves_to_the_bundled_lexicons_and_their_exclusions(self):
        directories, exclude = resolve_reference_dirs([CORE_REFERENCE_TOKEN, "other/dir"], ("com.example.private",))
        self.assertEqual(directories, [CORE_LEXICON_DIR, "other/dir"])
        self.assertTrue(os.path.isdir(CORE_LEXICON_DIR))
        self.assertIn("com.example.private", exclude)
        # What the core package itself does not generate cannot be referenced.
        core_manifest = json.loads((GENERATOR_DIR / "manifests" / "petrel-core.json").read_text())
        for namespace in core_manifest["lexicons"]["exclude_namespaces"]:
            self.assertIn(namespace, exclude)

    def test_reference_list_without_the_token_is_left_alone(self):
        self.assertEqual(resolve_reference_dirs(["a", "b"], ("x",)), (["a", "b"], ("x",)))

    def test_overlay_generation_resolves_refs_into_the_bundled_lexicons(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            lexicons = root / "lexicons"
            lexicons.mkdir()
            (lexicons / "listPins.json").write_text(json.dumps(lexicon(
                "com.example.pins.listPins",
                {"main": {"type": "query", "output": {"encoding": "application/json", "schema": object_def(
                    {"pins": {"type": "array", "items": {"type": "ref", "ref": "com.atproto.repo.strongRef"}}},
                    required=["pins"],
                )}}},
            )))
            output = root / "Generated"
            with contextlib.redirect_stdout(io.StringIO()):
                asyncio.run(generate_swift_from_lexicons_recursive(
                    [str(lexicons)], str(output),
                    exclude_namespaces=(), reference_dirs=[CORE_REFERENCE_TOKEN],
                    overlay=True, package_name="Pins",
                ))
            generated = (output / "Lexicons" / "Com" / "Example" / "ComExamplePinsListPins.swift").read_text()
            self.assertIn("import Petrel", generated)
            self.assertIn("public let pins: [ComAtprotoRepoStrongRef]", generated)
            namespaces = (output / "Client" / "ATProtoClient+Pins.swift").read_text()
            # `com` exists in Petrel; only the new nodes are declared.
            self.assertIn("public extension ATProtoClient.Com {", namespaces)
            self.assertIn("public struct Example: Sendable {", namespaces)
            self.assertNotIn("struct Atproto", namespaces)
            registration = (output / "Client" / "PinsLexicons.swift").read_text()
            self.assertNotIn("registerDecoder", registration.split("public static func register()")[1].split("}")[0])

    def test_only_objects_and_records_are_registered_for_typed_decoding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            lexicons = root / "lexicons"
            lexicons.mkdir()
            (lexicons / "defs.json").write_text(json.dumps(lexicon(
                "com.example.pins.defs",
                {
                    "pin": object_def({"note": {"type": "string"}}),
                    "sizes": {"type": "array", "items": {"type": "integer"}},
                    "either": {"type": "union", "refs": ["#pin"]},
                    "kind": {"type": "token"},
                },
            )))
            output = root / "Generated"
            with contextlib.redirect_stdout(io.StringIO()):
                asyncio.run(generate_swift_from_lexicons_recursive(
                    [str(lexicons)], str(output),
                    exclude_namespaces=(), reference_dirs=[CORE_REFERENCE_TOKEN],
                    overlay=True, package_name="Pins",
                ))
            registration = (output / "Client" / "PinsLexicons.swift").read_text()
            self.assertEqual(re.findall(r'forType: "([^"]+)"', registration), ["com.example.pins.defs#pin"])


class FixtureManifestTests(unittest.TestCase):
    """The fixture module is generated from a manifest a third party could have written."""

    def test_fixture_manifest_is_an_overlay_on_the_bundled_lexicons(self):
        manifest = json.loads((REPOSITORY_ROOT / "Tests" / "LexiconFixture" / "lexgen.json").read_text())
        self.assertEqual(manifest["package"]["kind"], "overlay")
        self.assertEqual(manifest["lexicons"]["reference"], [CORE_REFERENCE_TOKEN])
        self.assertNotIn("kotlin", manifest)

    def test_fixture_includes_the_official_catalog_lexicons(self):
        catalog = REPOSITORY_ROOT / "Tests" / "LexiconFixture" / "lexicons" / "catalog"
        ids = sorted(json.loads(path.read_text())["id"] for path in catalog.glob("*.json"))
        self.assertEqual(
            ids,
            [
                "example.lexicon.permissionset",
                "example.lexicon.procedure",
                "example.lexicon.query",
                "example.lexicon.record",
                "example.lexicon.subscription",
            ],
        )

    def test_every_fixture_lexicon_generates(self):
        lexicons = REPOSITORY_ROOT / "Tests" / "LexiconFixture" / "lexicons"
        for path in sorted(lexicons.rglob("*.json")):
            with self.subTest(lexicon=path.name):
                document = json.loads(path.read_text())
                with contextlib.redirect_stdout(io.StringIO()):
                    generated = SwiftCodeGenerator(document).convert()
                self.assertIn(f'typeIdentifier = "{document["id"]}"', generated)


if __name__ == "__main__":
    unittest.main()
