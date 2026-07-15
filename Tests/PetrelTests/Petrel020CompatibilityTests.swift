import Foundation
@testable import Petrel
import Testing

@Suite("Petrel 0.2.0 compatibility")
struct Petrel020CompatibilityTests {
    @Test("Legacy generated initializers preserve the new fields as nil")
    @available(*, deprecated, message: "Exercises Petrel 0.2.0 compatibility initializers")
    func legacyGeneratedInitializers() throws {
        let config = AppBskyAgeassuranceDefs.ConfigRegion(
            countryCode: "US",
            regionCode: "NY",
            minAccessAge: 13,
            rules: []
        )
        #expect(config.additionalVerificationMethods == nil)

        let input = ChatBskyConvoDefs.MessageInput(
            text: "hello",
            facets: nil,
            embed: nil
        )
        #expect(input.replyTo == nil)

        let view = ChatBskyConvoDefs.MessageView(
            id: "message-id",
            rev: "revision",
            text: "hello",
            facets: nil,
            embed: nil,
            reactions: nil,
            sender: .init(did: try DID(didString: "did:plc:compatibility")),
            sentAt: ATProtocolDate(date: Date(timeIntervalSince1970: 0))
        )
        #expect(view.replyTo == nil)
    }

    @Test("Client assertion backend errors retain typed status and code")
    func clientAssertionBackendErrorValue() {
        let error = ClientAssertionBackendError(statusCode: 403, code: "access_denied")

        #expect(error.statusCode == 403)
        #expect(error.code == "access_denied")
        #expect(error == ClientAssertionBackendError(statusCode: 403, code: "access_denied"))
        #expect(error.errorDescription?.contains("HTTP 403") == true)
    }

    // Keeping the legacy call inside a deprecated declaration both type-checks the
    // compatibility surface and avoids asking release builds to warn on its use.
    @available(*, deprecated, message: "Compile-only compatibility assertion")
    private func legacyGetUnreadCountsCompiles(
        _ namespace: ATProtoClient.Chat.Bsky.Convo
    ) async throws -> (responseCode: Int, data: ChatBskyConvoGetUnreadCounts.Output?) {
        try await namespace.getUnreadCounts()
    }
}
