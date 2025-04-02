import Foundation

// lexicon: 1, id: chat.bsky.convo.updateRead

public enum ChatBskyConvoUpdateRead {
    public static let typeIdentifier = "chat.bsky.convo.updateRead"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String?

        // Standard public initializer
        public init(convoId: String, messageId: String? = nil) {
            self.convoId = convoId
            self.messageId = messageId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(messageId, forKey: .messageId)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case messageId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            if let value = messageId {
                // Encode optional property even if it's an empty array for CBOR

                let messageIdValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "messageId", value: messageIdValue)
            }

            return map
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

            let convoValue = try (convo as? DAGCBOREncodable)?.toCBORValue() ?? convo
            map = map.adding(key: "convo", value: convoValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convo
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func updateRead(
        input: ChatBskyConvoUpdateRead.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoUpdateRead.Output?) {
        let endpoint = "chat.bsky.convo.updateRead"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ChatBskyConvoUpdateRead.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
