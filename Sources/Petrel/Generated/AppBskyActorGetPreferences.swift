import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.actor.getPreferences

public enum AppBskyActorGetPreferences {
    public static let typeIdentifier = "app.bsky.actor.getPreferences"
    public struct Parameters: Parametrizable {
        public init(
        ) {}
    }

    public struct Output: ATProtocolCodable {
        public let preferences: AppBskyActorDefs.Preferences

        // Standard public initializer
        public init(
            preferences: AppBskyActorDefs.Preferences
        ) {
            self.preferences = preferences
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
    func getPreferences(input: AppBskyActorGetPreferences.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetPreferences.Output?) {
        let endpoint = "/app.bsky.actor.getPreferences"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyActorGetPreferences.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
