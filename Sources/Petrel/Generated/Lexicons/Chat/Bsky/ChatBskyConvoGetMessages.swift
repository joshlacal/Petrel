import Foundation

// lexicon: 1, id: chat.bsky.convo.getMessages

public enum ChatBskyConvoGetMessages {
    public static let typeIdentifier = "chat.bsky.convo.getMessages"
    public struct Parameters: Parametrizable {
        public let convoId: String
        public let limit: Int?
        public let cursor: String?

        public init(
            convoId: String,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.convoId = convoId
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let messages: [OutputMessagesUnion]

        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            messages: [OutputMessagesUnion],

            relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]? = nil

        ) {
            self.cursor = cursor

            self.messages = messages

            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'cursor' — degrading to nil: \(error)")
                cursor = nil
            }

            messages = try container.decode([OutputMessagesUnion].self, forKey: .messages)

            do {
                relatedProfiles = try container.decodeIfPresent([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'relatedProfiles' — degrading to nil: \(error)")
                relatedProfiles = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(messages, forKey: .messages)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(relatedProfiles, forKey: .relatedProfiles)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let messagesValue = try messages.toCBORValue()
            map = map.adding(key: "messages", value: messagesValue)

            if let value = relatedProfiles {
                // Encode optional property even if it's an empty array for CBOR
                let relatedProfilesValue = try value.toCBORValue()
                map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case messages
            case relatedProfiles
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidConvo = "InvalidConvo."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }

    public enum OutputMessagesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
        case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
        case chatBskyConvoDefsSystemMessageView(ChatBskyConvoDefs.SystemMessageView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.MessageView) {
            self = .chatBskyConvoDefsMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.DeletedMessageView) {
            self = .chatBskyConvoDefsDeletedMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageView) {
            self = .chatBskyConvoDefsSystemMessageView(value)
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
            case "chat.bsky.convo.defs#systemMessageView":
                let value = try ChatBskyConvoDefs.SystemMessageView(from: decoder)
                self = .chatBskyConvoDefsSystemMessageView(value)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                try container.encode("chat.bsky.convo.defs#systemMessageView", forKey: .type)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageView")
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
            case let (
                .chatBskyConvoDefsSystemMessageView(lhsValue),
                .chatBskyConvoDefsSystemMessageView(rhsValue)
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

        /// DAGCBOR encoding with field ordering
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageView")

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
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getMessages

    /// Returns a page of messages from a conversation.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getMessages(input: ChatBskyConvoGetMessages.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetMessages.Output?) {
        let endpoint = "chat.bsky.convo.getMessages"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getMessages")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyConvoGetMessages.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getMessages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
