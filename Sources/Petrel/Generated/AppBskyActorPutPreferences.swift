import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.actor.putPreferences

public enum AppBskyActorPutPreferences {
    public static let typeIdentifier = "app.bsky.actor.putPreferences"
    public struct Input: ATProtocolCodable {
        public let preferences: AppBskyActorDefs.Preferences

        // Standard public initializer
        public init(preferences: AppBskyActorDefs.Preferences) {
            self.preferences = preferences
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Set the private preferences attached to the account.
    func putPreferences(
        input: AppBskyActorPutPreferences.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/app.bsky.actor.putPreferences"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
