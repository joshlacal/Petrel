import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.actor.getProfile

public enum AppBskyActorGetProfile {
    public static let typeIdentifier = "app.bsky.actor.getProfile"
    public struct Parameters: Parametrizable {
        public let actor: String

        public init(
            actor: String
        ) {
            self.actor = actor
        }
    }

    public typealias Output = AppBskyActorDefs.ProfileViewDetailed
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
    func getProfile(input: AppBskyActorGetProfile.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfile.Output?) {
        let endpoint = "/app.bsky.actor.getProfile"

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
        let decodedData = try? decoder.decode(AppBskyActorGetProfile.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
