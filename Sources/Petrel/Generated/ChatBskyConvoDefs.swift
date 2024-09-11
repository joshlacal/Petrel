import Foundation
internal import ZippyJSON

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
                did = try container.decode(String.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                messageId = try container.decode(String.self, forKey: .messageId)

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

            if did != other.did {
                return false
            }

            if convoId != other.convoId {
                return false
            }

            if messageId != other.messageId {
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
                text = try container.decode(String.self, forKey: .text)

            } catch {
                LogManager.logError("Decoding error for property 'text': \(error)")
                throw error
            }
            do {
                facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)

            } catch {
                LogManager.logError("Decoding error for property 'facets': \(error)")
                throw error
            }
            do {
                embed = try container.decodeIfPresent(MessageInputEmbedUnion.self, forKey: .embed)

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

            if text != other.text {
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
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                text = try container.decode(String.self, forKey: .text)

            } catch {
                LogManager.logError("Decoding error for property 'text': \(error)")
                throw error
            }
            do {
                facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)

            } catch {
                LogManager.logError("Decoding error for property 'facets': \(error)")
                throw error
            }
            do {
                embed = try container.decodeIfPresent(MessageViewEmbedUnion.self, forKey: .embed)

            } catch {
                LogManager.logError("Decoding error for property 'embed': \(error)")
                throw error
            }
            do {
                sender = try container.decode(MessageViewSender.self, forKey: .sender)

            } catch {
                LogManager.logError("Decoding error for property 'sender': \(error)")
                throw error
            }
            do {
                sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)

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

            if id != other.id {
                return false
            }

            if rev != other.rev {
                return false
            }

            if text != other.text {
                return false
            }

            if facets != other.facets {
                return false
            }

            if embed != other.embed {
                return false
            }

            if sender != other.sender {
                return false
            }

            if sentAt != other.sentAt {
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
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                sender = try container.decode(MessageViewSender.self, forKey: .sender)

            } catch {
                LogManager.logError("Decoding error for property 'sender': \(error)")
                throw error
            }
            do {
                sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)

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

            if id != other.id {
                return false
            }

            if rev != other.rev {
                return false
            }

            if sender != other.sender {
                return false
            }

            if sentAt != other.sentAt {
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
                did = try container.decode(String.self, forKey: .did)

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

            if did != other.did {
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
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                members = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .members)

            } catch {
                LogManager.logError("Decoding error for property 'members': \(error)")
                throw error
            }
            do {
                lastMessage = try container.decodeIfPresent(ConvoViewLastMessageUnion.self, forKey: .lastMessage)

            } catch {
                LogManager.logError("Decoding error for property 'lastMessage': \(error)")
                throw error
            }
            do {
                muted = try container.decode(Bool.self, forKey: .muted)

            } catch {
                LogManager.logError("Decoding error for property 'muted': \(error)")
                throw error
            }
            do {
                unreadCount = try container.decode(Int.self, forKey: .unreadCount)

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

            if id != other.id {
                return false
            }

            if rev != other.rev {
                return false
            }

            if members != other.members {
                return false
            }

            if lastMessage != other.lastMessage {
                return false
            }

            if muted != other.muted {
                return false
            }

            if unreadCount != other.unreadCount {
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
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

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

            if rev != other.rev {
                return false
            }

            if convoId != other.convoId {
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
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

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

            if rev != other.rev {
                return false
            }

            if convoId != other.convoId {
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
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogCreateMessageMessageUnion.self, forKey: .message)

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

            if rev != other.rev {
                return false
            }

            if convoId != other.convoId {
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
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogDeleteMessageMessageUnion.self, forKey: .message)

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

            if rev != other.rev {
                return false
            }

            if convoId != other.convoId {
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
            LogManager.logDebug("MessageInputEmbedUnion decoding: \(typeValue)")

            switch typeValue {
            case "app.bsky.embed.record":
                LogManager.logDebug("Decoding as app.bsky.embed.record")
                let value = try AppBskyEmbedRecord(from: decoder)
                self = .appBskyEmbedRecord(value)
            default:
                LogManager.logDebug("MessageInputEmbedUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedRecord(value):
                LogManager.logDebug("Encoding app.bsky.embed.record")
                try container.encode("app.bsky.embed.record", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("MessageInputEmbedUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedRecord(value):
                hasher.combine("app.bsky.embed.record")
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
            guard let otherValue = other as? MessageInputEmbedUnion else { return false }

            switch (self, otherValue) {
            case let (.appBskyEmbedRecord(selfValue),
                      .appBskyEmbedRecord(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            LogManager.logDebug("MessageViewEmbedUnion decoding: \(typeValue)")

            switch typeValue {
            case "app.bsky.embed.record#view":
                LogManager.logDebug("Decoding as app.bsky.embed.record#view")
                let value = try AppBskyEmbedRecord.View(from: decoder)
                self = .appBskyEmbedRecordView(value)
            default:
                LogManager.logDebug("MessageViewEmbedUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedRecordView(value):
                LogManager.logDebug("Encoding app.bsky.embed.record#view")
                try container.encode("app.bsky.embed.record#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("MessageViewEmbedUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedRecordView(value):
                hasher.combine("app.bsky.embed.record#view")
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
            guard let otherValue = other as? MessageViewEmbedUnion else { return false }

            switch (self, otherValue) {
            case let (.appBskyEmbedRecordView(selfValue),
                      .appBskyEmbedRecordView(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            LogManager.logDebug("ConvoViewLastMessageUnion decoding: \(typeValue)")

            switch typeValue {
            case "chat.bsky.convo.defs#messageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#messageView")
                let value = try ChatBskyConvoDefs.MessageView(from: decoder)
                self = .chatBskyConvoDefsMessageView(value)
            case "chat.bsky.convo.defs#deletedMessageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#deletedMessageView")
                let value = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                self = .chatBskyConvoDefsDeletedMessageView(value)
            default:
                LogManager.logDebug("ConvoViewLastMessageUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#messageView")
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#deletedMessageView")
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ConvoViewLastMessageUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
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
            case let (.chatBskyConvoDefsMessageView(selfValue),
                      .chatBskyConvoDefsMessageView(otherValue)):
                return selfValue == otherValue
            case let (.chatBskyConvoDefsDeletedMessageView(selfValue),
                      .chatBskyConvoDefsDeletedMessageView(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            LogManager.logDebug("LogCreateMessageMessageUnion decoding: \(typeValue)")

            switch typeValue {
            case "chat.bsky.convo.defs#messageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#messageView")
                let value = try ChatBskyConvoDefs.MessageView(from: decoder)
                self = .chatBskyConvoDefsMessageView(value)
            case "chat.bsky.convo.defs#deletedMessageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#deletedMessageView")
                let value = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                self = .chatBskyConvoDefsDeletedMessageView(value)
            default:
                LogManager.logDebug("LogCreateMessageMessageUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#messageView")
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#deletedMessageView")
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("LogCreateMessageMessageUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
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
            case let (.chatBskyConvoDefsMessageView(selfValue),
                      .chatBskyConvoDefsMessageView(otherValue)):
                return selfValue == otherValue
            case let (.chatBskyConvoDefsDeletedMessageView(selfValue),
                      .chatBskyConvoDefsDeletedMessageView(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            LogManager.logDebug("LogDeleteMessageMessageUnion decoding: \(typeValue)")

            switch typeValue {
            case "chat.bsky.convo.defs#messageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#messageView")
                let value = try ChatBskyConvoDefs.MessageView(from: decoder)
                self = .chatBskyConvoDefsMessageView(value)
            case "chat.bsky.convo.defs#deletedMessageView":
                LogManager.logDebug("Decoding as chat.bsky.convo.defs#deletedMessageView")
                let value = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                self = .chatBskyConvoDefsDeletedMessageView(value)
            default:
                LogManager.logDebug("LogDeleteMessageMessageUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#messageView")
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                LogManager.logDebug("Encoding chat.bsky.convo.defs#deletedMessageView")
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("LogDeleteMessageMessageUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
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
            case let (.chatBskyConvoDefsMessageView(selfValue),
                      .chatBskyConvoDefsMessageView(otherValue)):
                return selfValue == otherValue
            case let (.chatBskyConvoDefsDeletedMessageView(selfValue),
                      .chatBskyConvoDefsDeletedMessageView(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}
