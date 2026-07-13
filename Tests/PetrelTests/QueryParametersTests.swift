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
}
