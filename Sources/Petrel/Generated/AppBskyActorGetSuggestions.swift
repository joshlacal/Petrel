import Foundation

// lexicon: 1, id: app.bsky.actor.getSuggestions

public enum AppBskyActorGetSuggestions {
    public static let typeIdentifier = "app.bsky.actor.getSuggestions"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let actors: [AppBskyActorDefs.ProfileView]

        public let recId: Int?

        // Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyActorDefs.ProfileView],

            recId: Int? = nil

        ) {
            self.cursor = cursor

            self.actors = actors

            self.recId = recId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            actors = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .actors)

            recId = try container.decodeIfPresent(Int.self, forKey: .recId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(actors, forKey: .actors)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recId, forKey: .recId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let actorsValue = try actors.toCBORValue()
            map = map.adding(key: "actors", value: actorsValue)

            if let value = recId {
                // Encode optional property even if it's an empty array for CBOR
                let recIdValue = try value.toCBORValue()
                map = map.adding(key: "recId", value: recIdValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case actors
            case recId
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    // MARK: - getSuggestions

    /// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSuggestions(input: AppBskyActorGetSuggestions.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetSuggestions.Output?) {
        let endpoint = "app.bsky.actor.getSuggestions"

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

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyActorGetSuggestions.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.actor.getSuggestions: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
