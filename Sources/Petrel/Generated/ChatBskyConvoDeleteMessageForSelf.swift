import Foundation

// lexicon: 1, id: chat.bsky.convo.deleteMessageForSelf

public enum ChatBskyConvoDeleteMessageForSelf {
    public static let typeIdentifier = "chat.bsky.convo.deleteMessageForSelf"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String

        // Standard public initializer
        public init(convoId: String, messageId: String) {
            self.convoId = convoId
            self.messageId = messageId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            messageId = try container.decode(String.self, forKey: .messageId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(messageId, forKey: .messageId)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case messageId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageIdValue = try (messageId as? DAGCBOREncodable)?.toCBORValue() ?? messageId
            map = map.adding(key: "messageId", value: messageIdValue)

            return map
        }
    }

    public typealias Output = ChatBskyConvoDefs.DeletedMessageView
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func deleteMessageForSelf(
        input: ChatBskyConvoDeleteMessageForSelf.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoDeleteMessageForSelf.Output?) {
        let endpoint = "chat.bsky.convo.deleteMessageForSelf"

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
        let decodedData = try? decoder.decode(ChatBskyConvoDeleteMessageForSelf.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
