import Foundation

// lexicon: 1, id: chat.bsky.convo.getLog

public enum ChatBskyConvoGetLog {
    public static let typeIdentifier = "chat.bsky.convo.getLog"
    public struct Parameters: Parametrizable {
        public let cursor: String?

        public init(
            cursor: String? = nil
        ) {
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let logs: [OutputLogsUnion]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            logs: [OutputLogsUnion]

        ) {
            self.cursor = cursor

            self.logs = logs
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            logs = try container.decode([OutputLogsUnion].self, forKey: .logs)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(logs, forKey: .logs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let logsValue = try logs.toCBORValue()
            map = map.adding(key: "logs", value: logsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case logs
        }
    }

    public enum OutputLogsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsLogBeginConvo(ChatBskyConvoDefs.LogBeginConvo)
        case chatBskyConvoDefsLogAcceptConvo(ChatBskyConvoDefs.LogAcceptConvo)
        case chatBskyConvoDefsLogLeaveConvo(ChatBskyConvoDefs.LogLeaveConvo)
        case chatBskyConvoDefsLogMuteConvo(ChatBskyConvoDefs.LogMuteConvo)
        case chatBskyConvoDefsLogUnmuteConvo(ChatBskyConvoDefs.LogUnmuteConvo)
        case chatBskyConvoDefsLogCreateMessage(ChatBskyConvoDefs.LogCreateMessage)
        case chatBskyConvoDefsLogDeleteMessage(ChatBskyConvoDefs.LogDeleteMessage)
        case chatBskyConvoDefsLogReadMessage(ChatBskyConvoDefs.LogReadMessage)
        case chatBskyConvoDefsLogAddReaction(ChatBskyConvoDefs.LogAddReaction)
        case chatBskyConvoDefsLogRemoveReaction(ChatBskyConvoDefs.LogRemoveReaction)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.LogBeginConvo) {
            self = .chatBskyConvoDefsLogBeginConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogAcceptConvo) {
            self = .chatBskyConvoDefsLogAcceptConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogLeaveConvo) {
            self = .chatBskyConvoDefsLogLeaveConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogMuteConvo) {
            self = .chatBskyConvoDefsLogMuteConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogUnmuteConvo) {
            self = .chatBskyConvoDefsLogUnmuteConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogCreateMessage) {
            self = .chatBskyConvoDefsLogCreateMessage(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogDeleteMessage) {
            self = .chatBskyConvoDefsLogDeleteMessage(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogReadMessage) {
            self = .chatBskyConvoDefsLogReadMessage(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogAddReaction) {
            self = .chatBskyConvoDefsLogAddReaction(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogRemoveReaction) {
            self = .chatBskyConvoDefsLogRemoveReaction(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#logBeginConvo":
                let value = try ChatBskyConvoDefs.LogBeginConvo(from: decoder)
                self = .chatBskyConvoDefsLogBeginConvo(value)
            case "chat.bsky.convo.defs#logAcceptConvo":
                let value = try ChatBskyConvoDefs.LogAcceptConvo(from: decoder)
                self = .chatBskyConvoDefsLogAcceptConvo(value)
            case "chat.bsky.convo.defs#logLeaveConvo":
                let value = try ChatBskyConvoDefs.LogLeaveConvo(from: decoder)
                self = .chatBskyConvoDefsLogLeaveConvo(value)
            case "chat.bsky.convo.defs#logMuteConvo":
                let value = try ChatBskyConvoDefs.LogMuteConvo(from: decoder)
                self = .chatBskyConvoDefsLogMuteConvo(value)
            case "chat.bsky.convo.defs#logUnmuteConvo":
                let value = try ChatBskyConvoDefs.LogUnmuteConvo(from: decoder)
                self = .chatBskyConvoDefsLogUnmuteConvo(value)
            case "chat.bsky.convo.defs#logCreateMessage":
                let value = try ChatBskyConvoDefs.LogCreateMessage(from: decoder)
                self = .chatBskyConvoDefsLogCreateMessage(value)
            case "chat.bsky.convo.defs#logDeleteMessage":
                let value = try ChatBskyConvoDefs.LogDeleteMessage(from: decoder)
                self = .chatBskyConvoDefsLogDeleteMessage(value)
            case "chat.bsky.convo.defs#logReadMessage":
                let value = try ChatBskyConvoDefs.LogReadMessage(from: decoder)
                self = .chatBskyConvoDefsLogReadMessage(value)
            case "chat.bsky.convo.defs#logAddReaction":
                let value = try ChatBskyConvoDefs.LogAddReaction(from: decoder)
                self = .chatBskyConvoDefsLogAddReaction(value)
            case "chat.bsky.convo.defs#logRemoveReaction":
                let value = try ChatBskyConvoDefs.LogRemoveReaction(from: decoder)
                self = .chatBskyConvoDefsLogRemoveReaction(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                try container.encode("chat.bsky.convo.defs#logBeginConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                try container.encode("chat.bsky.convo.defs#logAcceptConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                try container.encode("chat.bsky.convo.defs#logLeaveConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogMuteConvo(value):
                try container.encode("chat.bsky.convo.defs#logMuteConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                try container.encode("chat.bsky.convo.defs#logUnmuteConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogCreateMessage(value):
                try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogReadMessage(value):
                try container.encode("chat.bsky.convo.defs#logReadMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogAddReaction(value):
                try container.encode("chat.bsky.convo.defs#logAddReaction", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                try container.encode("chat.bsky.convo.defs#logRemoveReaction", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                hasher.combine("chat.bsky.convo.defs#logBeginConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                hasher.combine("chat.bsky.convo.defs#logAcceptConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                hasher.combine("chat.bsky.convo.defs#logLeaveConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogMuteConvo(value):
                hasher.combine("chat.bsky.convo.defs#logMuteConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                hasher.combine("chat.bsky.convo.defs#logUnmuteConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogCreateMessage(value):
                hasher.combine("chat.bsky.convo.defs#logCreateMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                hasher.combine("chat.bsky.convo.defs#logDeleteMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogReadMessage(value):
                hasher.combine("chat.bsky.convo.defs#logReadMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogAddReaction(value):
                hasher.combine("chat.bsky.convo.defs#logAddReaction")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                hasher.combine("chat.bsky.convo.defs#logRemoveReaction")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputLogsUnion, rhs: OutputLogsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsLogBeginConvo(lhsValue),
                .chatBskyConvoDefsLogBeginConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogAcceptConvo(lhsValue),
                .chatBskyConvoDefsLogAcceptConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogLeaveConvo(lhsValue),
                .chatBskyConvoDefsLogLeaveConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogMuteConvo(lhsValue),
                .chatBskyConvoDefsLogMuteConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogUnmuteConvo(lhsValue),
                .chatBskyConvoDefsLogUnmuteConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogCreateMessage(lhsValue),
                .chatBskyConvoDefsLogCreateMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogDeleteMessage(lhsValue),
                .chatBskyConvoDefsLogDeleteMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogReadMessage(lhsValue),
                .chatBskyConvoDefsLogReadMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogAddReaction(lhsValue),
                .chatBskyConvoDefsLogAddReaction(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogRemoveReaction(lhsValue),
                .chatBskyConvoDefsLogRemoveReaction(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputLogsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logBeginConvo")

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
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logAcceptConvo")

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
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logLeaveConvo")

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
            case let .chatBskyConvoDefsLogMuteConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logMuteConvo")

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
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logUnmuteConvo")

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
            case let .chatBskyConvoDefsLogCreateMessage(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logCreateMessage")

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
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logDeleteMessage")

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
            case let .chatBskyConvoDefsLogReadMessage(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logReadMessage")

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
            case let .chatBskyConvoDefsLogAddReaction(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logAddReaction")

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
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logRemoveReaction")

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
    // MARK: - getLog

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getLog(input: ChatBskyConvoGetLog.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetLog.Output?) {
        let endpoint = "chat.bsky.convo.getLog"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getLog")
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
                let decodedData = try decoder.decode(ChatBskyConvoGetLog.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getLog: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
