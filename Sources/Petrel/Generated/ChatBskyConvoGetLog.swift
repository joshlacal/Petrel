import Foundation
import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.getLog

public struct ChatBskyConvoGetLog {
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

    public enum OutputLogsUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case chatBskyConvoDefsLogBeginConvo(ChatBskyConvoDefs.LogBeginConvo)
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
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                try container.encode("chat.bsky.convo.defs#logLeaveConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogCreateMessage(value):
                try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                hasher.combine("chat.bsky.convo.defs#logBeginConvo")
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputLogsUnion else { return false }

            switch (self, otherValue) {
            case let (
                .chatBskyConvoDefsLogBeginConvo(selfValue),

                .chatBskyConvoDefsLogBeginConvo(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .chatBskyConvoDefsLogLeaveConvo(selfValue),

                .chatBskyConvoDefsLogLeaveConvo(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .chatBskyConvoDefsLogCreateMessage(selfValue),

                .chatBskyConvoDefsLogCreateMessage(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .chatBskyConvoDefsLogDeleteMessage(selfValue),

                .chatBskyConvoDefsLogDeleteMessage(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoGetLog.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
