import Foundation

// lexicon: 1, id: chat.bsky.actor.deleteAccount

public enum ChatBskyActorDeleteAccount {
    public static let typeIdentifier = "chat.bsky.actor.deleteAccount"

    public struct Output: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        public func toCBORValue() throws -> Any {
            return data
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Actor {
    // MARK: - deleteAccount

    ///
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteAccount(
    ) async throws -> (responseCode: Int, data: ChatBskyActorDeleteAccount.Output?) {
        let endpoint = "chat.bsky.actor.deleteAccount"

        var headers: [String: String] = [:]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Chat endpoint - use proxy header
        let proxyHeaders = ["atproto-proxy": "did:web:api.bsky.chat#bsky_chat"]
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyActorDeleteAccount.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
