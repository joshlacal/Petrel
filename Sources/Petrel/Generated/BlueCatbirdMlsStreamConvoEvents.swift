import Foundation



// lexicon: 1, id: blue.catbird.mls.streamConvoEvents


public struct BlueCatbirdMlsStreamConvoEvents { 

    public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents"
        
public struct EventWrapper: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#eventWrapper"
            public let event: EventWrapperEventUnion

        // Standard initializer
        public init(
            event: EventWrapperEventUnion
        ) {
            
            self.event = event
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.event = try container.decode(EventWrapperEventUnion.self, forKey: .event)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'event': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(event, forKey: .event)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(event)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.event != other.event {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let eventValue = try event.toCBORValue()
            map = map.adding(key: "event", value: eventValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case event
        }
    }
        
public struct MessageEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#messageEvent"
            public let cursor: String
            public let message: BlueCatbirdMlsDefs.MessageView

        // Standard initializer
        public init(
            cursor: String, message: BlueCatbirdMlsDefs.MessageView
        ) {
            
            self.cursor = cursor
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.message = try container.decode(BlueCatbirdMlsDefs.MessageView.self, forKey: .message)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'message': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(message, forKey: .message)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(message)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.message != other.message {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case message
        }
    }
        
public struct ReactionEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#reactionEvent"
            public let cursor: String
            public let convoId: String
            public let messageId: String
            public let did: DID
            public let reaction: String
            public let action: String

        // Standard initializer
        public init(
            cursor: String, convoId: String, messageId: String, did: DID, reaction: String, action: String
        ) {
            
            self.cursor = cursor
            self.convoId = convoId
            self.messageId = messageId
            self.did = did
            self.reaction = reaction
            self.action = action
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.messageId = try container.decode(String.self, forKey: .messageId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'messageId': \(error)")
                
                throw error
            }
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.reaction = try container.decode(String.self, forKey: .reaction)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'reaction': \(error)")
                
                throw error
            }
            do {
                
                
                self.action = try container.decode(String.self, forKey: .action)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'action': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(messageId, forKey: .messageId)
            
            
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(reaction, forKey: .reaction)
            
            
            
            
            try container.encode(action, forKey: .action)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(messageId)
            hasher.combine(did)
            hasher.combine(reaction)
            hasher.combine(action)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.messageId != other.messageId {
                return false
            }
            
            
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.reaction != other.reaction {
                return false
            }
            
            
            
            
            if self.action != other.action {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)
            
            
            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let reactionValue = try reaction.toCBORValue()
            map = map.adding(key: "reaction", value: reactionValue)
            
            
            
            
            
            
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case messageId
            case did
            case reaction
            case action
        }
    }
        
public struct TypingEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#typingEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let isTyping: Bool

