@testable import Petrel
import XCTest

final class ServiceDIDMappingTests: XCTestCase {
    func testServiceDIDMapping() async throws {
        // Create a network service
        let baseURL = try XCTUnwrap(URL(string: "https://bsky.social"))
        let networkService = NetworkService(baseURL: baseURL)

        // Set service DIDs
        await networkService.setServiceDID("did:web:api.bsky.app#bsky_appview", for: "app.bsky")
        await networkService.setServiceDID("did:web:api.bsky.chat#bsky_chat", for: "chat.bsky")

        // Test app.bsky endpoints
        let appBskyDID = await networkService.getServiceDID(for: "app.bsky.feed.getTimeline")
        XCTAssertEqual(appBskyDID, "did:web:api.bsky.app#bsky_appview")

        // Test chat.bsky endpoints
        let chatDID = await networkService.getServiceDID(for: "chat.bsky.convo.listConvos")
        XCTAssertEqual(chatDID, "did:web:api.bsky.chat#bsky_chat")

        // Test preferences endpoints always use app.bsky DID
        let getPreferencesDID = await networkService.getServiceDID(for: "app.bsky.actor.getPreferences")
        XCTAssertEqual(getPreferencesDID, "did:web:api.bsky.app#bsky_appview")

        let putPreferencesDID = await networkService.getServiceDID(for: "app.bsky.actor.putPreferences")
        XCTAssertEqual(putPreferencesDID, "did:web:api.bsky.app#bsky_appview")

        // Test endpoint without configured service DID
        let unknownDID = await networkService.getServiceDID(for: "com.atproto.server.createSession")
        XCTAssertNil(unknownDID)
    }

    func testCustomServiceDID() async throws {
        // Create a network service
        let baseURL = try XCTUnwrap(URL(string: "https://bsky.social"))
        let networkService = NetworkService(baseURL: baseURL)

        // Set a custom service DID for app.bsky
        let customDID = "did:web:custom.appview.example#custom_appview"
        await networkService.setServiceDID(customDID, for: "app.bsky")

        // Verify custom DID is used
        let appBskyDID = await networkService.getServiceDID(for: "app.bsky.feed.getTimeline")
        XCTAssertEqual(appBskyDID, customDID)

        // Verify preferences still use the custom DID (since it's the app.bsky DID)
        let preferencesDID = await networkService.getServiceDID(for: "app.bsky.actor.getPreferences")
        XCTAssertEqual(preferencesDID, customDID)
    }
}
