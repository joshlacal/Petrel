import Foundation
import Petrel
import PetrelLexicon
import Testing

/// The Lexicon documents compiled into `PetrelLexicon`, and validation of generated values
/// against them.
@Suite("Lexicon: bundled catalog")
struct BundledCatalogTests {
    private static func post(text: String, langs: [String]? = nil) throws -> AppBskyFeedPost {
        try AppBskyFeedPost(
            text: text,
            langs: langs?.map { LanguageCodeContainer(languageCode: $0) },
            createdAt: #require(ATProtocolDate(iso8601String: "2026-07-15T12:00:00.000Z"))
        )
    }

    @Test("The bundled catalog holds the Lexicons Petrel generates types for, and is closed under reference")
    func bundledCatalogLoads() throws {
        let catalog = try LexiconCatalog.bundled()

        #expect(catalog.nsids.count >= 370)
        for nsid in [
            AppBskyFeedPost.typeIdentifier,
            AppBskyActorProfile.typeIdentifier,
            ComAtprotoRepoCreateRecord.typeIdentifier,
            ComAtprotoSyncSubscribeRepos.typeIdentifier,
            ChatBskyConvoSendMessage.typeIdentifier,
            AppBskyAuthCreatePosts.typeIdentifier,
        ] {
            #expect(catalog.document(nsid) != nil, "\(nsid) is not bundled")
        }
        // tools.ozone is the PetrelOzone product; it is not part of the core catalog.
        #expect(!catalog.nsids.contains { $0.hasPrefix("tools.ozone.") })
        #expect(catalog.referenceProblems().isEmpty)
    }

    @Test("A generated record that satisfies its Lexicon validates")
    func validGeneratedRecordPasses() throws {
        let catalog = try LexiconCatalog.bundled()
        let post = try Self.post(text: "hello world", langs: ["en"])

        try catalog.validateRecord(post)
        try catalog.validateRecord(post, recordKey: "3jwdwj2ctlk26")
    }

    /// `app.bsky.feed.post` limits `text` to 300 graphemes and 3000 bytes. The Swift type
    /// is a plain `String`; the schema is where the limit lives.
    @Test("A constraint the generated type does not carry is enforced through the catalog")
    func constraintViolationsAreReported() throws {
        let catalog = try LexiconCatalog.bundled()

        let tooManyGraphemes = try Self.post(text: String(repeating: "a", count: 301))
        #expect {
            try catalog.validateRecord(tooManyGraphemes)
        } throws: { error in
            (error as? LexiconValidationError)?.contains(.stringTooManyGraphemes, at: "/text") == true
        }

        // Exactly at the limit is fine, and the limit counts graphemes, not bytes or scalars.
        try catalog.validateRecord(Self.post(text: String(repeating: "👨‍👩‍👧‍👦", count: 100)))

        let tooManyLanguages = try Self.post(text: "hi", langs: ["en", "de", "fr", "es"])
        #expect(throws: LexiconValidationError.self) {
            try catalog.validateRecord(tooManyLanguages)
        }
    }

    @Test("A record key is checked against the collection's key type")
    func recordKeyIsChecked() throws {
        let catalog = try LexiconCatalog.bundled()
        let post = try Self.post(text: "hello")

        #expect(throws: LexiconValidationError.self) {
            try catalog.validateRecord(post, recordKey: "self")
        }
    }

    @Test("A generated object validates against the definition of its type")
    func generatedObjectValidates() throws {
        let catalog = try LexiconCatalog.bundled()
        let ref = try ComAtprotoRepoStrongRef(
            uri: ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jwdwj2ctlk26"),
            cid: CID.parse("bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a")
        )

        try catalog.validate(ref)
    }

    @Test("Query parameters are checked against the endpoint's Lexicon")
    func queryParametersAreChecked() throws {
        let catalog = try LexiconCatalog.bundled()
        let nsid = AppBskyFeedGetTimeline.typeIdentifier

        let accepted = try catalog.validateXRPCParameters(
            AppBskyFeedGetTimeline.Parameters(limit: 100).asQueryItems(),
            nsid: nsid
        )
        #expect(accepted["limit"] == .integer(100))

        #expect(throws: LexiconValidationError.self) {
            try catalog.validateXRPCParameters(
                AppBskyFeedGetTimeline.Parameters(limit: 101).asQueryItems(),
                nsid: nsid
            )
        }
    }
}
