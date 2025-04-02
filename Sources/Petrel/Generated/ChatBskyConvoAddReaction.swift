import Foundation

// lexicon: 1, id: chat.bsky.convo.addReaction

public enum ChatBskyConvoAddReaction {
    public static let typeIdentifier = "chat.bsky.convo.addReaction"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String
        public let value: String

        // Standard public initializer
        public init(convoId: String, messageId: String, value: String) {
            self.convoId = convoId
            self.messageId = messageId
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            messageId = try container.decode(String.self, forKey: .messageId)

            value = try container.decode(String.self, forKey: .value)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(messageId, forKey: .messageId)

            try container.encode(value, forKey: .value)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case messageId
            case value
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageIdValue = try (messageId as? DAGCBOREncodable)?.toCBORValue() ?? messageId
            map = map.adding(key: "messageId", value: messageIdValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let message: ChatBskyConvoDefs.MessageView

        // Standard public initializer
        public init(
            message: ChatBskyConvoDefs.MessageView

        ) {
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            message = try container.decode(ChatBskyConvoDefs.MessageView.self, forKey: .message)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(message, forKey: .message)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case message
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case reactionMessageDeleted = "ReactionMessageDeleted.Indicates that the message has been deleted and reactions can no longer be added/removed."
        case reactionLimitReached = "ReactionLimitReached.Indicates that the message has the maximum number of reactions allowed for a single user, and the requested reaction wasn't yet present. If it was already present, the request will not fail since it is idempotent."
        case reactionInvalidValue = "ReactionInvalidValue.Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    /// Adds an emoji reaction to a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in a single reaction.
    func addReaction(
        input: ChatBskyConvoAddReaction.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoAddReaction.Output?) {
        let endpoint = "chat.bsky.convo.addReaction"

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
        let decodedData = try? decoder.decode(ChatBskyConvoAddReaction.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
