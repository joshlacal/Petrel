import Foundation

// lexicon: 1, id: app.bsky.actor.searchActorsTypeahead

public enum AppBskyActorSearchActorsTypeahead {
    public static let typeIdentifier = "app.bsky.actor.searchActorsTypeahead"
    public struct Parameters: Parametrizable {
        public let term: String?
        public let q: String?
        public let limit: Int?

        public init(
            term: String? = nil,
            q: String? = nil,
            limit: Int? = nil
        ) {
            self.term = term
            self.q = q
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let actors: [AppBskyActorDefs.ProfileViewBasic]

        // Standard public initializer
        public init(
            actors: [AppBskyActorDefs.ProfileViewBasic]

        ) {
            self.actors = actors
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            actors = try container.decode([AppBskyActorDefs.ProfileViewBasic].self, forKey: .actors)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(actors, forKey: .actors)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let actorsValue = try actors.toCBORValue()
            map = map.adding(key: "actors", value: actorsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case actors
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    // MARK: - searchActorsTypeahead

    /// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func searchActorsTypeahead(input: AppBskyActorSearchActorsTypeahead.Parameters) async throws -> (responseCode: Int, data: AppBskyActorSearchActorsTypeahead.Output?) {
        let endpoint = "app.bsky.actor.searchActorsTypeahead"

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
        let decodedData = try? decoder.decode(AppBskyActorSearchActorsTypeahead.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
