import Foundation
@testable import Petrel
import Testing

/// Ports of the `utils` cases in `packages/api/tests/atp-agent.test.ts` and of
/// the `sanitizeMutedWordValue` expectations exercised through `addMutedWord`.
@Suite("BskyPreferences utilities")
struct BskyPreferencesUtilitiesTests {
    private func feed(_ id: String, type: String = "feed", value: String, pinned: Bool) -> AppBskyActorDefs.SavedFeed {
        AppBskyActorDefs.SavedFeed(id: id, type: type, value: value, pinned: pinned)
    }

    private let feedURI = "at://bob.com/app.bsky.feed.generator/1"
    private let listURI = "at://bob.com/app.bsky.graph.list/2"

    @Test("savedFeedsToUriArrays: saved includes pinned, order kept")
    func savedFeedsToUriArrays() {
        let (pinned, saved) = BskyPreferencesUtilities.savedFeedsToURIArrays([
            (value: "a", pinned: true),
            (value: "b", pinned: false),
            (value: "c", pinned: true),
        ])
        #expect(saved == ["a", "b", "c"])
        #expect(pinned == ["a", "c"])
    }

    @Test("getSavedFeedType works")
    func savedFeedType() throws {
        #expect(try BskyPreferencesUtilities.savedFeedType(of: "at://foo.com") == "unknown")
        #expect(try BskyPreferencesUtilities.savedFeedType(of: feedURI) == "feed")
        #expect(try BskyPreferencesUtilities.savedFeedType(of: listURI) == "list")
        #expect(try BskyPreferencesUtilities.savedFeedType(of: "at://did:plc:fake/app.bsky.graph.follow/fake") == "unknown")
    }

    @Test("getSavedFeedType throws on an invalid URI")
    func savedFeedTypeInvalid() {
        #expect(throws: BskyAgentError.self) {
            try BskyPreferencesUtilities.savedFeedType(of: "https://example.com/feed")
        }
    }

    @Test("validateSavedFeed throws if missing id")
    func validateMissingID() {
        #expect(throws: BskyAgentError.self) {
            try BskyPreferencesUtilities.validateSavedFeed(feed("", value: feedURI, pinned: false))
        }
    }

    @Test("validateSavedFeed does not throw if a UUID is used as id")
    func validateUUID() throws {
        try BskyPreferencesUtilities.validateSavedFeed(
            feed("497dcba3-ecbf-4587-a2dd-5eb0665e6880", value: feedURI, pinned: false)
        )
    }

    @Test("validateSavedFeed throws if mismatched types")
    func validateMismatch() {
        #expect(throws: BskyAgentError.self) {
            try BskyPreferencesUtilities.validateSavedFeed(feed("3jzfcijpj2z2a", type: "list", value: feedURI, pinned: false))
        }
        #expect(throws: BskyAgentError.self) {
            try BskyPreferencesUtilities.validateSavedFeed(feed("3jzfcijpj2z2a", type: "feed", value: listURI, pinned: false))
        }
    }

    @Test("validateSavedFeed throws when a feed or list value is not an AT URI")
    func validateNonURI() {
        #expect(throws: BskyAgentError.self) {
            try BskyPreferencesUtilities.validateSavedFeed(feed("3jzfcijpj2z2a", type: "feed", value: "following", pinned: false))
        }
    }

    @Test("validateSavedFeed ignores values it can't validate")
    func validateUnknown() throws {
        try BskyPreferencesUtilities.validateSavedFeed(feed("3jzfcijpj2z2a", type: "timeline", value: "following", pinned: false))
        try BskyPreferencesUtilities.validateSavedFeed(feed("3jzfcijpj2z2a", type: "unknown", value: "could be @nyt4!ng", pinned: false))
    }

    @Test(
        "sanitizeMutedWordValue",
        arguments: [
            ("word", "word"),
            ("#", ""),
            ("##", "#"),
            ("##hashtag", "#hashtag"),
            ("#hashtag", "hashtag"),
            ("#\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
            ("##\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
            ("###\u{FE0F}\u{20E3}", "##\u{FE0F}\u{20E3}"),
            ("Bluesky's", "Bluesky's"),
            ("#\u{200B}", ""),
            ("#\u{200B}ab", "ab"),
            ("test value\n with newline", "test value with newline"),
            ("test value\n\r with newline", "test value with newline"),
            (" ", ""),
            (" trim ", "trim"),
            ("\u{FEFF}\t trim\u{2028}\u{3000}", "trim"),
            ("#new value", "new value"),
            ("", ""),
        ]
    )
    func sanitize(input: String, expected: String) {
        #expect(BskyPreferencesUtilities.sanitizeMutedWordValue(input) == expected)
    }

    @Test("sanitizeMutedWordValue removes only the first run of invisible characters, as the TS regex does")
    func sanitizeFirstRunOnly() {
        #expect(BskyPreferencesUtilities.sanitizeMutedWordValue("a\n\nb\nc") == "ab\nc")
        #expect(BskyPreferencesUtilities.sanitizeMutedWordValue("a\u{00AD}\u{2060}\u{200D}\u{200C}\u{200B}b") == "ab")
    }
}
