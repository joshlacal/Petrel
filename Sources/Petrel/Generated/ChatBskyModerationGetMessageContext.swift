import Foundation



// lexicon: 1, id: chat.bsky.moderation.getMessageContext


public struct ChatBskyModerationGetMessageContext { 

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
            
            
            self.messages = try container.decode([OutputMessagesUnion].self, forKey: .messages)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(messages, forKey: .messages)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let messagesValue = try (messages as? DAGCBOREncodable)?.toCBORValue() ?? messages
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
        case .chatBskyConvoDefsMessageView(let value):
            try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsDeletedMessageView(let value):
            try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .chatBskyConvoDefsMessageView(let value):
            hasher.combine("chat.bsky.convo.defs#messageView")
            hasher.combine(value)
        case .chatBskyConvoDefsDeletedMessageView(let value):
            hasher.combine("chat.bsky.convo.defs#deletedMessageView")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputMessagesUnion, rhs: OutputMessagesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.chatBskyConvoDefsMessageView(let lhsValue),
              .chatBskyConvoDefsMessageView(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsDeletedMessageView(let lhsValue),
              .chatBskyConvoDefsDeletedMessageView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
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
        case .chatBskyConvoDefsMessageView(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")
            
            // Add the value's fields while preserving their order
            if let encodableValue = value as? DAGCBOREncodable {
                let valueDict = try encodableValue.toCBORValue()
                
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
            }
            return map
        case .chatBskyConvoDefsDeletedMessageView(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")
            
            // Add the value's fields while preserving their order
            if let encodableValue = value as? DAGCBOREncodable {
                let valueDict = try encodableValue.toCBORValue()
                
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
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .chatBskyConvoDefsMessageView(let value):
            return value.hasPendingData
        case .chatBskyConvoDefsDeletedMessageView(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .chatBskyConvoDefsMessageView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .chatBskyConvoDefsMessageView(value)
        case .chatBskyConvoDefsDeletedMessageView(var value):
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


extension ATProtoClient.Chat.Bsky.Moderation {
    /// 
    public func getMessageContext(input: ChatBskyModerationGetMessageContext.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetMessageContext.Output?) {
        let endpoint = "chat.bsky.moderation.getMessageContext"
        
        
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
        let decodedData = try? decoder.decode(ChatBskyModerationGetMessageContext.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
