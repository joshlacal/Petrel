import Foundation

// lexicon: 1, id: app.bsky.graph.getFollowers

public enum AppBskyGraphGetFollowers {
    public static let typeIdentifier = "app.bsky.graph.getFollowers"
    public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let limit: Int?
        public let cursor: String?

        public init(
            actor: ATIdentifier,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.actor = actor
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let subject: AppBskyActorDefs.ProfileView

        public let cursor: String?

        public let followers: [AppBskyActorDefs.ProfileView]

        /// Standard public initializer
        public init(
            subject: AppBskyActorDefs.ProfileView,

            cursor: String? = nil,

            followers: [AppBskyActorDefs.ProfileView]

        ) {
            self.subject = subject

            self.cursor = cursor

            self.followers = followers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            subject = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .subject)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            followers = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .followers)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(subject, forKey: .subject)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(followers, forKey: .followers)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let followersValue = try followers.toCBORValue()
            map = map.adding(key: "followers", value: followersValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case subject
            case cursor
            case followers
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getFollowers

    /// Enumerates accounts which follow a specified account (actor).
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getFollowers(input: AppBskyGraphGetFollowers.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetFollowers.Output?) {
        let endpoint = "app.bsky.graph.getFollowers"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.getFollowers")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
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
                let decodedData = try decoder.decode(AppBskyGraphGetFollowers.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getFollowers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
