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

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(convos, forKey: .convos)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let convosValue = try (convos as? DAGCBOREncodable)?.toCBORValue() ?? convos
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
    ///
    func listConvos(input: ChatBskyConvoListConvos.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoListConvos.Output?) {
        let endpoint = "chat.bsky.convo.listConvos"

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
        let decodedData = try? decoder.decode(ChatBskyConvoListConvos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
