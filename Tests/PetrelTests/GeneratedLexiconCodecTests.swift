import Foundation
@testable import Petrel
import Testing

/// Wire-format behaviour of generated Lexicon types: what goes out is what the Lexicon and
/// data-model specifications say, and what comes in survives a round trip.
@Suite("Generated Lexicon codecs")
struct GeneratedLexiconCodecTests {
    private static let cidString = "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"

    private static func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    private static func jsonObject(_ value: some Encodable) throws -> NSDictionary {
        try jsonObject(JSONEncoder().encode(value))
    }

    // MARK: - cid-link (lex-4)

    /// DAG-CBOR tag 42 with a 37-byte byte string that starts with the 0x00 multibase prefix.
    private static let cborLinkPrefix = Data([0xD8, 0x2A, 0x58, 0x25, 0x00])

    @Test("A cid-link field is {\"$link\"} in JSON and tag 42 in DAG-CBOR")
    func cidLinkFieldUsesLinkRepresentation() throws {
        let json = Data("""
        {"action":"create","path":"app.bsky.feed.post/3jwdwj2ctlk26","cid":{"$link":"\(Self.cidString)"}}
        """.utf8)

        let op = try JSONDecoder().decode(ComAtprotoSyncSubscribeRepos.RepoOp.self, from: json)
        #expect(op.cid?.cid.string == Self.cidString)

        let encoded = try Self.jsonObject(op)
        #expect(encoded["cid"] as? NSDictionary == ["$link": Self.cidString])

        let cbor = try op.encodedDAGCBOR()
        #expect(cbor.range(of: Self.cborLinkPrefix) != nil, "cid-link must be CBOR tag 42")
    }

