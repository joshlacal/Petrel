import Foundation

// lexicon: 1, id: chat.bsky.convo.defs

public enum ChatBskyConvoDefs {
    public static let typeIdentifier = "chat.bsky.convo.defs"

    public struct MessageRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#messageRef"
        public let did: DID
        public let convoId: String
        public let messageId: String

        // Standard initializer
        public init(
            did: DID, convoId: String, messageId: String
        ) {
            self.did = did
            self.convoId = convoId
            self.messageId = messageId
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageIdValue = try (messageId as? DAGCBOREncodable)?.toCBORValue() ?? messageId
            map = map.adding(key: "messageId", value: messageIdValue)

            return map
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

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(facets, forKey: .facets)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embed, forKey: .embed)
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let textValue = try (text as? DAGCBOREncodable)?.toCBORValue() ?? text
            map = map.adding(key: "text", value: textValue)

            if let value = facets {
                // Encode optional property even if it's an empty array for CBOR

                let facetsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "facets", value: facetsValue)
            }

            if let value = embed {
                // Encode optional property even if it's an empty array for CBOR

                let embedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "embed", value: embedValue)
            }

            return map
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
        public let reactions: [ReactionView]?
        public let sender: MessageViewSender
        public let sentAt: ATProtocolDate

        // Standard initializer
        public init(
            id: String, rev: String, text: String, facets: [AppBskyRichtextFacet]?, embed: MessageViewEmbedUnion?, reactions: [ReactionView]?, sender: MessageViewSender, sentAt: ATProtocolDate
        ) {
            self.id = id
            self.rev = rev
            self.text = text
            self.facets = facets
            self.embed = embed
            self.reactions = reactions
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
                reactions = try container.decodeIfPresent([ReactionView].self, forKey: .reactions)

            } catch {
                LogManager.logError("Decoding error for property 'reactions': \(error)")
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

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(facets, forKey: .facets)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embed, forKey: .embed)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reactions, forKey: .reactions)

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
            if let value = reactions {
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

            if reactions != other.reactions {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let textValue = try (text as? DAGCBOREncodable)?.toCBORValue() ?? text
            map = map.adding(key: "text", value: textValue)

            if let value = facets {
                // Encode optional property even if it's an empty array for CBOR

                let facetsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "facets", value: facetsValue)
            }

            if let value = embed {
                // Encode optional property even if it's an empty array for CBOR

                let embedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "embed", value: embedValue)
            }

            if let value = reactions {
                // Encode optional property even if it's an empty array for CBOR

                let reactionsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "reactions", value: reactionsValue)
            }

            let senderValue = try (sender as? DAGCBOREncodable)?.toCBORValue() ?? sender
            map = map.adding(key: "sender", value: senderValue)

            let sentAtValue = try (sentAt as? DAGCBOREncodable)?.toCBORValue() ?? sentAt
            map = map.adding(key: "sentAt", value: sentAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case text
            case facets
            case embed
            case reactions
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let senderValue = try (sender as? DAGCBOREncodable)?.toCBORValue() ?? sender
            map = map.adding(key: "sender", value: senderValue)

            let sentAtValue = try (sentAt as? DAGCBOREncodable)?.toCBORValue() ?? sentAt
            map = map.adding(key: "sentAt", value: sentAtValue)

            return map
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
        public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct ReactionView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#reactionView"
        public let value: String
        public let sender: ReactionViewSender
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(
            value: String, sender: ReactionViewSender, createdAt: ATProtocolDate
        ) {
            self.value = value
            self.sender = sender
            self.createdAt = createdAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                sender = try container.decode(ReactionViewSender.self, forKey: .sender)

            } catch {
                LogManager.logError("Decoding error for property 'sender': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(value, forKey: .value)

            try container.encode(sender, forKey: .sender)

            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(value)
            hasher.combine(sender)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if value != other.value {
                return false
            }

            if sender != other.sender {
                return false
            }

            if createdAt != other.createdAt {
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

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            let senderValue = try (sender as? DAGCBOREncodable)?.toCBORValue() ?? sender
            map = map.adding(key: "sender", value: senderValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case value
            case sender
            case createdAt
        }
    }

    public struct ReactionViewSender: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#reactionViewSender"
        public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct MessageAndReactionView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#messageAndReactionView"
        public let message: MessageView
        public let reaction: ReactionView

        // Standard initializer
        public init(
            message: MessageView, reaction: ReactionView
        ) {
            self.message = message
            self.reaction = reaction
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                message = try container.decode(MessageView.self, forKey: .message)

            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)

            } catch {
                LogManager.logError("Decoding error for property 'reaction': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(message, forKey: .message)

            try container.encode(reaction, forKey: .reaction)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(message)
            hasher.combine(reaction)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if message != other.message {
                return false
            }

            if reaction != other.reaction {
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

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            let reactionValue = try (reaction as? DAGCBOREncodable)?.toCBORValue() ?? reaction
            map = map.adding(key: "reaction", value: reactionValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case message
            case reaction
        }
    }

    public struct ConvoView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#convoView"
        public let id: String
        public let rev: String
        public let members: [ChatBskyActorDefs.ProfileViewBasic]
        public let lastMessage: ConvoViewLastMessageUnion?
        public let lastReaction: ConvoViewLastReactionUnion?
        public let muted: Bool
        public let status: String?
        public let unreadCount: Int

        // Standard initializer
        public init(
            id: String, rev: String, members: [ChatBskyActorDefs.ProfileViewBasic], lastMessage: ConvoViewLastMessageUnion?, lastReaction: ConvoViewLastReactionUnion?, muted: Bool, status: String?, unreadCount: Int
        ) {
            self.id = id
            self.rev = rev
            self.members = members
            self.lastMessage = lastMessage
            self.lastReaction = lastReaction
            self.muted = muted
            self.status = status
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
                lastReaction = try container.decodeIfPresent(ConvoViewLastReactionUnion.self, forKey: .lastReaction)

            } catch {
                LogManager.logError("Decoding error for property 'lastReaction': \(error)")
                throw error
            }
            do {
                muted = try container.decode(Bool.self, forKey: .muted)

            } catch {
                LogManager.logError("Decoding error for property 'muted': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
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

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastMessage, forKey: .lastMessage)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastReaction, forKey: .lastReaction)

            try container.encode(muted, forKey: .muted)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)

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
            if let value = lastReaction {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(muted)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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

            if lastReaction != other.lastReaction {
                return false
            }

            if muted != other.muted {
                return false
            }

            if status != other.status {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let membersValue = try (members as? DAGCBOREncodable)?.toCBORValue() ?? members
            map = map.adding(key: "members", value: membersValue)

            if let value = lastMessage {
                // Encode optional property even if it's an empty array for CBOR

                let lastMessageValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastMessage", value: lastMessageValue)
            }

            if let value = lastReaction {
                // Encode optional property even if it's an empty array for CBOR

                let lastReactionValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastReaction", value: lastReactionValue)
            }

            let mutedValue = try (muted as? DAGCBOREncodable)?.toCBORValue() ?? muted
            map = map.adding(key: "muted", value: mutedValue)

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR

                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            let unreadCountValue = try (unreadCount as? DAGCBOREncodable)?.toCBORValue() ?? unreadCount
            map = map.adding(key: "unreadCount", value: unreadCountValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case members
            case lastMessage
            case lastReaction
            case muted
            case status
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct LogAcceptConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logAcceptConvo"
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct LogMuteConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logMuteConvo"
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct LogUnmuteConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logUnmuteConvo"
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            return map
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
        }
    }

    public struct LogReadMessage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logReadMessage"
        public let rev: String
        public let convoId: String
        public let message: LogReadMessageMessageUnion

        // Standard initializer
        public init(
            rev: String, convoId: String, message: LogReadMessageMessageUnion
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
                message = try container.decode(LogReadMessageMessageUnion.self, forKey: .message)

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
        }
    }

    public struct LogAddReaction: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logAddReaction"
        public let rev: String
        public let convoId: String
        public let message: LogAddReactionMessageUnion
        public let reaction: ReactionView

        // Standard initializer
        public init(
            rev: String, convoId: String, message: LogAddReactionMessageUnion, reaction: ReactionView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.reaction = reaction
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
                message = try container.decode(LogAddReactionMessageUnion.self, forKey: .message)

            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)

            } catch {
                LogManager.logError("Decoding error for property 'reaction': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(rev, forKey: .rev)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(message, forKey: .message)

            try container.encode(reaction, forKey: .reaction)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(reaction)
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

            if reaction != other.reaction {
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

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            let reactionValue = try (reaction as? DAGCBOREncodable)?.toCBORValue() ?? reaction
            map = map.adding(key: "reaction", value: reactionValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case reaction
        }
    }

    public struct LogRemoveReaction: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logRemoveReaction"
        public let rev: String
        public let convoId: String
        public let message: LogRemoveReactionMessageUnion
        public let reaction: ReactionView

        // Standard initializer
        public init(
            rev: String, convoId: String, message: LogRemoveReactionMessageUnion, reaction: ReactionView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.reaction = reaction
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
                message = try container.decode(LogRemoveReactionMessageUnion.self, forKey: .message)

            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)

            } catch {
                LogManager.logError("Decoding error for property 'reaction': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(rev, forKey: .rev)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(message, forKey: .message)

            try container.encode(reaction, forKey: .reaction)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(reaction)
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

            if reaction != other.reaction {
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

            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)

            let convoIdValue = try (convoId as? DAGCBOREncodable)?.toCBORValue() ?? convoId
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try (message as? DAGCBOREncodable)?.toCBORValue() ?? message
            map = map.adding(key: "message", value: messageValue)

            let reactionValue = try (reaction as? DAGCBOREncodable)?.toCBORValue() ?? reaction
            map = map.adding(key: "reaction", value: reactionValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case reaction
        }
    }

    public enum MessageInputEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedRecord(AppBskyEmbedRecord)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyEmbedRecord) {
            self = .appBskyEmbedRecord(value)
        }

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
            case let .appBskyEmbedRecord(value):
                try container.encode("app.bsky.embed.record", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedRecord(value):
                hasher.combine("app.bsky.embed.record")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: MessageInputEmbedUnion, rhs: MessageInputEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedRecord(lhsValue),
                .appBskyEmbedRecord(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? MessageInputEmbedUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedRecord(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedRecord(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedRecord(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecord(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum MessageViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyEmbedRecord.View) {
            self = .appBskyEmbedRecordView(value)
        }

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
            case let .appBskyEmbedRecordView(value):
                try container.encode("app.bsky.embed.record#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedRecordView(value):
                hasher.combine("app.bsky.embed.record#view")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: MessageViewEmbedUnion, rhs: MessageViewEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedRecordView(lhsValue),
                .appBskyEmbedRecordView(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? MessageViewEmbedUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedRecordView(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#view")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedRecordView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedRecordView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordView(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ConvoViewLastMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ConvoViewLastMessageUnion, rhs: ConvoViewLastMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ConvoViewLastMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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

    public enum ConvoViewLastReactionUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageAndReactionView(ChatBskyConvoDefs.MessageAndReactionView)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ChatBskyConvoDefs.MessageAndReactionView) {
            self = .chatBskyConvoDefsMessageAndReactionView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#messageAndReactionView":
                let value = try ChatBskyConvoDefs.MessageAndReactionView(from: decoder)
                self = .chatBskyConvoDefsMessageAndReactionView(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsMessageAndReactionView(value):
                try container.encode("chat.bsky.convo.defs#messageAndReactionView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsMessageAndReactionView(value):
                hasher.combine("chat.bsky.convo.defs#messageAndReactionView")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ConvoViewLastReactionUnion, rhs: ConvoViewLastReactionUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageAndReactionView(lhsValue),
                .chatBskyConvoDefsMessageAndReactionView(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ConvoViewLastReactionUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageAndReactionView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageAndReactionView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageAndReactionView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageAndReactionView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageAndReactionView(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum LogCreateMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogCreateMessageMessageUnion, rhs: LogCreateMessageMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogCreateMessageMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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

    public enum LogDeleteMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogDeleteMessageMessageUnion, rhs: LogDeleteMessageMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogDeleteMessageMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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

    public enum LogReadMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogReadMessageMessageUnion, rhs: LogReadMessageMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogReadMessageMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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

    public enum LogAddReactionMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogAddReactionMessageUnion, rhs: LogAddReactionMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogAddReactionMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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

    public enum LogRemoveReactionMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .chatBskyConvoDefsMessageView(value):
                try container.encode("chat.bsky.convo.defs#messageView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsDeletedMessageView(value):
                try container.encode("chat.bsky.convo.defs#deletedMessageView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogRemoveReactionMessageUnion, rhs: LogRemoveReactionMessageUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsMessageView(lhsValue),
                .chatBskyConvoDefsMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsDeletedMessageView(lhsValue),
                .chatBskyConvoDefsDeletedMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogRemoveReactionMessageUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                return value.hasPendingData
            case let .chatBskyConvoDefsDeletedMessageView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .chatBskyConvoDefsMessageView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .chatBskyConvoDefsMessageView(value)
            case var .chatBskyConvoDefsDeletedMessageView(value):
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
