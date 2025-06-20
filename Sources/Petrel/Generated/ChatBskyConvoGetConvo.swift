import Foundation

// lexicon: 1, id: chat.bsky.convo.getConvo

public enum ChatBskyConvoGetConvo {
    public static let typeIdentifier = "chat.bsky.convo.getConvo"
    public struct Parameters: Parametrizable {
        public let convoId: String

        public init(
            convoId: String
        ) {
            self.convoId = convoId
        }
    }

    public struct Output: ATProtocolCodable {
        public let convo: ChatBskyConvoDefs.ConvoView

        // Standard public initializer
        public init(
            convo: ChatBskyConvoDefs.ConvoView

        ) {
            self.convo = convo
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convo = try container.decode(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convo, forKey: .convo)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convo
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getConvo

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConvo(input: ChatBskyConvoGetConvo.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvo.Output?) {
        let endpoint = "chat.bsky.convo.getConvo"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
