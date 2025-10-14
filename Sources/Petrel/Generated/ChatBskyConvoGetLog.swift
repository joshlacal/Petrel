import Foundation



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
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.logs = try container.decode([OutputLogsUnion].self, forKey: .logs)
            
            
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
        case .chatBskyConvoDefsLogBeginConvo(let value):
            try container.encode("chat.bsky.convo.defs#logBeginConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            try container.encode("chat.bsky.convo.defs#logAcceptConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            try container.encode("chat.bsky.convo.defs#logLeaveConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogMuteConvo(let value):
            try container.encode("chat.bsky.convo.defs#logMuteConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            try container.encode("chat.bsky.convo.defs#logUnmuteConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogCreateMessage(let value):
            try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogReadMessage(let value):
            try container.encode("chat.bsky.convo.defs#logReadMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogAddReaction(let value):
            try container.encode("chat.bsky.convo.defs#logAddReaction", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            try container.encode("chat.bsky.convo.defs#logRemoveReaction", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .chatBskyConvoDefsLogBeginConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logBeginConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logAcceptConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logLeaveConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogMuteConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logMuteConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logUnmuteConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogCreateMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logCreateMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logDeleteMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogReadMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logReadMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogAddReaction(let value):
            hasher.combine("chat.bsky.convo.defs#logAddReaction")
            hasher.combine(value)
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            hasher.combine("chat.bsky.convo.defs#logRemoveReaction")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputLogsUnion, rhs: OutputLogsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.chatBskyConvoDefsLogBeginConvo(let lhsValue),
              .chatBskyConvoDefsLogBeginConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogAcceptConvo(let lhsValue),
              .chatBskyConvoDefsLogAcceptConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogLeaveConvo(let lhsValue),
              .chatBskyConvoDefsLogLeaveConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogMuteConvo(let lhsValue),
              .chatBskyConvoDefsLogMuteConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogUnmuteConvo(let lhsValue),
              .chatBskyConvoDefsLogUnmuteConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogCreateMessage(let lhsValue),
              .chatBskyConvoDefsLogCreateMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogDeleteMessage(let lhsValue),
              .chatBskyConvoDefsLogDeleteMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogReadMessage(let lhsValue),
              .chatBskyConvoDefsLogReadMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogAddReaction(let lhsValue),
              .chatBskyConvoDefsLogAddReaction(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogRemoveReaction(let lhsValue),
              .chatBskyConvoDefsLogRemoveReaction(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputLogsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .chatBskyConvoDefsLogBeginConvo(let value):
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
        case .chatBskyConvoDefsLogAcceptConvo(let value):
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
        case .chatBskyConvoDefsLogLeaveConvo(let value):
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
        case .chatBskyConvoDefsLogMuteConvo(let value):
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
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
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
        case .chatBskyConvoDefsLogCreateMessage(let value):
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
        case .chatBskyConvoDefsLogDeleteMessage(let value):
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
        case .chatBskyConvoDefsLogReadMessage(let value):
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
        case .chatBskyConvoDefsLogAddReaction(let value):
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
        case .chatBskyConvoDefsLogRemoveReaction(let value):
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
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .chatBskyConvoDefsLogBeginConvo(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogMuteConvo(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogCreateMessage(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogReadMessage(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogAddReaction(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .chatBskyConvoDefsLogBeginConvo(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogBeginConvo(value)
        case .chatBskyConvoDefsLogAcceptConvo(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogAcceptConvo(value)
        case .chatBskyConvoDefsLogLeaveConvo(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogLeaveConvo(value)
        case .chatBskyConvoDefsLogMuteConvo(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogMuteConvo(value)
        case .chatBskyConvoDefsLogUnmuteConvo(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogUnmuteConvo(value)
        case .chatBskyConvoDefsLogCreateMessage(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogCreateMessage(value)
        case .chatBskyConvoDefsLogDeleteMessage(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogDeleteMessage(value)
        case .chatBskyConvoDefsLogReadMessage(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogReadMessage(value)
        case .chatBskyConvoDefsLogAddReaction(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogAddReaction(value)
        case .chatBskyConvoDefsLogRemoveReaction(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsLogRemoveReaction(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getLog

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getLog(input: ChatBskyConvoGetLog.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetLog.Output?) {
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
        if (200...299).contains(responseCode) {
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
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
