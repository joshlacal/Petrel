import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.unspecced.getSuggestionsSkeleton

public enum AppBskyUnspeccedGetSuggestionsSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestionsSkeleton"
    public struct Parameters: Parametrizable {
        public let viewer: String?
        public let limit: Int?
        public let cursor: String?
        public let relativeToDid: String?

        public init(
            viewer: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil,
            relativeToDid: String? = nil
        ) {
            self.viewer = viewer
            self.limit = limit
            self.cursor = cursor
            self.relativeToDid = relativeToDid
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let actors: [AppBskyUnspeccedDefs.SkeletonSearchActor]

        public let relativeToDid: String?

        public let recId: Int?

        // Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyUnspeccedDefs.SkeletonSearchActor],

            relativeToDid: String? = nil,

            recId: Int? = nil

        ) {
            self.cursor = cursor

            self.actors = actors

            self.relativeToDid = relativeToDid

            self.recId = recId
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get a skeleton of suggested actors. Intended to be called and then hydrated through app.bsky.actor.getSuggestions
    func getSuggestionsSkeleton(input: AppBskyUnspeccedGetSuggestionsSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestionsSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestionsSkeleton"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestionsSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
