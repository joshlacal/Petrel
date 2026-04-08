import Foundation



// lexicon: 1, id: place.stream.chat.defs


public struct PlaceStreamChatDefs { 

    public static let typeIdentifier = "place.stream.chat.defs"
        
public struct MessageView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.chat.defs#messageView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let author: AppBskyActorDefs.ProfileViewBasic
            public let record: ATProtocolValueContainer
            public let indexedAt: ATProtocolDate
            public let chatProfile: PlaceStreamChatProfile?
            public let replyTo: MessageViewReplyToUnion?
            public let deleted: Bool?
            public let badges: [PlaceStreamBadgeDefs.BadgeView]?

        public init(
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer, indexedAt: ATProtocolDate, chatProfile: PlaceStreamChatProfile?, replyTo: MessageViewReplyToUnion?, deleted: Bool?, badges: [PlaceStreamBadgeDefs.BadgeView]?
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.record = record
            self.indexedAt = indexedAt
            self.chatProfile = chatProfile
            self.replyTo = replyTo
            self.deleted = deleted
            self.badges = badges
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)
            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
            do {
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")
                throw error
            }
            do {
                self.chatProfile = try container.decodeIfPresent(PlaceStreamChatProfile.self, forKey: .chatProfile)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'chatProfile': \(error)")
                throw error
            }
            do {
                self.replyTo = try container.decodeIfPresent(MessageViewReplyToUnion.self, forKey: .replyTo)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'replyTo': \(error)")
                throw error
            }
            do {
                self.deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deleted': \(error)")
                throw error
            }
            do {
                self.badges = try container.decodeIfPresent([PlaceStreamBadgeDefs.BadgeView].self, forKey: .badges)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'badges': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(author, forKey: .author)
            try container.encode(record, forKey: .record)
            try container.encode(indexedAt, forKey: .indexedAt)
            try container.encodeIfPresent(chatProfile, forKey: .chatProfile)
            try container.encodeIfPresent(replyTo, forKey: .replyTo)
            try container.encodeIfPresent(deleted, forKey: .deleted)
            try container.encodeIfPresent(badges, forKey: .badges)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(record)
            hasher.combine(indexedAt)
            if let value = chatProfile {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = replyTo {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deleted {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = badges {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if author != other.author {
                return false
            }
            if record != other.record {
                return false
            }
            if indexedAt != other.indexedAt {
                return false
            }
            if chatProfile != other.chatProfile {
                return false
            }
            if replyTo != other.replyTo {
                return false
            }
            if deleted != other.deleted {
                return false
            }
            if badges != other.badges {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            if let value = chatProfile {
                let chatProfileValue = try value.toCBORValue()
                map = map.adding(key: "chatProfile", value: chatProfileValue)
            }
            if let value = replyTo {
                let replyToValue = try value.toCBORValue()
                map = map.adding(key: "replyTo", value: replyToValue)
            }
            if let value = deleted {
                let deletedValue = try value.toCBORValue()
                map = map.adding(key: "deleted", value: deletedValue)
            }
            if let value = badges {
                let badgesValue = try value.toCBORValue()
                map = map.adding(key: "badges", value: badgesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case record
            case indexedAt
            case chatProfile
            case replyTo
            case deleted
            case badges
        }
    }
        
public struct PinnedRecordView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.chat.defs#pinnedRecordView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let record: PlaceStreamChatPinnedRecord
            public let indexedAt: ATProtocolDate
            public let pinnedBy: PlaceStreamChatProfile?
            public let message: MessageView?

        public init(
            uri: ATProtocolURI, cid: CID, record: PlaceStreamChatPinnedRecord, indexedAt: ATProtocolDate, pinnedBy: PlaceStreamChatProfile?, message: MessageView?
        ) {
            self.uri = uri
            self.cid = cid
            self.record = record
            self.indexedAt = indexedAt
            self.pinnedBy = pinnedBy
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(PlaceStreamChatPinnedRecord.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
            do {
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")
                throw error
            }
            do {
                self.pinnedBy = try container.decodeIfPresent(PlaceStreamChatProfile.self, forKey: .pinnedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'pinnedBy': \(error)")
                throw error
            }
            do {
                self.message = try container.decodeIfPresent(MessageView.self, forKey: .message)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(record, forKey: .record)
            try container.encode(indexedAt, forKey: .indexedAt)
            try container.encodeIfPresent(pinnedBy, forKey: .pinnedBy)
            try container.encodeIfPresent(message, forKey: .message)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(record)
            hasher.combine(indexedAt)
            if let value = pinnedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = message {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if record != other.record {
                return false
            }
            if indexedAt != other.indexedAt {
                return false
            }
            if pinnedBy != other.pinnedBy {
                return false
            }
            if message != other.message {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            if let value = pinnedBy {
                let pinnedByValue = try value.toCBORValue()
                map = map.adding(key: "pinnedBy", value: pinnedByValue)
            }
            if let value = message {
                let messageValue = try value.toCBORValue()
                map = map.adding(key: "message", value: messageValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case record
            case indexedAt
            case pinnedBy
            case message
        }
    }




public indirect enum MessageViewReplyToUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case placeStreamChatDefsMessageView(PlaceStreamChatDefs.MessageView)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: PlaceStreamChatDefs.MessageView) {
        self = .placeStreamChatDefsMessageView(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "place.stream.chat.defs#messageView":
            let value = try PlaceStreamChatDefs.MessageView(from: decoder)
            self = .placeStreamChatDefsMessageView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .placeStreamChatDefsMessageView(let value):
            try container.encode("place.stream.chat.defs#messageView", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .placeStreamChatDefsMessageView(let value):
            hasher.combine("place.stream.chat.defs#messageView")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: MessageViewReplyToUnion, rhs: MessageViewReplyToUnion) -> Bool {
        switch (lhs, rhs) {
        case (.placeStreamChatDefsMessageView(let lhsValue),
              .placeStreamChatDefsMessageView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? MessageViewReplyToUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .placeStreamChatDefsMessageView(let value):
            map = map.adding(key: "$type", value: "place.stream.chat.defs#messageView")
            
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


                           

