import Foundation
import Petrel
import Testing

/// Compiled copies of the snippets in `Sources/Petrel/Petrel.docc/Identifiers.md`.
/// Uses a plain `import Petrel` so that only public API is reachable, exactly as
/// in an application. When a snippet in the article changes, change it here too.
@Suite("DocC article: Identifiers and String Formats")
struct IdentifiersArticleTests {
    @Test("three ways to check a string")
    func threeWaysToCheck() {
        #expect(DID.isValidDID("did:plc:ewvi7nxzyoun6zhxrhs64oiz"))
        #expect(!DID.isValidDID("did:plc:ewvi7nxzyoun6zhxrhs64oiz\n"))

        do {
            _ = try Handle(handleString: "not a handle")
            Issue.record("expected the handle to be rejected")
        } catch let error as ATProtocolError {
            #expect(error == .invalidHandle(
                "Invalid handle \"not a handle\": contains a character outside A-Z a-z 0-9 . -"
            ))
            #expect(error.message.hasPrefix("Invalid handle"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("values are kept as written")
    func valuesAreKeptAsWritten() throws {
        let handle = try Handle(handleString: "Alice.Example.COM")
        #expect(handle.value == "alice.example.com")
        #expect(handle.wireValue == "Alice.Example.COM")

        let uri = try ATProtocolURI(uriString: "at://Alice.Example.COM/COM.Example.fooBar/Self")
        #expect(uri.normalized().uriString() == "at://alice.example.com/com.example.fooBar/Self")

        let nsid = try NSID(nsidString: "COM.Example.fooBar")
        #expect(nsid.normalized.nsidString() == "com.example.fooBar")
    }

    @Test("DIDs and handles")
    func didsAndHandles() throws {
        let did = try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(did.method == "plc")
        #expect(did.atprotoMethod == .plc)

        #expect(try DID(didString: "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N").atprotoMethod == nil)
        #expect(try !DID(didString: "did:web:example.com:user:alice").isAtprotoDID)

        #expect(try Handle(handleString: "laptop.local").hasDisallowedTLD)
        #expect(Handle.invalidSentinel.value == "handle.invalid")

        switch try ATIdentifier(string: "atproto.com") {
        case .did: Issue.record("expected a handle")
        case let .handle(handle): #expect(handle.value == "atproto.com")
        }
    }

    @Test("NSIDs and record keys")
    func nsidsAndRecordKeys() throws {
        let collection = try NSID(nsidString: "app.bsky.feed.post")
        #expect(collection.authority == "app.bsky.feed")
        #expect(collection.name == "post")

        let key = try RecordKey(keyString: "3jzfcijpj2z2a")
        #expect(key.value == "3jzfcijpj2z2a")
        #expect(!RecordKey.isValidRecordKey(".."))
    }

    @Test("TIDs")
    func tids() async throws {
        let rkey = await TIDGenerator.next()
        #expect(TID.isValidTID(rkey))

        let tid = await TIDGenerator.shared.nextTID()
        #expect(tid.timestampMicros > 1_700_000_000_000_000)
        #expect(tid.clockID < 1024)

        let previousRevision = try TID(tidString: "3jzfcijpj2z2a")
        let revision = try await TIDGenerator.shared.next(after: previousRevision)
        #expect(revision > previousRevision)
    }

    @Test("AT-URIs")
    func atURIs() throws {
        let uri = try ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a")
        #expect(uri.authority == "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(uri.collectionNSID == (try NSID(nsidString: "app.bsky.feed.post")))
        #expect(uri.rkey == (try RecordKey(keyString: "3jzfcijpj2z2a")))

        #expect(!ATProtocolURI.isValidATURI("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/"))

        let did = try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        let collection = try NSID(nsidString: "app.bsky.feed.post")
        let key = try RecordKey(keyString: "3jzfcijpj2z2a")
        let built = try ATProtocolURI(
            authority: .did(did),
            collection: collection,
            recordKey: key
        )
        #expect(built == uri)

        let string = "at://did:plc:asdf123/space/com.example.group/default"
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: string, grammar: .restricted) }
        #expect(!ATProtocolURI.isValidATURI(string, grammar: .restricted))
        #expect(ATProtocolURI.isValidATURI(string))
    }

    @Test("datetimes")
    func datetimes() throws {
        let created = try ATProtocolDate(datetimeString: "1985-04-12T23:20:50.123Z")
        #expect(abs(created.date.timeIntervalSince1970 - 482_196_050.123) < 0.001)
        #expect(created.iso8601String == "1985-04-12T23:20:50.123Z")

        #expect(!ATProtocolDate.isValidDatetime("1985-04-12T23:20:50.123"))
        #expect(!ATProtocolDate.isValidDatetime("1985-02-30T00:00:00Z"))

        #expect(ATProtocolDate.isValidDatetime(ATProtocolDate(date: Date()).iso8601String))

        #expect(try ATProtocolDate.normalizeDatetime("1985-04-12 23:20:50") == "1985-04-12T23:20:50.000Z")
        #expect(try ATProtocolDate.normalizeDatetime("1985-04-12T23:20:50.123+0700") == "1985-04-12T16:20:50.123Z")
    }

    @Test("language tags")
    func languageTags() throws {
        let tag = try LanguageTag("hy-Latn-IT-arevela")
        #expect(tag.language == "hy")
        #expect(tag.script == "Latn")
        #expect(tag.region == "IT")
        #expect(tag.variants == ["arevela"])

        let language = try LanguageCodeContainer(validating: "pt-BR")
        #expect(language.languageTag == "pt-BR")

        #expect(!LanguageTag.isValid("ja-"))
        #expect(LanguageTag.isWellFormed("JA"))
        #expect(!LanguageTag.isValid("JA"))
    }

    @Test("URIs")
    func uris() throws {
        let link = try URI(validating: "https://example.com/path?q=1#top")
        #expect(link.scheme == "https")
        #expect(link.authority == "example.com")
        #expect(link.url == URL(string: "https://example.com/path?q=1#top"))

        #expect(URI.isValidURI("dns:example.com"))
        #expect(!URI.isValidURI("example.com"))

        let unchecked = URI(uriString: "example.com")
        #expect(!unchecked.isValid())
        #expect(throws: (any Error).self) { try JSONEncoder().encode(unchecked) }
    }

    @Test("CID strings")
    func cidStrings() {
        #expect(CIDSyntax.isValid("bafyreidfayvfuwqa7qgahxgn2xrq2xrq2xrq2xrq2xrq2xrq2xrq2xrq2y"))
        #expect(!CIDSyntax.isValid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR"))
    }
}
