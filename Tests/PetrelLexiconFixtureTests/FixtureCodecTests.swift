import Foundation
import Petrel
import PetrelLexiconFixture
import Testing

/// Codec behaviour of a module generated from third-party lexicons (`Tests/LexiconFixture`).
///
/// The fixture exists to prove that generator output for lexicons Petrel does not ship
/// compiles and is wire-correct: NSIDs of any depth, hyphenated and digit-led segments,
/// inline objects, tokens, permission sets, union bodies, `#main` refs and closed unions.
@Suite("Third-party lexicon fixture: codecs")
struct FixtureCodecTests {
    private static let cidString = "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"

    private static func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    private static func jsonObject(_ value: some Encodable) throws -> NSDictionary {
        try jsonObject(JSONEncoder().encode(value))
    }

    private static let gadgetJSON = Data("""
    {
      "id": "3jwdwj2ctlk26",
      "meta": {"label": "left", "weight": 3, "origin": {"country": "NZ", "futureOriginField": 1}, "futureMetaField": "kept"},
      "parts": [{"sku": "a-1", "quantity": 2}, {"sku": "b-2"}],
      "bag": {"anything": [1, 2], "goes": {"here": true}},
      "head": {"$link": "\(cidString)"},
      "payload": {"$bytes": "aGVsbG8="},
      "status": "com.example.widget.defs#statusActive",
      "grade": "b",
      "kind": "complex",
      "retiredAt": null,
      "attachment": {"$type": "com.example.widget.note", "text": "attached", "created-at": "2026-07-15T12:00:00.000Z"},
      "decision": {"$type": "com.example.widget.defs#rejected", "reason": "scratched"},
      "sizes": [1, 2, 3],
      "extra": {"free": "form"}
    }
    """.utf8)