        // Standard initializer
        public init(
            cursor: String, convoId: String, did: DID, isTyping: Bool
        ) {
            
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.isTyping = isTyping
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.isTyping = try container.decode(Bool.self, forKey: .isTyping)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'isTyping': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(isTyping, forKey: .isTyping)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            hasher.combine(isTyping)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.isTyping != other.isTyping {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let isTypingValue = try isTyping.toCBORValue()
            map = map.adding(key: "isTyping", value: isTypingValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case isTyping
        }
    }
        
public struct InfoEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#infoEvent"
            public let cursor: String
            public let info: String

        // Standard initializer
        public init(
            cursor: String, info: String
        ) {
            
            self.cursor = cursor
            self.info = info
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.info = try container.decode(String.self, forKey: .info)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'info': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(info, forKey: .info)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(info)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.info != other.info {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let infoValue = try info.toCBORValue()
            map = map.adding(key: "info", value: infoValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case info
        }
    }    
public struct Parameters: Parametrizable {
        public let cursor: String?
        public let convoId: String?
        
        public init(
            cursor: String? = nil, 
            convoId: String? = nil
            ) {
            self.cursor = cursor
            self.convoId = convoId
            
        }
    }
    public typealias Output = EventWrapper
    





public enum EventWrapperEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case blueCatbirdMlsStreamConvoEventsMessageEvent(BlueCatbirdMlsStreamConvoEvents.MessageEvent)
    case blueCatbirdMlsStreamConvoEventsReactionEvent(BlueCatbirdMlsStreamConvoEvents.ReactionEvent)
    case blueCatbirdMlsStreamConvoEventsTypingEvent(BlueCatbirdMlsStreamConvoEvents.TypingEvent)
    case blueCatbirdMlsStreamConvoEventsInfoEvent(BlueCatbirdMlsStreamConvoEvents.InfoEvent)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: BlueCatbirdMlsStreamConvoEvents.MessageEvent) {
        self = .blueCatbirdMlsStreamConvoEventsMessageEvent(value)
    }
    public init(_ value: BlueCatbirdMlsStreamConvoEvents.ReactionEvent) {
        self = .blueCatbirdMlsStreamConvoEventsReactionEvent(value)
    }
    public init(_ value: BlueCatbirdMlsStreamConvoEvents.TypingEvent) {
        self = .blueCatbirdMlsStreamConvoEventsTypingEvent(value)
    }
    public init(_ value: BlueCatbirdMlsStreamConvoEvents.InfoEvent) {
        self = .blueCatbirdMlsStreamConvoEventsInfoEvent(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "blue.catbird.mls.streamConvoEvents#messageEvent":
            let value = try BlueCatbirdMlsStreamConvoEvents.MessageEvent(from: decoder)
            self = .blueCatbirdMlsStreamConvoEventsMessageEvent(value)
        case "blue.catbird.mls.streamConvoEvents#reactionEvent":
            let value = try BlueCatbirdMlsStreamConvoEvents.ReactionEvent(from: decoder)
            self = .blueCatbirdMlsStreamConvoEventsReactionEvent(value)
        case "blue.catbird.mls.streamConvoEvents#typingEvent":
            let value = try BlueCatbirdMlsStreamConvoEvents.TypingEvent(from: decoder)
            self = .blueCatbirdMlsStreamConvoEventsTypingEvent(value)
        case "blue.catbird.mls.streamConvoEvents#infoEvent":
            let value = try BlueCatbirdMlsStreamConvoEvents.InfoEvent(from: decoder)
            self = .blueCatbirdMlsStreamConvoEventsInfoEvent(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .blueCatbirdMlsStreamConvoEventsMessageEvent(let value):
            try container.encode("blue.catbird.mls.streamConvoEvents#messageEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsStreamConvoEventsReactionEvent(let value):
            try container.encode("blue.catbird.mls.streamConvoEvents#reactionEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsStreamConvoEventsTypingEvent(let value):
            try container.encode("blue.catbird.mls.streamConvoEvents#typingEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsStreamConvoEventsInfoEvent(let value):
            try container.encode("blue.catbird.mls.streamConvoEvents#infoEvent", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .blueCatbirdMlsStreamConvoEventsMessageEvent(let value):
            hasher.combine("blue.catbird.mls.streamConvoEvents#messageEvent")
            hasher.combine(value)
        case .blueCatbirdMlsStreamConvoEventsReactionEvent(let value):
            hasher.combine("blue.catbird.mls.streamConvoEvents#reactionEvent")
            hasher.combine(value)
        case .blueCatbirdMlsStreamConvoEventsTypingEvent(let value):
            hasher.combine("blue.catbird.mls.streamConvoEvents#typingEvent")
            hasher.combine(value)
        case .blueCatbirdMlsStreamConvoEventsInfoEvent(let value):
            hasher.combine("blue.catbird.mls.streamConvoEvents#infoEvent")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: EventWrapperEventUnion, rhs: EventWrapperEventUnion) -> Bool {
        switch (lhs, rhs) {
        case (.blueCatbirdMlsStreamConvoEventsMessageEvent(let lhsValue),
              .blueCatbirdMlsStreamConvoEventsMessageEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsStreamConvoEventsReactionEvent(let lhsValue),
              .blueCatbirdMlsStreamConvoEventsReactionEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsStreamConvoEventsTypingEvent(let lhsValue),
              .blueCatbirdMlsStreamConvoEventsTypingEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsStreamConvoEventsInfoEvent(let lhsValue),
              .blueCatbirdMlsStreamConvoEventsInfoEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? EventWrapperEventUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .blueCatbirdMlsStreamConvoEventsMessageEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mls.streamConvoEvents#messageEvent")
            
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
        case .blueCatbirdMlsStreamConvoEventsReactionEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mls.streamConvoEvents#reactionEvent")
            
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
        case .blueCatbirdMlsStreamConvoEventsTypingEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mls.streamConvoEvents#typingEvent")
            
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
        case .blueCatbirdMlsStreamConvoEventsInfoEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mls.streamConvoEvents#infoEvent")
            
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
}


}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - streamConvoEvents

    /// Server-Sent Events stream for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via Server-Sent Events in conversations involving the authenticated user
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: AsyncThrowingStream of events from the Server-Sent Events stream
    /// - Throws: NetworkError if the request fails or the connection cannot be established
    public func streamConvoEvents(input: BlueCatbirdMlsStreamConvoEvents.Parameters) async throws -> AsyncThrowingStream<BlueCatbirdMlsStreamConvoEvents.Output, Error> {
        let endpoint = "blue.catbird.mls.streamConvoEvents"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "text/event-stream"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.streamConvoEvents")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Use networkService to prepare authenticated streaming request with OAuth/DPoP
                    let authenticatedRequest = try await networkService.prepareStreamingRequest(
                        urlRequest,
                        additionalHeaders: proxyHeaders
                    )

                    // Create URLSession with infinite timeouts for SSE long-lived connections
                    let configuration = URLSessionConfiguration.default
                    configuration.timeoutIntervalForRequest = .infinity  // No request timeout for SSE
                    configuration.timeoutIntervalForResource = .infinity // No resource timeout for SSE
                    configuration.waitsForConnectivity = true            // Wait for network
                    let sseSession = URLSession(configuration: configuration)

                    // Stream with the authenticated request using SSE-configured session
                    let (bytes, response) = try await sseSession.bytes(for: authenticatedRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: NetworkError.invalidResponse(description: "Non-HTTP response"))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: NetworkError.serverError(code: httpResponse.statusCode, message: "SSE connection failed"))
                        return
                    }

                    guard let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
                          contentType.lowercased().contains("text/event-stream") else {
                        continuation.finish(throwing: NetworkError.invalidContentType(expected: "text/event-stream", actual: httpResponse.allHeaderFields["Content-Type"] as? String ?? "nil"))
                        return
                    }

                    // Parse SSE stream
                    var buffer = ""
                    let decoder = JSONDecoder()

                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)

                        // SSE events are delimited by double newline
                        if buffer.hasSuffix("\n\n") {
                            // Parse the event
                            let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)

                            for line in lines {
                                let lineStr = String(line)

                                // SSE data lines start with "data: "
                                if lineStr.hasPrefix("data: ") {
                                    let jsonString = String(lineStr.dropFirst(6))

                                    if let jsonData = jsonString.data(using: .utf8) {
                                        do {
                                            let event = try decoder.decode(BlueCatbirdMlsStreamConvoEvents.Output.self, from: jsonData)
                                            continuation.yield(event)
                                        } catch {
                                            LogManager.logError("Failed to decode SSE event for blue.catbird.mls.streamConvoEvents: \(error)")
                                            // Continue processing other events
                                        }
                                    }
                                }
                                // Ignore comment lines (start with ":") and other SSE fields
                            }

                            buffer = ""
                        }
                    }

                    // Stream ended normally
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
                           

