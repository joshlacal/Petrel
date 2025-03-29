import Foundation

// lexicon: 1, id: app.bsky.unspecced.getSuggestionsSkeleton

public enum AppBskyUnspeccedGetSuggestionsSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestionsSkeleton"
    public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let limit: Int?
        public let cursor: String?
        public let relativeToDid: DID?

        public init(
            viewer: DID? = nil,
            limit: Int? = nil,
            cursor: String? = nil,
            relativeToDid: DID? = nil
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

        public let relativeToDid: DID?

        public let recId: Int?

        // Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyUnspeccedDefs.SkeletonSearchActor],

            relativeToDid: DID? = nil,

            recId: Int? = nil

        ) {
            self.cursor = cursor

            self.actors = actors

            self.relativeToDid = relativeToDid

            self.recId = recId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            actors = try container.decode([AppBskyUnspeccedDefs.SkeletonSearchActor].self, forKey: .actors)

            relativeToDid = try container.decodeIfPresent(DID.self, forKey: .relativeToDid)

            recId = try container.decodeIfPresent(Int.self, forKey: .recId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(actors, forKey: .actors)

            if let value = relativeToDid {
                try container.encode(value, forKey: .relativeToDid)
            }

            if let value = recId {
                try container.encode(value, forKey: .recId)
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let actorsValue = try (actors as? DAGCBOREncodable)?.toCBORValue() ?? actors
            map = map.adding(key: "actors", value: actorsValue)

            if let value = relativeToDid {
                let relativeToDidValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "relativeToDid", value: relativeToDidValue)
            }

            if let value = recId {
                let recIdValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "recId", value: recIdValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case actors
            case relativeToDid
            case recId
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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetSuggestionsSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
