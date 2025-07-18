import Foundation

// lexicon: 1, id: chat.bsky.convo.listConvos

public enum ChatBskyConvoListConvos {
    public static let typeIdentifier = "chat.bsky.convo.listConvos"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let readState: String?
        public let status: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil,
            readState: String? = nil,
            status: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
            self.readState = readState
            self.status = status
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let convos: [ChatBskyConvoDefs.ConvoView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            convos: [ChatBskyConvoDefs.ConvoView]

        ) {
            self.cursor = cursor

            self.convos = convos
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            convos = try container.decode([ChatBskyConvoDefs.ConvoView].self, forKey: .convos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(convos, forKey: .convos)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let convosValue = try convos.toCBORValue()
            map = map.adding(key: "convos", value: convosValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case convos
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - listConvos

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listConvos(input: ChatBskyConvoListConvos.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoListConvos.Output?) {
        let endpoint = "chat.bsky.convo.listConvos"

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
        let decodedData = try? decoder.decode(ChatBskyConvoListConvos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
