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

        // Standard public initializer
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

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(logs, forKey: .logs)
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case logs
        }
    }

    public enum OutputLogsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogMuteConvo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogCreateMessage(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogReadMessage(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogAddReaction(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogBeginConvo {
                        self = .chatBskyConvoDefsLogBeginConvo(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogAcceptConvo {
                        self = .chatBskyConvoDefsLogAcceptConvo(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogLeaveConvo {
                        self = .chatBskyConvoDefsLogLeaveConvo(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogMuteConvo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogMuteConvo {
                        self = .chatBskyConvoDefsLogMuteConvo(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogUnmuteConvo {
                        self = .chatBskyConvoDefsLogUnmuteConvo(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogCreateMessage(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogCreateMessage {
                        self = .chatBskyConvoDefsLogCreateMessage(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogDeleteMessage {
                        self = .chatBskyConvoDefsLogDeleteMessage(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogReadMessage(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogReadMessage {
                        self = .chatBskyConvoDefsLogReadMessage(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogAddReaction(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogAddReaction {
                        self = .chatBskyConvoDefsLogAddReaction(updatedValue)
                    }
                }
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogRemoveReaction {
                        self = .chatBskyConvoDefsLogRemoveReaction(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func getLog(input: ChatBskyConvoGetLog.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetLog.Output?) {
        let endpoint = "chat.bsky.convo.getLog"

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
        let decodedData = try? decoder.decode(ChatBskyConvoGetLog.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