    @Test("A plain string in place of a cid-link is rejected")
    func cidLinkRejectsPlainString() {
        let json = Data("""
        {"action":"create","path":"app.bsky.feed.post/3jwdwj2ctlk26","cid":"\(Self.cidString)"}
        """.utf8)

        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(ComAtprotoSyncSubscribeRepos.RepoOp.self, from: json)
        }
    }

    @Test("A format:cid string stays a string in JSON and DAG-CBOR")
    func cidFormatStringStaysAString() throws {
        let ref = try ComAtprotoRepoStrongRef(
            uri: ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jwdwj2ctlk26"),
            cid: CID.parse(Self.cidString)
        )

        #expect(try Self.jsonObject(ref)["cid"] as? String == Self.cidString)
        #expect(try ref.encodedDAGCBOR().range(of: Data([0xD8, 0x2A])) == nil)
    }

    // MARK: - Blobs (lex-12)

    private static let rawCID = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"

    @Test("A blob round-trips in the current format")
    func blobRoundTrips() throws {
        let json = Data("""
        {"$type":"blob","ref":{"$link":"\(Self.rawCID)"},"mimeType":"image/png","size":4096}
        """.utf8)

        let blob = try JSONDecoder().decode(Blob.self, from: json)
        #expect(!blob.isLegacy)
        #expect(blob.ref?.cid.string == Self.rawCID)
        #expect(blob == Blob(ref: ATProtoLink(cid: try CID.parse(Self.rawCID)), mimeType: "image/png", size: 4096))
        #expect(try Self.jsonObject(blob) == Self.jsonObject(json))
        #expect(try blob.encodedDAGCBOR().range(of: Self.cborLinkPrefix) != nil)
    }

    /// The deprecated form must still be readable, and must be written back as it was read:
    /// it used to come back as `{"$type":"blob","mimeType":…,"size":0,"cid":…}`, which is
    /// neither the legacy nor a valid current blob.
    @Test("A legacy blob is written back exactly as it was read")
    func legacyBlobRoundTrips() throws {
        let json = Data("""
        {"cid":"\(Self.rawCID)","mimeType":"image/jpeg"}
        """.utf8)

        let blob = try JSONDecoder().decode(Blob.self, from: json)
        #expect(blob.isLegacy)
        #expect(blob.size < 0)
        #expect(blob.cid == Self.rawCID)
        #expect(blob.mimeType == "image/jpeg")

        #expect(try Self.jsonObject(blob) == Self.jsonObject(json))
        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: json)
        #expect(try blob.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR())

        // Inside a record too.
        let record = Data("""
        {"$type":"app.bsky.actor.profile","displayName":"old","avatar":{"cid":"\(Self.rawCID)","mimeType":"image/jpeg"}}
        """.utf8)
        let profile = try JSONDecoder().decode(AppBskyActorProfile.self, from: record)
        #expect(profile.avatar?.isLegacy == true)
        #expect(try Self.jsonObject(profile) == Self.jsonObject(record))
    }

    @Test("A malformed blob is rejected", arguments: [
        #"{"$type":"blob","mimeType":"image/png","size":10}"#,
        #"{"$type":"blob","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},"mimeType":"image/png","size":"10"}"#,
        #"{"$type":"blob","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},"mimeType":"image/png","size":-1}"#,
        #"{"$type":"blob","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},"mimeType":"","size":10}"#,
        #"{"$type":"blobby","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},"mimeType":"image/png","size":10}"#,
        #"{"$type":"blob","ref":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku","mimeType":"image/png","size":10}"#,
    ])
    func malformedBlobIsRejected(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Blob.self, from: Data(json.utf8))
        }
    }

    @Test("A negative size is never written in the current format")
    func negativeSizeIsNeverWritten() {
        let invalid = Blob(type: "blob", ref: nil, mimeType: "image/png", size: -5, cid: nil)
        #expect(throws: (any Error).self) { try JSONEncoder().encode(invalid) }
        #expect(throws: (any Error).self) { try invalid.encodedDAGCBOR() }
    }

    // MARK: - Undeclared fields (lex-15)

    private static let postWithFutureFields = Data("""
    {
      "$type": "app.bsky.feed.post",
      "text": "hello",
      "createdAt": "2026-07-15T12:00:00.000Z",
      "futureScalar": 7,
      "futureObject": {"nested": [1, "two", {"$link": "\(cidString)"}], "flag": true},
      "reply": {
        "root": {"uri": "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jwdwj2ctlk26", "cid": "\(cidString)", "futureRefField": "kept"},
        "parent": {"uri": "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jwdwj2ctlk26", "cid": "\(cidString)"}
      }
    }
    """.utf8)

    @Test("A record keeps fields its Lexicon does not declare, at every depth, in JSON")
    func undeclaredFieldsRoundTripThroughJSON() throws {
        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.postWithFutureFields)

        #expect(post.extraFields["futureScalar"] == .number(7))
        #expect(post.extraFields.keys.sorted() == ["futureObject", "futureScalar"])
        #expect(post.reply?.root.extraFields["futureRefField"] == .string("kept"))
        #expect(post.reply?.parent.extraFields.isEmpty == true)

        #expect(try Self.jsonObject(post) == Self.jsonObject(Self.postWithFutureFields))
    }

    @Test("A record with undeclared fields re-encodes to the same DAG-CBOR bytes, so the same CID")
    func undeclaredFieldsRoundTripThroughDAGCBOR() throws {
        // The reference encoding: the same JSON read as untyped data.
        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: Self.postWithFutureFields)
        let expected = try ATProtocolValueContainer.object(untyped).encodedDAGCBOR()

        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: Self.postWithFutureFields)
        let encoded = try post.encodedDAGCBOR()
        #expect(encoded == expected)

        let decodedAgain = try AppBskyFeedPost.decodedFromDAGCBOR(encoded)
        #expect(decodedAgain == post)
        #expect(try decodedAgain.encodedDAGCBOR() == expected)
    }

    @Test("Undeclared fields take part in equality and hashing")
    func undeclaredFieldsAffectEquality() throws {
        let plain = try AppBskyFeedPost(
            text: "hello",
            createdAt: #require(ATProtocolDate(iso8601String: "2026-07-15T12:00:00.000Z"))
        )
        let extended = AppBskyFeedPost(
            text: plain.text,
            createdAt: plain.createdAt,
            extraFields: ["futureScalar": .number(7)]
        )

        #expect(plain != extended)
        #expect(plain.hashValue != extended.hashValue)
        #expect(plain.extraFields.isEmpty)
    }

    /// v-3: the meta-schema Lexicon declares only `lexicon`, so `id`, `defs` and
    /// `description` used to be discarded when a published schema record was read.
    @Test("A published Lexicon schema record keeps id, defs and description")
    func lexiconSchemaRecordKeepsItsSchema() throws {
        let json = Data("""
        {
          "$type": "com.atproto.lexicon.schema",
          "lexicon": 1,
          "id": "com.example.kitchenSink",
          "description": "An example.",
          "defs": {"main": {"type": "record", "key": "tid", "record": {"type": "object", "properties": {}}}}
        }
        """.utf8)

        let schema = try JSONDecoder().decode(ComAtprotoLexiconSchema.self, from: json)
        #expect(schema.lexicon == 1)
        #expect(schema.extraFields["id"] == .string("com.example.kitchenSink"))
        #expect(schema.extraFields["description"] == .string("An example."))
        guard case let .object(defs)? = schema.extraFields["defs"] else {
            Issue.record("defs were not kept")
            return
        }
        #expect(defs.keys.sorted() == ["main"])
        #expect(try Self.jsonObject(schema) == Self.jsonObject(json))

        // Read through the untyped container (as getRecord returns it), it is still typed
        // and still complete.
        let container = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        let typed = try #require(container.decoded(ComAtprotoLexiconSchema.self))
        #expect(typed == schema)
        #expect(try Self.jsonObject(container) == Self.jsonObject(json))
    }

    // MARK: - Unions (v-4, lex-22)

    @Test("An open union keeps a variant it does not know and re-encodes it unchanged")
    func openUnionRoundTripsUnknownVariant() throws {
        let json = Data("""
        {
          "$type": "app.bsky.feed.post",
          "text": "hello",
          "createdAt": "2026-07-15T12:00:00.000Z",
          "embed": {"$type": "com.example.embed.hologram", "model": {"$link": "\(Self.cidString)"}, "scale": 3}
        }
        """.utf8)

        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: json)
        guard case let .unexpected(unknownEmbed)? = post.embed else {
            Issue.record("an unknown $type must decode as .unexpected, got \(String(describing: post.embed))")
            return
        }
        guard case let .unknownType(type, _) = unknownEmbed else {
            Issue.record("expected the raw value to be kept, got \(unknownEmbed)")
            return
        }
        #expect(type == "com.example.embed.hologram")
        #expect(try Self.jsonObject(post) == Self.jsonObject(json))

        let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: json)
        #expect(try post.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR())
    }

    @Test("An open union without $type is invalid")
    func openUnionRequiresType() {
        let json = Data("""
        {"$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-07-15T12:00:00.000Z","embed":{"scale":3}}
        """.utf8)

        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(AppBskyFeedPost.self, from: json)
        }
    }

    @Test("A known union variant decodes typed and writes its $type")
    func openUnionDecodesKnownVariant() throws {
        let json = Data("""
        {
          "$type": "app.bsky.feed.post",
          "text": "hello",
          "createdAt": "2026-07-15T12:00:00.000Z",
          "embed": {"$type": "app.bsky.embed.external", "external": {"uri": "https://example.com", "title": "t", "description": "d"}}
        }
        """.utf8)

        let post = try JSONDecoder().decode(AppBskyFeedPost.self, from: json)
        guard case let .appBskyEmbedExternal(external)? = post.embed else {
            Issue.record("expected a typed external embed, got \(String(describing: post.embed))")
            return
        }
        #expect(external.external.title == "t")
        #expect(try Self.jsonObject(post) == Self.jsonObject(json))
    }

    /// `com.atproto.repo.applyWrites` declares `writes` as a closed union.
    @Test("A closed union rejects a variant it does not declare")
    func closedUnionRejectsUnknownVariant() throws {
        let known = Data("""
        {"repo":"did:plc:ewvi7nxzyoun6zhxrhs64oiz","writes":[{"$type":"com.atproto.repo.applyWrites#delete","collection":"app.bsky.feed.post","rkey":"3jwdwj2ctlk26"}]}
        """.utf8)
        let input = try JSONDecoder().decode(ComAtprotoRepoApplyWrites.Input.self, from: known)
        guard case .comAtprotoRepoApplyWritesDelete = input.writes.first else {
            Issue.record("expected a delete write")
            return
        }

        let unknown = Data("""
        {"repo":"did:plc:ewvi7nxzyoun6zhxrhs64oiz","writes":[{"$type":"com.example.applyWrites#teleport","collection":"app.bsky.feed.post"}]}
        """.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ComAtprotoRepoApplyWrites.Input.self, from: unknown)
        }
    }

    // MARK: - Optional and nullable (lex-16)

    @Test("An optional, nullable property distinguishes absent, null and a value")
    func optionalNullablePropertyHasThreeStates() throws {
        func input(_ swapRecord: ATProtoNullable<CID>?) throws -> ComAtprotoRepoPutRecord.Input {
            try ComAtprotoRepoPutRecord.Input(
                repo: ATIdentifier(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz"),
                collection: NSID(nsidString: "app.bsky.actor.profile"),
                rkey: RecordKey(keyString: "self"),
                record: .object(["$type": .string("app.bsky.actor.profile")]),
                swapRecord: swapRecord
            )
        }

        let absent = try Self.jsonObject(input(nil))
        #expect(absent["swapRecord"] == nil)

        // "The record must not exist yet": an explicit null on the wire.
        let null = try Self.jsonObject(input(.null))
        #expect(null["swapRecord"] is NSNull)

        let cid = try CID.parse(Self.cidString)
        let value = try Self.jsonObject(input(.value(cid)))
        #expect(value["swapRecord"] as? String == Self.cidString)

        for state in [nil, .null, .value(cid)] as [ATProtoNullable<CID>?] {
            let original = try input(state)
            let decoded = try JSONDecoder().decode(
                ComAtprotoRepoPutRecord.Input.self,
                from: JSONEncoder().encode(original)
            )
            #expect(decoded.swapRecord == state)
        }
    }

    // MARK: - Strict decoding (lex-16)

    @Test("A malformed optional field is dropped by default and rejected by a strict decoder")
    func strictDecodingRejectsMalformedOptionalFields() throws {
        let json = Data("""
        {"$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-07-15T12:00:00.000Z","tags":"not-an-array"}
        """.utf8)

        let lenient = try JSONDecoder().decode(AppBskyFeedPost.self, from: json)
        #expect(lenient.tags == nil)

        #expect(throws: DecodingError.self) {
            try ATProtoDecoding.strictJSONDecoder().decode(AppBskyFeedPost.self, from: json)
        }
    }

    // MARK: - Tokens, record keys, permission sets (lex-11, v-6, lex-9)

    @Test("Token definitions are constants holding their fully-qualified value")
    func tokenDefinitionsAreConstants() {
        #expect(AppBskyGraphDefs.modlist == "app.bsky.graph.defs#modlist")
        #expect(AppBskyGraphDefs.curatelist == "app.bsky.graph.defs#curatelist")
        #expect(ComAtprotoModerationDefs.reasonSpam == "com.atproto.moderation.defs#reasonSpam")
        // The constant is what the open string type of the same Lexicon expects.
        #expect(AppBskyGraphDefs.ListPurpose(rawValue: AppBskyGraphDefs.modlist) == .appbskygraphdefsmodlist)
    }

    @Test("Record types expose the record key type of their collection")
    func recordTypesExposeTheirKeyType() {
        #expect(AppBskyFeedPost.recordKeyType == .tid)
        #expect(AppBskyFeedPost.recordKeyType.accepts("3jwdwj2ctlk26"))
        #expect(!AppBskyFeedPost.recordKeyType.accepts("self"))

        #expect(AppBskyActorProfile.recordKeyType == .literal("self"))
        #expect(AppBskyActorProfile.recordKeyType.accepts("self"))
        #expect(!AppBskyActorProfile.recordKeyType.accepts("3jwdwj2ctlk26"))

        #expect(ComAtprotoLexiconSchema.recordKeyType == .nsid)
        #expect(ComAtprotoLexiconSchema.recordKeyType.accepts("com.example.kitchenSink"))
        #expect(!ComAtprotoLexiconSchema.recordKeyType.accepts("not an nsid"))

        #expect(LexiconRecordKeyType(lexiconValue: "any").accepts("anything-goes_1.~"))
        #expect(!LexiconRecordKeyType(lexiconValue: "any").accepts("has/slash"))
        #expect(LexiconRecordKeyType(lexiconValue: "literal:self").lexiconValue == "literal:self")
    }

    @Test("A permission-set Lexicon is a typed constant that builds its include: scope")
    func permissionSetLexiconsAreTyped() throws {
        let set = AppBskyAuthCreatePosts.permissionSet
        #expect(set.nsid == "app.bsky.authCreatePosts")
        #expect(set.title == "Create Bluesky Posts")
        #expect(set.detail == "Can not update or delete posts.")

        let repo = try #require(set.permissions.first { $0.resource == "repo" })
        #expect(repo.collections.contains("app.bsky.feed.post"))
        #expect(repo.actions == ["create"])
        #expect(!repo.inheritAud)

        let rpc = try #require(set.permissions.first { $0.resource == "rpc" })
        #expect(rpc.methods.contains("app.bsky.video.uploadVideo"))
        #expect(rpc.inheritAud)
        #expect(rpc.audience == nil)
        #expect(set.requiresAudience)

        #expect(set.includeScope() == "include:app.bsky.authCreatePosts")
        // The example from the permission specification.
        let example = LexiconPermissionSet(nsid: "app.example.authFull", permissions: [])
        #expect(
            example.includeScope(audience: "did:web:api.example.com#svc_chat")
                == "include:app.example.authFull?aud=did:web:api.example.com%23svc_chat"
        )
    }

    @Test("Permission-set text falls back from a regional language to its base language")
    func permissionSetLocalization() {
        let set = LexiconPermissionSet(
            nsid: "com.example.authBasic",
            title: "Basic",
            titleLang: ["es": "Básico", "pt-BR": "Básico (BR)"],
            detail: "Detail",
            detailLang: ["es": "Detalle"],
            permissions: []
        )

        #expect(set.title(for: "pt-BR") == "Básico (BR)")
        #expect(set.title(for: "es-MX") == "Básico")
        #expect(set.title(for: "ja") == "Basic")
        #expect(set.detail(for: "es") == "Detalle")
        #expect(set.detail(for: "de") == "Detail")
    }
}
