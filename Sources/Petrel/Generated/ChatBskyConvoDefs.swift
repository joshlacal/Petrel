import Foundation
import ZippyJSON


// lexicon: 1, id: chat.bsky.convo.defs


public struct ChatBskyConvoDefs { 

    public static let typeIdentifier = "chat.bsky.convo.defs"
        
public struct MessageRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#messageRef"
            public let did: String
            public let convoId: String
            public let messageId: String

        // Standard initializer
        public init(
            did: String, convoId: String, messageId: String
        ) {
            
            self.did = did
            self.convoId = convoId
            self.messageId = messageId
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                
                self.messageId = try container.decode(String.self, forKey: .messageId)
                
            } catch {
                LogManager.logError("Decoding error for property 'messageId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(messageId, forKey: .messageId)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(convoId)
            hasher.combine(messageId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            if self.messageId != other.messageId {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case convoId
            case messageId
        }
    }
        
public struct MessageInput: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#messageInput"
            public let text: String
            public let facets: [AppBskyRichtextFacet]?
            public let embed: MessageInputEmbedUnion?

        // Standard initializer
        public init(
            text: String, facets: [AppBskyRichtextFacet]?, embed: MessageInputEmbedUnion?
        ) {
            
            self.text = text
            self.facets = facets
            self.embed = embed
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.text = try container.decode(String.self, forKey: .text)
                
            } catch {
                LogManager.logError("Decoding error for property 'text': \(error)")
                throw error
            }
            do {
                
                self.facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)
                
            } catch {
                LogManager.logError("Decoding error for property 'facets': \(error)")
                throw error
            }
            do {
                
                self.embed = try container.decodeIfPresent(MessageInputEmbedUnion.self, forKey: .embed)
                
            } catch {
                LogManager.logError("Decoding error for property 'embed': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(text, forKey: .text)
            
            
            if let value = facets {
                try container.encode(value, forKey: .facets)
            }
            
            
            if let value = embed {
                try container.encode(value, forKey: .embed)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            if let value = facets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.text != other.text {
                return false
            }
            
            
            if facets != other.facets {
                return false
            }
            
            
            if embed != other.embed {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case text
            case facets
            case embed
        }
    }
        
public struct MessageView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#messageView"
            public let id: String
            public let rev: String
            public let text: String
            public let facets: [AppBskyRichtextFacet]?
            public let embed: MessageViewEmbedUnion?
            public let sender: MessageViewSender
            public let sentAt: ATProtocolDate

        // Standard initializer
        public init(
            id: String, rev: String, text: String, facets: [AppBskyRichtextFacet]?, embed: MessageViewEmbedUnion?, sender: MessageViewSender, sentAt: ATProtocolDate
        ) {
            
            self.id = id
            self.rev = rev
            self.text = text
            self.facets = facets
            self.embed = embed
            self.sender = sender
            self.sentAt = sentAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.id = try container.decode(String.self, forKey: .id)
                
            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.text = try container.decode(String.self, forKey: .text)
                
            } catch {
                LogManager.logError("Decoding error for property 'text': \(error)")
                throw error
            }
            do {
                
                self.facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)
                
            } catch {
                LogManager.logError("Decoding error for property 'facets': \(error)")
                throw error
            }
            do {
                
                self.embed = try container.decodeIfPresent(MessageViewEmbedUnion.self, forKey: .embed)
                
            } catch {
                LogManager.logError("Decoding error for property 'embed': \(error)")
                throw error
            }
            do {
                
                self.sender = try container.decode(MessageViewSender.self, forKey: .sender)
                
            } catch {
                LogManager.logError("Decoding error for property 'sender': \(error)")
                throw error
            }
            do {
                
                self.sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'sentAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(id, forKey: .id)
            
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(text, forKey: .text)
            
            
            if let value = facets {
                try container.encode(value, forKey: .facets)
            }
            
            
            if let value = embed {
                try container.encode(value, forKey: .embed)
            }
            
            
            try container.encode(sender, forKey: .sender)
            
            
            try container.encode(sentAt, forKey: .sentAt)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(rev)
            hasher.combine(text)
            if let value = facets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(sender)
            hasher.combine(sentAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.id != other.id {
                return false
            }
            
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.text != other.text {
                return false
            }
            
            
            if facets != other.facets {
                return false
            }
            
            
            if embed != other.embed {
                return false
            }
            
            
            if self.sender != other.sender {
                return false
            }
            
            
            if self.sentAt != other.sentAt {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case text
            case facets
            case embed
            case sender
            case sentAt
        }
    }
        
public struct DeletedMessageView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#deletedMessageView"
            public let id: String
            public let rev: String
            public let sender: MessageViewSender
            public let sentAt: ATProtocolDate

        // Standard initializer
        public init(
            id: String, rev: String, sender: MessageViewSender, sentAt: ATProtocolDate
        ) {
            
            self.id = id
            self.rev = rev
            self.sender = sender
            self.sentAt = sentAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.id = try container.decode(String.self, forKey: .id)
                
            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.sender = try container.decode(MessageViewSender.self, forKey: .sender)
                
            } catch {
                LogManager.logError("Decoding error for property 'sender': \(error)")
                throw error
            }
            do {
                
                self.sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'sentAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(id, forKey: .id)
            
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(sender, forKey: .sender)
            
            
            try container.encode(sentAt, forKey: .sentAt)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(rev)
            hasher.combine(sender)
            hasher.combine(sentAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.id != other.id {
                return false
            }
            
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.sender != other.sender {
                return false
            }
            
            
            if self.sentAt != other.sentAt {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case sender
            case sentAt
        }
    }
        
public struct MessageViewSender: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#messageViewSender"
            public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }
        
public struct ConvoView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#convoView"
            public let id: String
            public let rev: String
            public let members: [ChatBskyActorDefs.ProfileViewBasic]
            public let lastMessage: ConvoViewLastMessageUnion?
            public let muted: Bool
            public let unreadCount: Int

        // Standard initializer
        public init(
            id: String, rev: String, members: [ChatBskyActorDefs.ProfileViewBasic], lastMessage: ConvoViewLastMessageUnion?, muted: Bool, unreadCount: Int
        ) {
            
            self.id = id
            self.rev = rev
            self.members = members
            self.lastMessage = lastMessage
            self.muted = muted
            self.unreadCount = unreadCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.id = try container.decode(String.self, forKey: .id)
                
            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.members = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .members)
                
            } catch {
                LogManager.logError("Decoding error for property 'members': \(error)")
                throw error
            }
            do {
                
                self.lastMessage = try container.decodeIfPresent(ConvoViewLastMessageUnion.self, forKey: .lastMessage)
                
            } catch {
                LogManager.logError("Decoding error for property 'lastMessage': \(error)")
                throw error
            }
            do {
                
                self.muted = try container.decode(Bool.self, forKey: .muted)
                
            } catch {
                LogManager.logError("Decoding error for property 'muted': \(error)")
                throw error
            }
            do {
                
                self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'unreadCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(id, forKey: .id)
            
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(members, forKey: .members)
            
            
            if let value = lastMessage {
                try container.encode(value, forKey: .lastMessage)
            }
            
            
            try container.encode(muted, forKey: .muted)
            
            
            try container.encode(unreadCount, forKey: .unreadCount)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(rev)
            hasher.combine(members)
            if let value = lastMessage {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(muted)
            hasher.combine(unreadCount)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.id != other.id {
                return false
            }
            
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.members != other.members {
                return false
            }
            
            
            if lastMessage != other.lastMessage {
                return false
            }
            
            
            if self.muted != other.muted {
                return false
            }
            
            
            if self.unreadCount != other.unreadCount {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case members
            case lastMessage
            case muted
            case unreadCount
        }
    }
        
public struct LogBeginConvo: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#logBeginConvo"
            public let rev: String
            public let convoId: String

        // Standard initializer
        public init(
            rev: String, convoId: String
        ) {
            
            self.rev = rev
            self.convoId = convoId
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(convoId, forKey: .convoId)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }
        
public struct LogLeaveConvo: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#logLeaveConvo"
            public let rev: String
            public let convoId: String

        // Standard initializer
        public init(
            rev: String, convoId: String
        ) {
            
            self.rev = rev
            self.convoId = convoId
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(convoId, forKey: .convoId)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }
        
public struct LogCreateMessage: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#logCreateMessage"
            public let rev: String
            public let convoId: String
            public let message: LogCreateMessageMessageUnion

        // Standard initializer
        public init(
            rev: String, convoId: String, message: LogCreateMessageMessageUnion
        ) {
            
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                
                self.message = try container.decode(LogCreateMessageMessageUnion.self, forKey: .message)
                
            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(message, forKey: .message)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.convoId != other.convoId {
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
        }
    }
        
public struct LogDeleteMessage: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.convo.defs#logDeleteMessage"
            public let rev: String
            public let convoId: String
            public let message: LogDeleteMessageMessageUnion

        // Standard initializer
        public init(
            rev: String, convoId: String, message: LogDeleteMessageMessageUnion
        ) {
            
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.rev = try container.decode(String.self, forKey: .rev)
                
            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                
                self.message = try container.decode(LogDeleteMessageMessageUnion.self, forKey: .message)
                
            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(rev, forKey: .rev)
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(message, forKey: .message)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.rev != other.rev {
                return false
            }
            
            
            if self.convoId != other.convoId {
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
        }
    }





public enum MessageInputEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyEmbedRecord(AppBskyEmbedRecord)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.embed.record":
            let value = try AppBskyEmbedRecord(from: decoder)
            self = .appBskyEmbedRecord(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyEmbedRecord(let value):
            try container.encode("app.bsky.embed.record", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedRecord(let value):
            hasher.combine("app.bsky.embed.record")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? MessageInputEmbedUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyEmbedRecord(let selfValue), 
                .appBskyEmbedRecord(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum MessageViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.embed.record#view":
            let value = try AppBskyEmbedRecord.View(from: decoder)
            self = .appBskyEmbedRecordView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyEmbedRecordView(let value):
            try container.encode("app.bsky.embed.record#view", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedRecordView(let value):
            hasher.combine("app.bsky.embed.record#view")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? MessageViewEmbedUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyEmbedRecordView(let selfValue), 
                .appBskyEmbedRecordView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum ConvoViewLastMessageUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
    case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
    case unexpected(ATProtocolValueContainer)

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
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
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
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ConvoViewLastMessageUnion else { return false }

        switch (self, otherValue) {
            case (.chatBskyConvoDefsMessageView(let selfValue), 
                .chatBskyConvoDefsMessageView(let otherValue)):
                return selfValue == otherValue
            case (.chatBskyConvoDefsDeletedMessageView(let selfValue), 
                .chatBskyConvoDefsDeletedMessageView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum LogCreateMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
    case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
    case unexpected(ATProtocolValueContainer)

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
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
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
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? LogCreateMessageMessageUnion else { return false }

        switch (self, otherValue) {
            case (.chatBskyConvoDefsMessageView(let selfValue), 
                .chatBskyConvoDefsMessageView(let otherValue)):
                return selfValue == otherValue
            case (.chatBskyConvoDefsDeletedMessageView(let selfValue), 
                .chatBskyConvoDefsDeletedMessageView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum LogDeleteMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
    case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
    case unexpected(ATProtocolValueContainer)

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
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
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
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? LogDeleteMessageMessageUnion else { return false }

        switch (self, otherValue) {
            case (.chatBskyConvoDefsMessageView(let selfValue), 
                .chatBskyConvoDefsMessageView(let otherValue)):
                return selfValue == otherValue
            case (.chatBskyConvoDefsDeletedMessageView(let selfValue), 
                .chatBskyConvoDefsDeletedMessageView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}


                           
