import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.actor.getProfiles

public enum AppBskyActorGetProfiles {
    public static let typeIdentifier = "app.bsky.actor.getProfiles"
    public struct Parameters: Parametrizable {
        public let actors: [String]

        public init(
            actors: [String]
        ) {
            self.actors = actors
        }
    }

    public struct Output: ATProtocolCodable {
        public let profiles: [AppBskyActorDefs.ProfileViewDetailed]

        // Standard public initializer
        public init(
            profiles: [AppBskyActorDefs.ProfileViewDetailed]
        ) {
            self.profiles = profiles
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Get detailed profile views of multiple actors.
    func getProfiles(input: AppBskyActorGetProfiles.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfiles.Output?) {
        let endpoint = "/app.bsky.actor.getProfiles"

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
        let decodedData = try? decoder.decode(AppBskyActorGetProfiles.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
