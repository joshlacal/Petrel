import Foundation

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
        let endpoint = "app.bsky.actor.getProfiles"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyActorGetProfiles.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
