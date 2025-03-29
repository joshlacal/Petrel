import Foundation

// lexicon: 1, id: app.bsky.unspecced.searchActorsSkeleton

public enum AppBskyUnspeccedSearchActorsSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.searchActorsSkeleton"
    public struct Parameters: Parametrizable {
        public let q: String
        public let viewer: DID?
        public let typeahead: Bool?
        public let limit: Int?
        public let cursor: String?

        public init(
            q: String,
            viewer: DID? = nil,
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            hitsTotal = try container.decodeIfPresent(Int.self, forKey: .hitsTotal)

            actors = try container.decode([AppBskyUnspeccedDefs.SkeletonSearchActor].self, forKey: .actors)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            if let value = hitsTotal {
                try container.encode(value, forKey: .hitsTotal)
            }

            try container.encode(actors, forKey: .actors)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            if let value = hitsTotal {
                let hitsTotalValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "hitsTotal", value: hitsTotalValue)
            }

            let actorsValue = try (actors as? DAGCBOREncodable)?.toCBORValue() ?? actors
            map = map.adding(key: "actors", value: actorsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case hitsTotal
            case actors
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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedSearchActorsSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
