import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.unspecced.searchActorsSkeleton

public enum AppBskyUnspeccedSearchActorsSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.searchActorsSkeleton"
    public struct Parameters: Parametrizable {
        public let q: String
        public let viewer: String?
        public let typeahead: Bool?
        public let limit: Int?
        public let cursor: String?

        public init(
            q: String,
            viewer: String? = nil,
            typeahead: Bool? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.q = q
            self.viewer = viewer
            self.typeahead = typeahead
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let hitsTotal: Int?

        public let actors: [AppBskyUnspeccedDefs.SkeletonSearchActor]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            hitsTotal: Int? = nil,

            actors: [AppBskyUnspeccedDefs.SkeletonSearchActor]

        ) {
            self.cursor = cursor

            self.hitsTotal = hitsTotal

            self.actors = actors
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case badQueryString = "BadQueryString."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Backend Actors (profile) search, returns only skeleton.
    func searchActorsSkeleton(input: AppBskyUnspeccedSearchActorsSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedSearchActorsSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.searchActorsSkeleton"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedSearchActorsSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
