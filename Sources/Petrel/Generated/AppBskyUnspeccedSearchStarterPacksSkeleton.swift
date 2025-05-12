import Foundation

// lexicon: 1, id: app.bsky.unspecced.searchStarterPacksSkeleton

public enum AppBskyUnspeccedSearchStarterPacksSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.searchStarterPacksSkeleton"
    public struct Parameters: Parametrizable {
        public let q: String
        public let viewer: DID?
        public let limit: Int?
        public let cursor: String?

        public init(
            q: String,
            viewer: DID? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.q = q
            self.viewer = viewer
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let hitsTotal: Int?

        public let starterPacks: [AppBskyUnspeccedDefs.SkeletonSearchStarterPack]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            hitsTotal: Int? = nil,

            starterPacks: [AppBskyUnspeccedDefs.SkeletonSearchStarterPack]

        ) {
            self.cursor = cursor

            self.hitsTotal = hitsTotal

            self.starterPacks = starterPacks
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            hitsTotal = try container.decodeIfPresent(Int.self, forKey: .hitsTotal)

            starterPacks = try container.decode([AppBskyUnspeccedDefs.SkeletonSearchStarterPack].self, forKey: .starterPacks)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hitsTotal, forKey: .hitsTotal)

            try container.encode(starterPacks, forKey: .starterPacks)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            if let value = hitsTotal {
                // Encode optional property even if it's an empty array for CBOR
                let hitsTotalValue = try value.toCBORValue()
                map = map.adding(key: "hitsTotal", value: hitsTotalValue)
            }

            let starterPacksValue = try starterPacks.toCBORValue()
            map = map.adding(key: "starterPacks", value: starterPacksValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case hitsTotal
            case starterPacks
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
    // MARK: - searchStarterPacksSkeleton

    /// Backend Starter Pack search, returns only skeleton.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func searchStarterPacksSkeleton(input: AppBskyUnspeccedSearchStarterPacksSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedSearchStarterPacksSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.searchStarterPacksSkeleton"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedSearchStarterPacksSkeleton.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