    @Test("Inline objects are typed structs, at every depth and inside arrays")
    func inlineObjectsAreTyped() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)

        #expect(gadget.meta.label == "left")
        #expect(gadget.meta.weight == 3)
        #expect(gadget.meta.origin?.country == "NZ")
        #expect(gadget.parts?.map(\.sku) == ["a-1", "b-2"])
        #expect(gadget.parts?.first?.quantity == 2)
        // Inline objects keep undeclared fields too.
        #expect(gadget.meta.extraFields["futureMetaField"] == .string("kept"))
        #expect(gadget.meta.origin?.extraFields["futureOriginField"] == .number(1))
        // An object with no declared properties is an open dictionary.
        #expect(gadget.bag?.keys.sorted() == ["anything", "goes"])
    }

    @Test("A gadget round-trips through JSON without gaining or losing a field")
    func gadgetRoundTripsThroughJSON() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)
        #expect(try Self.jsonObject(gadget) == Self.jsonObject(Self.gadgetJSON))
    }

    @Test("A gadget re-encodes to the DAG-CBOR bytes of the same data read untyped")
    func gadgetRoundTripsThroughDAGCBOR() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)
        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: Self.gadgetJSON)

        #expect(try gadget.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR())
    }

    @Test("cid-link, bytes and string-typed definitions use their wire representations")
    func scalarRepresentations() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)

        #expect(gadget.head.cid.string == Self.cidString)
        #expect(gadget.payload?.data == Data("hello".utf8))
        #expect(gadget.status?.rawValue == ComExampleWidgetDefs.statusActive)
        #expect(gadget.grade == .value_b)
        // A ref to a lexicon whose `main` is a string resolves to that string type.
        #expect(gadget.kind == ComExampleWidgetKind.Main.complex)
        #expect(gadget.sizes == [1, 2, 3])
    }

    @Test("An optional, nullable property keeps null and absent apart")
    func optionalNullablePropertyKeepsNull() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)
        #expect(gadget.retiredAt == .null)
        #expect(gadget.replacedBy == nil)
        #expect(try Self.jsonObject(gadget)["retiredAt"] is NSNull)
        #expect(try Self.jsonObject(gadget)["replacedBy"] == nil)
    }

    @Test("A union ref written with or without #main names the same type, and $type never carries #main")
    func mainRefsAreNormalized() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)
        guard case let .comExampleWidgetNote(note)? = gadget.attachment else {
            Issue.record("expected the note variant, got \(String(describing: gadget.attachment))")
            return
        }
        #expect(note.text == "attached")

        let attachment = try #require(try Self.jsonObject(gadget)["attachment"] as? NSDictionary)
        #expect(attachment["$type"] as? String == "com.example.widget.note")
    }

    @Test("A closed union decodes its members and rejects anything else")
    func closedUnionIsClosed() throws {
        let gadget = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: Self.gadgetJSON)
        guard case let .comExampleWidgetDefsRejected(rejected)? = gadget.decision else {
            Issue.record("expected the rejected variant")
            return
        }
        #expect(rejected.reason == "scratched")

        let outsider = Data("""
        {"id":"3jwdwj2ctlk26","meta":{"label":"x"},"head":{"$link":"\(Self.cidString)"},"decision":{"$type":"com.example.widget.defs#deferred"}}
        """.utf8)
        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetDefs.Gadget.self, from: outsider)
        }
    }

    @Test("A named object does not write $type unless it is a union member")
    func refObjectsDoNotWriteType() throws {
        let ref = try ComExampleWidgetDefs.GadgetRef(
            uri: ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.widget.note/3jwdwj2ctlk26")
        )
        #expect(try Self.jsonObject(ref)["$type"] == nil)

        let asUnionMember = try Self.jsonObject(ComExampleWidgetDefs.GadgetAttachmentUnion(ref))
        #expect(asUnionMember["$type"] as? String == "com.example.widget.defs#gadgetRef")
    }

    @Test("Property names that are not Swift identifiers keep their wire name")
    func awkwardPropertyNames() throws {
        let json = Data("""
        {"$type":"com.example.widget.note","text":"hi","created-at":"2026-07-15T12:00:00.000Z","default":true,"extraFields":"declared","container":"declared too","future":1}
        """.utf8)

        let note = try ATProtoDecoding.strictJSONDecoder().decode(ComExampleWidgetNote.self, from: json)
        #expect(note.createdAt.iso8601String == "2026-07-15T12:00:00.000Z")
        #expect(note.default == true)
        // The Lexicon's own `extraFields` property wins the name; undeclared fields move aside.
        #expect(note.extraFields == "declared")
        #expect(note.container == "declared too")
        #expect(note.undeclaredFields == ["future": .number(1)])

        #expect(try Self.jsonObject(note) == Self.jsonObject(json))
        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: json)
        #expect(try note.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR())
    }

    @Test("Tokens are constants, including one named like a generated member")
    func tokens() {
        #expect(ComExampleWidgetDefs.statusActive == "com.example.widget.defs#statusActive")
        #expect(ComExampleWidgetDefs.statusRetired == "com.example.widget.defs#statusRetired")
        #expect(ComExampleWidgetDefs.typeIdentifierToken == "com.example.widget.defs#typeIdentifier")
        #expect(ComExampleWidgetDefs.typeIdentifier == "com.example.widget.defs")
        #expect(ExampleLexiconRecord.demoToken == "example.lexicon.record#demoToken")
    }

    @Test("A lexicon whose main is not an object still generates its sibling definitions")
    func siblingsOfANonObjectMain() throws {
        let detail = ComExampleWidgetKind.Detail(note: "n")
        #expect(try Self.jsonObject(detail) == ["note": "n"])
        #expect(ComExampleWidgetKind.Main.predefinedValues.map(\.rawValue) == ["simple", "complex"])
    }

    @Test("A permission set keeps translations and resources Petrel does not know")
    func permissionSet() {
        let set = ComExampleAuthBasic.permissionSet
        #expect(set.nsid == "com.example.authBasic")
        #expect(set.title(for: "es-AR") == "Acceso a widgets")
        #expect(set.detail(for: "es") == "Leer y escribir notas de widgets.")
        #expect(set.title(for: "fr") == "Widget access")
        #expect(set.permissions.map(\.resource) == ["repo", "rpc", "hologram"])
        #expect(set.permissions[2].parameters == ["beam": ["wide"]])
        #expect(set.requiresAudience)
        #expect(
            set.includeScope(audience: "did:web:widgets.example.com#widget_api")
                == "include:com.example.authBasic?aud=did:web:widgets.example.com%23widget_api"
        )

        // The official catalog permission set.
        #expect(ExampleLexiconPermissionset.permissionSet.nsid == "example.lexicon.permissionset")
        #expect(!ExampleLexiconPermissionset.permissionSet.permissions.isEmpty)
    }

    @Test("Registering the module makes its types decode inside untyped data")
    func registrationEnablesTypedDispatch() throws {
        LexiconFixtureLexicons.register()

        let json = Data("""
        {"$type":"com.example.widget.note","text":"hi","created-at":"2026-07-15T12:00:00.000Z","future":1}
        """.utf8)
        let container = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        let note = try #require(container.decoded(ComExampleWidgetNote.self))
        #expect(note.text == "hi")
        #expect(try Self.jsonObject(container) == Self.jsonObject(json))
    }

    @Test("Record types expose their record key type")
    func recordKeyTypes() {
        #expect(ComExampleWidgetNote.recordKeyType == .tid)
        #expect(ExampleLexiconRecord.recordKeyType == LexiconRecordKeyType(lexiconValue: "literal:demo"))
    }
}
