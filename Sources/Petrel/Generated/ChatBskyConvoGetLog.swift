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
    }

    public enum OutputLogsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case chatBskyConvoDefsLogBeginConvo(ChatBskyConvoDefs.LogBeginConvo)
        case chatBskyConvoDefsLogAcceptConvo(ChatBskyConvoDefs.LogAcceptConvo)
        case chatBskyConvoDefsLogLeaveConvo(ChatBskyConvoDefs.LogLeaveConvo)
        case chatBskyConvoDefsLogCreateMessage(ChatBskyConvoDefs.LogCreateMessage)
        case chatBskyConvoDefsLogDeleteMessage(ChatBskyConvoDefs.LogDeleteMessage)
        case unexpected(ATProtocolValueContainer)

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
            case "chat.bsky.convo.defs#logCreateMessage":
                let value = try ChatBskyConvoDefs.LogCreateMessage(from: decoder)
                self = .chatBskyConvoDefsLogCreateMessage(value)
            case "chat.bsky.convo.defs#logDeleteMessage":
                let value = try ChatBskyConvoDefs.LogDeleteMessage(from: decoder)
                self = .chatBskyConvoDefsLogDeleteMessage(value)
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
            case let .chatBskyConvoDefsLogCreateMessage(value):
                try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
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
            case let .chatBskyConvoDefsLogCreateMessage(value):
                hasher.combine("chat.bsky.convo.defs#logCreateMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                hasher.combine("chat.bsky.convo.defs#logDeleteMessage")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case rawContent = "_rawContent"
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
                .chatBskyConvoDefsLogCreateMessage(lhsValue),
                .chatBskyConvoDefsLogCreateMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogDeleteMessage(lhsValue),
                .chatBskyConvoDefsLogDeleteMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputLogsUnion else { return false }
            return self == otherValue
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
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsLogBeginConvo(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogBeginConvo {
                        self = .chatBskyConvoDefsLogBeginConvo(updatedValue)
                    }
                }
            case var .chatBskyConvoDefsLogAcceptConvo(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogAcceptConvo {
                        self = .chatBskyConvoDefsLogAcceptConvo(updatedValue)
                    }
                }
            case var .chatBskyConvoDefsLogLeaveConvo(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogLeaveConvo {
                        self = .chatBskyConvoDefsLogLeaveConvo(updatedValue)
                    }
                }
            case var .chatBskyConvoDefsLogCreateMessage(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogCreateMessage {
                        self = .chatBskyConvoDefsLogCreateMessage(updatedValue)
                    }
                }
            case var .chatBskyConvoDefsLogDeleteMessage(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? ChatBskyConvoDefs.LogDeleteMessage {
                        self = .chatBskyConvoDefsLogDeleteMessage(updatedValue)
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
