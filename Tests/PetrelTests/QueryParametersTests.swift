import Foundation
@testable import Petrel
import Testing

@Suite("Query parameter encoding")
struct QueryParametersTests {
    @Test("Language code containers are emitted as scalar query parameters")
    func languageCodeContainerQueryParameter() {
        let parameters = AppBskyFeedSearchPosts.Parameters(
            q: "swift",
            lang: LanguageCodeContainer(languageCode: "en")
        )

        let queryItems = parameters.asQueryItems()

        #expect(queryItems.first(where: { $0.name == "lang" })?.value == "en")
    }

    @Test("Language code arrays emit one query parameter per language")
    func languageCodeContainerArrayQueryParameters() {
        let parameters = AppBskyFeedSearchPostsV2.Parameters(
            query: "swift",
            languages: [
                LanguageCodeContainer(languageCode: "en"),
                LanguageCodeContainer(languageCode: "fr"),
            ]
        )

        let languageValues = parameters.asQueryItems()
            .filter { $0.name == "languages" }
            .compactMap { $0.value }

        #expect(languageValues == ["en", "fr"])
    }

    enum ProtocolVersion: String, Codable, Sendable {
        case one = "1"
        case two = "2"
    }

    /// Shape of generated lexicon parameters such as
    /// `blue.catbird.chat.getConversations.supportedProtocolVersions`.
    struct VersionedParameters: Parametrizable {
        let limit: Int
        let supportedProtocolVersions: [ProtocolVersion]?
    }

    @Test("Optional enum arrays emit one raw value per element")
    func optionalEnumArrayPresent() {
        let items = VersionedParameters(limit: 5, supportedProtocolVersions: [.one, .two]).asQueryItems()
        #expect(items.filter { $0.name == "supportedProtocolVersions" }.map(\.value) == ["1", "2"])
        #expect(items.first(where: { $0.name == "limit" })?.value == "5")
    }

    @Test("Absent and empty optional enum arrays emit no items")
    func optionalEnumArrayNilAndEmpty() {
        for versions in [nil, []] as [[ProtocolVersion]?] {
            let items = VersionedParameters(limit: 5, supportedProtocolVersions: versions).asQueryItems()
            #expect(items.map(\.name) == ["limit"])
        }
    }
}
