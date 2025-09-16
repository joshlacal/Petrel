import Foundation

// lexicon: 1, id: chat.bsky.moderation.getMessageContext

public enum ChatBskyModerationGetMessageContext {
    public static let typeIdentifier = "chat.bsky.moderation.getMessageContext"
    public struct Parameters: Parametrizable {
        public let convoId: String?
        public let messageId: String
        public let before: Int?
        public let after: Int?

        public init(
            convoId: String? = nil,
            messageId: String,
            before: Int? = nil,
            after: Int? = nil
        ) {
            self.convoId = convoId
            self.messageId = messageId
            self.before = before
            self.after = after
        }
    }

    public struct Output: ATProtocolCodable {
        public let messages: [OutputMessagesUnion]

        // Standard public initializer
        public init(
            messages: [OutputMessagesUnion]

        ) {
            self.messages = messages
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            messages = try container.decode([OutputMessagesUnion].self, forKey: .messages)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(messages, forKey: .messages)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let messagesValue = try messages.toCBORValue()
            map = map.adding(key: "messages", value: messagesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case messages
        }
    }

    public enum OutputMessagesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
        case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ChatBskyConvoDefs.MessageView) {
            self = .chatBskyConvoDefsMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.DeletedMessageView) {
            self = .chatBskyConvoDefsDeletedMessageView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#messageView":
                let value = try ChatBskyConvoDefs.MessageView(from: decoder)
                self = .chatBskyConvoDefsMessageView(value)
            case "chat.bsky.convo.defs#deletedMessageView":
                let value = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                self = .chatBskyConvoDefsDeletedMessageView(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                hasher.combine("chat.bsky.convo.defs#messageView")
                hasher.combine(value)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                hasher.combine("chat.bsky.convo.defs#deletedMessageView")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputMessagesUnion, rhs: OutputMessagesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputMessagesUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsDeletedMessageView(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Moderation {
    // MARK: - getMessageContext

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getMessageContext(input: ChatBskyModerationGetMessageContext.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetMessageContext.Output?) {
        let endpoint = "chat.bsky.moderation.getMessageContext"

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

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyModerationGetMessageContext.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.moderation.getMessageContext: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
