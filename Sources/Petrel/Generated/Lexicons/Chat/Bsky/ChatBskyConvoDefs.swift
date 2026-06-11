import Foundation

// lexicon: 1, id: chat.bsky.convo.defs

public enum ChatBskyConvoDefs {
    public static let typeIdentifier = "chat.bsky.convo.defs"

    public struct ConvoRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#convoRef"
        public let did: DID
        public let convoId: String

        public init(
            did: DID, convoId: String
        ) {
            self.did = did
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(convoId, forKey: .convoId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(convoId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case convoId
        }
    }

    public struct MessageRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#messageRef"
        public let did: DID
        public let convoId: String
        public let messageId: String

        public init(
            did: DID, convoId: String, messageId: String
        ) {
            self.did = did
            self.convoId = convoId
            self.messageId = messageId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                messageId = try container.decode(String.self, forKey: .messageId)
            } catch {
                LogManager.logError("Decoding error for required property 'messageId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageIdValue = try messageId.toCBORValue()
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

        public init(
            text: String, facets: [AppBskyRichtextFacet]?, embed: MessageInputEmbedUnion?
        ) {
            self.text = text
            self.facets = facets
            self.embed = embed
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                text = try container.decode(String.self, forKey: .text)
            } catch {
                LogManager.logError("Decoding error for required property 'text': \(error)")
                throw error
            }
            do {
                facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'facets' — degrading to nil: \(error)")
                facets = nil
            }
            do {
                embed = try container.decodeIfPresent(MessageInputEmbedUnion.self, forKey: .embed)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'embed' — degrading to nil: \(error)")
                embed = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(facets, forKey: .facets)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let textValue = try text.toCBORValue()
            map = map.adding(key: "text", value: textValue)
            if let value = facets {
                let facetsValue = try value.toCBORValue()
                map = map.adding(key: "facets", value: facetsValue)
            }
            if let value = embed {
                let embedValue = try value.toCBORValue()
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                text = try container.decode(String.self, forKey: .text)
            } catch {
                LogManager.logError("Decoding error for required property 'text': \(error)")
                throw error
            }
            do {
                facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'facets' — degrading to nil: \(error)")
                facets = nil
            }
            do {
                embed = try container.decodeIfPresent(MessageViewEmbedUnion.self, forKey: .embed)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'embed' — degrading to nil: \(error)")
                embed = nil
            }
            do {
                reactions = try container.decodeIfPresent([ReactionView].self, forKey: .reactions)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'reactions' — degrading to nil: \(error)")
                reactions = nil
            }
            do {
                sender = try container.decode(MessageViewSender.self, forKey: .sender)
            } catch {
                LogManager.logError("Decoding error for required property 'sender': \(error)")
                throw error
            }
            do {
                sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)
            } catch {
                LogManager.logError("Decoding error for required property 'sentAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(rev, forKey: .rev)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(facets, forKey: .facets)
            try container.encodeIfPresent(embed, forKey: .embed)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let textValue = try text.toCBORValue()
            map = map.adding(key: "text", value: textValue)
            if let value = facets {
                let facetsValue = try value.toCBORValue()
                map = map.adding(key: "facets", value: facetsValue)
            }
            if let value = embed {
                let embedValue = try value.toCBORValue()
                map = map.adding(key: "embed", value: embedValue)
            }
            if let value = reactions {
                let reactionsValue = try value.toCBORValue()
                map = map.adding(key: "reactions", value: reactionsValue)
            }
            let senderValue = try sender.toCBORValue()
            map = map.adding(key: "sender", value: senderValue)
            let sentAtValue = try sentAt.toCBORValue()
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

    public struct SystemMessageReferredUser: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageReferredUser"
        public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct SystemMessageView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageView"
        public let id: String
        public let rev: String
        public let sentAt: ATProtocolDate
        public let data: SystemMessageViewDataUnion

        public init(
            id: String, rev: String, sentAt: ATProtocolDate, data: SystemMessageViewDataUnion
        ) {
            self.id = id
            self.rev = rev
            self.sentAt = sentAt
            self.data = data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)
            } catch {
                LogManager.logError("Decoding error for required property 'sentAt': \(error)")
                throw error
            }
            do {
                data = try container.decode(SystemMessageViewDataUnion.self, forKey: .data)
            } catch {
                LogManager.logError("Decoding error for required property 'data': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(rev, forKey: .rev)
            try container.encode(sentAt, forKey: .sentAt)
            try container.encode(data, forKey: .data)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(rev)
            hasher.combine(sentAt)
            hasher.combine(data)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if rev != other.rev {
                return false
            }
            if sentAt != other.sentAt {
                return false
            }
            if data != other.data {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let sentAtValue = try sentAt.toCBORValue()
            map = map.adding(key: "sentAt", value: sentAtValue)
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case rev
            case sentAt
            case data
        }
    }

    public struct SystemMessageDataAddMember: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataAddMember"
        public let member: SystemMessageReferredUser
        public let role: ChatBskyActorDefs.MemberRole
        public let addedBy: SystemMessageReferredUser

        public init(
            member: SystemMessageReferredUser, role: ChatBskyActorDefs.MemberRole, addedBy: SystemMessageReferredUser
        ) {
            self.member = member
            self.role = role
            self.addedBy = addedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                member = try container.decode(SystemMessageReferredUser.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
            do {
                role = try container.decode(ChatBskyActorDefs.MemberRole.self, forKey: .role)
            } catch {
                LogManager.logError("Decoding error for required property 'role': \(error)")
                throw error
            }
            do {
                addedBy = try container.decode(SystemMessageReferredUser.self, forKey: .addedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'addedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(member, forKey: .member)
            try container.encode(role, forKey: .role)
            try container.encode(addedBy, forKey: .addedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(member)
            hasher.combine(role)
            hasher.combine(addedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if member != other.member {
                return false
            }
            if role != other.role {
                return false
            }
            if addedBy != other.addedBy {
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
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            let roleValue = try role.toCBORValue()
            map = map.adding(key: "role", value: roleValue)
            let addedByValue = try addedBy.toCBORValue()
            map = map.adding(key: "addedBy", value: addedByValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case member
            case role
            case addedBy
        }
    }

    public struct SystemMessageDataRemoveMember: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataRemoveMember"
        public let member: SystemMessageReferredUser
        public let removedBy: SystemMessageReferredUser

        public init(
            member: SystemMessageReferredUser, removedBy: SystemMessageReferredUser
        ) {
            self.member = member
            self.removedBy = removedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                member = try container.decode(SystemMessageReferredUser.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
            do {
                removedBy = try container.decode(SystemMessageReferredUser.self, forKey: .removedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'removedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(member, forKey: .member)
            try container.encode(removedBy, forKey: .removedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(member)
            hasher.combine(removedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if member != other.member {
                return false
            }
            if removedBy != other.removedBy {
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
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            let removedByValue = try removedBy.toCBORValue()
            map = map.adding(key: "removedBy", value: removedByValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case member
            case removedBy
        }
    }

    public struct SystemMessageDataMemberJoin: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataMemberJoin"
        public let member: SystemMessageReferredUser
        public let role: ChatBskyActorDefs.MemberRole
        public let approvedBy: SystemMessageReferredUser?

        public init(
            member: SystemMessageReferredUser, role: ChatBskyActorDefs.MemberRole, approvedBy: SystemMessageReferredUser?
        ) {
            self.member = member
            self.role = role
            self.approvedBy = approvedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                member = try container.decode(SystemMessageReferredUser.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
            do {
                role = try container.decode(ChatBskyActorDefs.MemberRole.self, forKey: .role)
            } catch {
                LogManager.logError("Decoding error for required property 'role': \(error)")
                throw error
            }
            do {
                approvedBy = try container.decodeIfPresent(SystemMessageReferredUser.self, forKey: .approvedBy)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'approvedBy' — degrading to nil: \(error)")
                approvedBy = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(member, forKey: .member)
            try container.encode(role, forKey: .role)
            try container.encodeIfPresent(approvedBy, forKey: .approvedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(member)
            hasher.combine(role)
            if let value = approvedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if member != other.member {
                return false
            }
            if role != other.role {
                return false
            }
            if approvedBy != other.approvedBy {
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
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            let roleValue = try role.toCBORValue()
            map = map.adding(key: "role", value: roleValue)
            if let value = approvedBy {
                let approvedByValue = try value.toCBORValue()
                map = map.adding(key: "approvedBy", value: approvedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case member
            case role
            case approvedBy
        }
    }

    public struct SystemMessageDataMemberLeave: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataMemberLeave"
        public let member: SystemMessageReferredUser

        public init(
            member: SystemMessageReferredUser
        ) {
            self.member = member
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                member = try container.decode(SystemMessageReferredUser.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(member, forKey: .member)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(member)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if member != other.member {
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
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case member
        }
    }

    public struct SystemMessageDataLockConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataLockConvo"
        public let lockedBy: SystemMessageReferredUser

        public init(
            lockedBy: SystemMessageReferredUser
        ) {
            self.lockedBy = lockedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lockedBy = try container.decode(SystemMessageReferredUser.self, forKey: .lockedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'lockedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(lockedBy, forKey: .lockedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(lockedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if lockedBy != other.lockedBy {
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
            let lockedByValue = try lockedBy.toCBORValue()
            map = map.adding(key: "lockedBy", value: lockedByValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lockedBy
        }
    }

    public struct SystemMessageDataUnlockConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataUnlockConvo"
        public let unlockedBy: SystemMessageReferredUser

        public init(
            unlockedBy: SystemMessageReferredUser
        ) {
            self.unlockedBy = unlockedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                unlockedBy = try container.decode(SystemMessageReferredUser.self, forKey: .unlockedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'unlockedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(unlockedBy, forKey: .unlockedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(unlockedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if unlockedBy != other.unlockedBy {
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
            let unlockedByValue = try unlockedBy.toCBORValue()
            map = map.adding(key: "unlockedBy", value: unlockedByValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case unlockedBy
        }
    }

    public struct SystemMessageDataLockConvoPermanently: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataLockConvoPermanently"
        public let lockedBy: SystemMessageReferredUser

        public init(
            lockedBy: SystemMessageReferredUser
        ) {
            self.lockedBy = lockedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lockedBy = try container.decode(SystemMessageReferredUser.self, forKey: .lockedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'lockedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(lockedBy, forKey: .lockedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(lockedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if lockedBy != other.lockedBy {
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
            let lockedByValue = try lockedBy.toCBORValue()
            map = map.adding(key: "lockedBy", value: lockedByValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lockedBy
        }
    }

    public struct SystemMessageDataEditGroup: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataEditGroup"
        public let oldName: String?
        public let newName: String?

        public init(
            oldName: String?, newName: String?
        ) {
            self.oldName = oldName
            self.newName = newName
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                oldName = try container.decodeIfPresent(String.self, forKey: .oldName)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'oldName' — degrading to nil: \(error)")
                oldName = nil
            }
            do {
                newName = try container.decodeIfPresent(String.self, forKey: .newName)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'newName' — degrading to nil: \(error)")
                newName = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(oldName, forKey: .oldName)
            try container.encodeIfPresent(newName, forKey: .newName)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = oldName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = newName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if oldName != other.oldName {
                return false
            }
            if newName != other.newName {
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
            if let value = oldName {
                let oldNameValue = try value.toCBORValue()
                map = map.adding(key: "oldName", value: oldNameValue)
            }
            if let value = newName {
                let newNameValue = try value.toCBORValue()
                map = map.adding(key: "newName", value: newNameValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case oldName
            case newName
        }
    }

    public struct SystemMessageDataCreateJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataCreateJoinLink"

        public init() {}

        public init(from decoder: Decoder) throws {
            _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct SystemMessageDataEditJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataEditJoinLink"

        public init() {}

        public init(from decoder: Decoder) throws {
            _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct SystemMessageDataEnableJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataEnableJoinLink"

        public init() {}

        public init(from decoder: Decoder) throws {
            _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct SystemMessageDataDisableJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#systemMessageDataDisableJoinLink"

        public init() {}

        public init(from decoder: Decoder) throws {
            _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct DeletedMessageView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#deletedMessageView"
        public let id: String
        public let rev: String
        public let sender: MessageViewSender
        public let sentAt: ATProtocolDate

        public init(
            id: String, rev: String, sender: MessageViewSender, sentAt: ATProtocolDate
        ) {
            self.id = id
            self.rev = rev
            self.sender = sender
            self.sentAt = sentAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                sender = try container.decode(MessageViewSender.self, forKey: .sender)
            } catch {
                LogManager.logError("Decoding error for required property 'sender': \(error)")
                throw error
            }
            do {
                sentAt = try container.decode(ATProtocolDate.self, forKey: .sentAt)
            } catch {
                LogManager.logError("Decoding error for required property 'sentAt': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let senderValue = try sender.toCBORValue()
            map = map.adding(key: "sender", value: senderValue)
            let sentAtValue = try sentAt.toCBORValue()
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

        public init(
            did: DID
        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
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

        public init(
            value: String, sender: ReactionViewSender, createdAt: ATProtocolDate
        ) {
            self.value = value
            self.sender = sender
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                value = try container.decode(String.self, forKey: .value)
            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")
                throw error
            }
            do {
                sender = try container.decode(ReactionViewSender.self, forKey: .sender)
            } catch {
                LogManager.logError("Decoding error for required property 'sender': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            let senderValue = try sender.toCBORValue()
            map = map.adding(key: "sender", value: senderValue)
            let createdAtValue = try createdAt.toCBORValue()
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

        public init(
            did: DID
        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
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

        public init(
            message: MessageView, reaction: ReactionView
        ) {
            self.message = message
            self.reaction = reaction
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                message = try container.decode(MessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)
            } catch {
                LogManager.logError("Decoding error for required property 'reaction': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let reactionValue = try reaction.toCBORValue()
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
        public let status: ConvoStatus?
        public let unreadCount: Int
        public let kind: ConvoViewKindUnion?

        public init(
            id: String, rev: String, members: [ChatBskyActorDefs.ProfileViewBasic], lastMessage: ConvoViewLastMessageUnion?, lastReaction: ConvoViewLastReactionUnion?, muted: Bool, status: ConvoStatus?, unreadCount: Int, kind: ConvoViewKindUnion?
        ) {
            self.id = id
            self.rev = rev
            self.members = members
            self.lastMessage = lastMessage
            self.lastReaction = lastReaction
            self.muted = muted
            self.status = status
            self.unreadCount = unreadCount
            self.kind = kind
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                members = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .members)
            } catch {
                LogManager.logError("Decoding error for required property 'members': \(error)")
                throw error
            }
            do {
                lastMessage = try container.decodeIfPresent(ConvoViewLastMessageUnion.self, forKey: .lastMessage)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'lastMessage' — degrading to nil: \(error)")
                lastMessage = nil
            }
            do {
                lastReaction = try container.decodeIfPresent(ConvoViewLastReactionUnion.self, forKey: .lastReaction)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'lastReaction' — degrading to nil: \(error)")
                lastReaction = nil
            }
            do {
                muted = try container.decode(Bool.self, forKey: .muted)
            } catch {
                LogManager.logError("Decoding error for required property 'muted': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(ConvoStatus.self, forKey: .status)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'status' — degrading to nil: \(error)")
                status = nil
            }
            do {
                unreadCount = try container.decode(Int.self, forKey: .unreadCount)
            } catch {
                LogManager.logError("Decoding error for required property 'unreadCount': \(error)")
                throw error
            }
            do {
                kind = try container.decodeIfPresent(ConvoViewKindUnion.self, forKey: .kind)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'kind' — degrading to nil: \(error)")
                kind = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(rev, forKey: .rev)
            try container.encode(members, forKey: .members)
            try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
            try container.encodeIfPresent(lastReaction, forKey: .lastReaction)
            try container.encode(muted, forKey: .muted)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encode(unreadCount, forKey: .unreadCount)
            try container.encodeIfPresent(kind, forKey: .kind)
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
            if let value = kind {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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
            if kind != other.kind {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let membersValue = try members.toCBORValue()
            map = map.adding(key: "members", value: membersValue)
            if let value = lastMessage {
                let lastMessageValue = try value.toCBORValue()
                map = map.adding(key: "lastMessage", value: lastMessageValue)
            }
            if let value = lastReaction {
                let lastReactionValue = try value.toCBORValue()
                map = map.adding(key: "lastReaction", value: lastReactionValue)
            }
            let mutedValue = try muted.toCBORValue()
            map = map.adding(key: "muted", value: mutedValue)
            if let value = status {
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            let unreadCountValue = try unreadCount.toCBORValue()
            map = map.adding(key: "unreadCount", value: unreadCountValue)
            if let value = kind {
                let kindValue = try value.toCBORValue()
                map = map.adding(key: "kind", value: kindValue)
            }
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
            case kind
        }
    }

    public struct DirectConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#directConvo"

        public init() {}

        public init(from decoder: Decoder) throws {
            _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct GroupConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#groupConvo"
        public let createdAt: ATProtocolDate
        public let joinLink: ChatBskyGroupDefs.JoinLinkView?
        public let joinRequestCount: Int?
        public let lockStatus: ConvoLockStatus
        public let lockStatusModerationOverride: Bool
        public let memberCount: Int
        public let memberLimit: Int
        public let name: String
        public let unreadJoinRequestCount: Int?

        public init(
            createdAt: ATProtocolDate, joinLink: ChatBskyGroupDefs.JoinLinkView?, joinRequestCount: Int?, lockStatus: ConvoLockStatus, lockStatusModerationOverride: Bool, memberCount: Int, memberLimit: Int, name: String, unreadJoinRequestCount: Int?
        ) {
            self.createdAt = createdAt
            self.joinLink = joinLink
            self.joinRequestCount = joinRequestCount
            self.lockStatus = lockStatus
            self.lockStatusModerationOverride = lockStatusModerationOverride
            self.memberCount = memberCount
            self.memberLimit = memberLimit
            self.name = name
            self.unreadJoinRequestCount = unreadJoinRequestCount
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                joinLink = try container.decodeIfPresent(ChatBskyGroupDefs.JoinLinkView.self, forKey: .joinLink)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'joinLink' — degrading to nil: \(error)")
                joinLink = nil
            }
            do {
                joinRequestCount = try container.decodeIfPresent(Int.self, forKey: .joinRequestCount)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'joinRequestCount' — degrading to nil: \(error)")
                joinRequestCount = nil
            }
            do {
                lockStatus = try container.decode(ConvoLockStatus.self, forKey: .lockStatus)
            } catch {
                LogManager.logError("Decoding error for required property 'lockStatus': \(error)")
                throw error
            }
            do {
                lockStatusModerationOverride = try container.decode(Bool.self, forKey: .lockStatusModerationOverride)
            } catch {
                LogManager.logError("Decoding error for required property 'lockStatusModerationOverride': \(error)")
                throw error
            }
            do {
                memberCount = try container.decode(Int.self, forKey: .memberCount)
            } catch {
                LogManager.logError("Decoding error for required property 'memberCount': \(error)")
                throw error
            }
            do {
                memberLimit = try container.decode(Int.self, forKey: .memberLimit)
            } catch {
                LogManager.logError("Decoding error for required property 'memberLimit': \(error)")
                throw error
            }
            do {
                name = try container.decode(String.self, forKey: .name)
            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")
                throw error
            }
            do {
                unreadJoinRequestCount = try container.decodeIfPresent(Int.self, forKey: .unreadJoinRequestCount)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'unreadJoinRequestCount' — degrading to nil: \(error)")
                unreadJoinRequestCount = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(joinLink, forKey: .joinLink)
            try container.encodeIfPresent(joinRequestCount, forKey: .joinRequestCount)
            try container.encode(lockStatus, forKey: .lockStatus)
            try container.encode(lockStatusModerationOverride, forKey: .lockStatusModerationOverride)
            try container.encode(memberCount, forKey: .memberCount)
            try container.encode(memberLimit, forKey: .memberLimit)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(unreadJoinRequestCount, forKey: .unreadJoinRequestCount)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(createdAt)
            if let value = joinLink {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinRequestCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(lockStatus)
            hasher.combine(lockStatusModerationOverride)
            hasher.combine(memberCount)
            hasher.combine(memberLimit)
            hasher.combine(name)
            if let value = unreadJoinRequestCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if createdAt != other.createdAt {
                return false
            }
            if joinLink != other.joinLink {
                return false
            }
            if joinRequestCount != other.joinRequestCount {
                return false
            }
            if lockStatus != other.lockStatus {
                return false
            }
            if lockStatusModerationOverride != other.lockStatusModerationOverride {
                return false
            }
            if memberCount != other.memberCount {
                return false
            }
            if memberLimit != other.memberLimit {
                return false
            }
            if name != other.name {
                return false
            }
            if unreadJoinRequestCount != other.unreadJoinRequestCount {
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
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = joinLink {
                let joinLinkValue = try value.toCBORValue()
                map = map.adding(key: "joinLink", value: joinLinkValue)
            }
            if let value = joinRequestCount {
                let joinRequestCountValue = try value.toCBORValue()
                map = map.adding(key: "joinRequestCount", value: joinRequestCountValue)
            }
            let lockStatusValue = try lockStatus.toCBORValue()
            map = map.adding(key: "lockStatus", value: lockStatusValue)
            let lockStatusModerationOverrideValue = try lockStatusModerationOverride.toCBORValue()
            map = map.adding(key: "lockStatusModerationOverride", value: lockStatusModerationOverrideValue)
            let memberCountValue = try memberCount.toCBORValue()
            map = map.adding(key: "memberCount", value: memberCountValue)
            let memberLimitValue = try memberLimit.toCBORValue()
            map = map.adding(key: "memberLimit", value: memberLimitValue)
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            if let value = unreadJoinRequestCount {
                let unreadJoinRequestCountValue = try value.toCBORValue()
                map = map.adding(key: "unreadJoinRequestCount", value: unreadJoinRequestCountValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case createdAt
            case joinLink
            case joinRequestCount
            case lockStatus
            case lockStatusModerationOverride
            case memberCount
            case memberLimit
            case name
            case unreadJoinRequestCount
        }
    }

    public struct LogBeginConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logBeginConvo"
        public let rev: String
        public let convoId: String

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
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

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
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

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
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

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
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

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
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
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?

        public init(
            rev: String, convoId: String, message: LogCreateMessageMessageUnion, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogCreateMessageMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decodeIfPresent([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'relatedProfiles' — degrading to nil: \(error)")
                relatedProfiles = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            if let value = relatedProfiles {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            if let value = relatedProfiles {
                let relatedProfilesValue = try value.toCBORValue()
                map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogDeleteMessage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logDeleteMessage"
        public let rev: String
        public let convoId: String
        public let message: LogDeleteMessageMessageUnion

        public init(
            rev: String, convoId: String, message: LogDeleteMessageMessageUnion
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogDeleteMessageMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

        public init(
            rev: String, convoId: String, message: LogReadMessageMessageUnion
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogReadMessageMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?

        public init(
            rev: String, convoId: String, message: LogAddReactionMessageUnion, reaction: ReactionView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.reaction = reaction
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogAddReactionMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)
            } catch {
                LogManager.logError("Decoding error for required property 'reaction': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decodeIfPresent([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'relatedProfiles' — degrading to nil: \(error)")
                relatedProfiles = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(reaction, forKey: .reaction)
            try container.encodeIfPresent(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(reaction)
            if let value = relatedProfiles {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let reactionValue = try reaction.toCBORValue()
            map = map.adding(key: "reaction", value: reactionValue)
            if let value = relatedProfiles {
                let relatedProfilesValue = try value.toCBORValue()
                map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case reaction
            case relatedProfiles
        }
    }

    public struct LogRemoveReaction: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logRemoveReaction"
        public let rev: String
        public let convoId: String
        public let message: LogRemoveReactionMessageUnion
        public let reaction: ReactionView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?

        public init(
            rev: String, convoId: String, message: LogRemoveReactionMessageUnion, reaction: ReactionView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]?
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.reaction = reaction
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogRemoveReactionMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                reaction = try container.decode(ReactionView.self, forKey: .reaction)
            } catch {
                LogManager.logError("Decoding error for required property 'reaction': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decodeIfPresent([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'relatedProfiles' — degrading to nil: \(error)")
                relatedProfiles = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(reaction, forKey: .reaction)
            try container.encodeIfPresent(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(reaction)
            if let value = relatedProfiles {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let reactionValue = try reaction.toCBORValue()
            map = map.adding(key: "reaction", value: reactionValue)
            if let value = relatedProfiles {
                let relatedProfilesValue = try value.toCBORValue()
                map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case reaction
            case relatedProfiles
        }
    }

    public struct LogReadConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logReadConvo"
        public let rev: String
        public let convoId: String
        public let message: LogReadConvoMessageUnion

        public init(
            rev: String, convoId: String, message: LogReadConvoMessageUnion
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(LogReadConvoMessageUnion.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogAddMember: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logAddMember"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogRemoveMember: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logRemoveMember"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogMemberJoin: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logMemberJoin"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogMemberLeave: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logMemberLeave"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogLockConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logLockConvo"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogUnlockConvo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logUnlockConvo"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogLockConvoPermanently: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logLockConvoPermanently"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView
        public let relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]

        public init(
            rev: String, convoId: String, message: SystemMessageView, relatedProfiles: [ChatBskyActorDefs.ProfileViewBasic]
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
            self.relatedProfiles = relatedProfiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                relatedProfiles = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .relatedProfiles)
            } catch {
                LogManager.logError("Decoding error for required property 'relatedProfiles': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(message, forKey: .message)
            try container.encode(relatedProfiles, forKey: .relatedProfiles)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(message)
            hasher.combine(relatedProfiles)
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
            if relatedProfiles != other.relatedProfiles {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let relatedProfilesValue = try relatedProfiles.toCBORValue()
            map = map.adding(key: "relatedProfiles", value: relatedProfilesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case message
            case relatedProfiles
        }
    }

    public struct LogEditGroup: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logEditGroup"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView

        public init(
            rev: String, convoId: String, message: SystemMessageView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogCreateJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logCreateJoinLink"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView

        public init(
            rev: String, convoId: String, message: SystemMessageView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogEditJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logEditJoinLink"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView

        public init(
            rev: String, convoId: String, message: SystemMessageView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogEnableJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logEnableJoinLink"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView

        public init(
            rev: String, convoId: String, message: SystemMessageView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogDisableJoinLink: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logDisableJoinLink"
        public let rev: String
        public let convoId: String
        public let message: SystemMessageView

        public init(
            rev: String, convoId: String, message: SystemMessageView
        ) {
            self.rev = rev
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(SystemMessageView.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let messageValue = try message.toCBORValue()
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

    public struct LogIncomingJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logIncomingJoinRequest"
        public let rev: String
        public let convoId: String
        public let member: ChatBskyActorDefs.ProfileViewBasic

        public init(
            rev: String, convoId: String, member: ChatBskyActorDefs.ProfileViewBasic
        ) {
            self.rev = rev
            self.convoId = convoId
            self.member = member
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                member = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(member, forKey: .member)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(member)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if rev != other.rev {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if member != other.member {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case member
        }
    }

    public struct LogApproveJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logApproveJoinRequest"
        public let rev: String
        public let convoId: String
        public let member: ChatBskyActorDefs.ProfileViewBasic

        public init(
            rev: String, convoId: String, member: ChatBskyActorDefs.ProfileViewBasic
        ) {
            self.rev = rev
            self.convoId = convoId
            self.member = member
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                member = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(member, forKey: .member)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(member)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if rev != other.rev {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if member != other.member {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case member
        }
    }

    public struct LogRejectJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logRejectJoinRequest"
        public let rev: String
        public let convoId: String
        public let member: ChatBskyActorDefs.ProfileViewBasic

        public init(
            rev: String, convoId: String, member: ChatBskyActorDefs.ProfileViewBasic
        ) {
            self.rev = rev
            self.convoId = convoId
            self.member = member
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                member = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(member, forKey: .member)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(member)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if rev != other.rev {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if member != other.member {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case member
        }
    }

    public struct LogOutgoingJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logOutgoingJoinRequest"
        public let rev: String
        public let convoId: String

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct LogWithdrawIncomingJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logWithdrawIncomingJoinRequest"
        public let rev: String
        public let convoId: String
        public let member: ChatBskyActorDefs.ProfileViewBasic

        public init(
            rev: String, convoId: String, member: ChatBskyActorDefs.ProfileViewBasic
        ) {
            self.rev = rev
            self.convoId = convoId
            self.member = member
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                member = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .member)
            } catch {
                LogManager.logError("Decoding error for required property 'member': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(rev, forKey: .rev)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(member, forKey: .member)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rev)
            hasher.combine(convoId)
            hasher.combine(member)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if rev != other.rev {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if member != other.member {
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
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let memberValue = try member.toCBORValue()
            map = map.adding(key: "member", value: memberValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
            case member
        }
    }

    public struct LogWithdrawOutgoingJoinRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logWithdrawOutgoingJoinRequest"
        public let rev: String
        public let convoId: String

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct LogReadJoinRequests: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.defs#logReadJoinRequests"
        public let rev: String
        public let convoId: String

        public init(
            rev: String, convoId: String
        ) {
            self.rev = rev
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rev
            case convoId
        }
    }

    public struct ConvoKind: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        /// Predefined constants
        ///
        public static let direct = ConvoKind(rawValue: "direct")
        ///
        public static let group = ConvoKind(rawValue: "group")

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ConvoKind else { return false }
            return rawValue == otherValue.rawValue
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        /// Provide allCases-like functionality
        public static var predefinedValues: [ConvoKind] {
            return [
                .direct,
                .group,
            ]
        }
    }

    public struct ConvoLockStatus: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        /// Predefined constants
        ///
        public static let unlocked = ConvoLockStatus(rawValue: "unlocked")
        ///
        public static let locked = ConvoLockStatus(rawValue: "locked")
        ///
        public static let lockeddashpermanently = ConvoLockStatus(rawValue: "locked-permanently")

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ConvoLockStatus else { return false }
            return rawValue == otherValue.rawValue
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        /// Provide allCases-like functionality
        public static var predefinedValues: [ConvoLockStatus] {
            return [
                .unlocked,
                .locked,
                .lockeddashpermanently,
            ]
        }
    }

    public struct ConvoStatus: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        /// Predefined constants
        ///
        public static let request = ConvoStatus(rawValue: "request")
        ///
        public static let accepted = ConvoStatus(rawValue: "accepted")

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ConvoStatus else { return false }
            return rawValue == otherValue.rawValue
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        /// Provide allCases-like functionality
        public static var predefinedValues: [ConvoStatus] {
            return [
                .request,
                .accepted,
            ]
        }
    }

    public enum MessageInputEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedRecord(AppBskyEmbedRecord)
        case chatBskyEmbedJoinLink(ChatBskyEmbedJoinLink)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyEmbedRecord) {
            self = .appBskyEmbedRecord(value)
        }

        public init(_ value: ChatBskyEmbedJoinLink) {
            self = .chatBskyEmbedJoinLink(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.record":
                let value = try AppBskyEmbedRecord(from: decoder)
                self = .appBskyEmbedRecord(value)
            case "chat.bsky.embed.joinLink":
                let value = try ChatBskyEmbedJoinLink(from: decoder)
                self = .chatBskyEmbedJoinLink(value)
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
            case let .chatBskyEmbedJoinLink(value):
                try container.encode("chat.bsky.embed.joinLink", forKey: .type)
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
            case let .chatBskyEmbedJoinLink(value):
                hasher.combine("chat.bsky.embed.joinLink")
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
            case let (
                .chatBskyEmbedJoinLink(lhsValue),
                .chatBskyEmbedJoinLink(rhsValue)
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedRecord(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record")

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
            case let .chatBskyEmbedJoinLink(value):
                map = map.adding(key: "$type", value: "chat.bsky.embed.joinLink")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum MessageViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
        case chatBskyEmbedJoinLinkView(ChatBskyEmbedJoinLink.View)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyEmbedRecord.View) {
            self = .appBskyEmbedRecordView(value)
        }

        public init(_ value: ChatBskyEmbedJoinLink.View) {
            self = .chatBskyEmbedJoinLinkView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.record#view":
                let value = try AppBskyEmbedRecord.View(from: decoder)
                self = .appBskyEmbedRecordView(value)
            case "chat.bsky.embed.joinLink#view":
                let value = try ChatBskyEmbedJoinLink.View(from: decoder)
                self = .chatBskyEmbedJoinLinkView(value)
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
            case let .chatBskyEmbedJoinLinkView(value):
                try container.encode("chat.bsky.embed.joinLink#view", forKey: .type)
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
            case let .chatBskyEmbedJoinLinkView(value):
                hasher.combine("chat.bsky.embed.joinLink#view")
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
            case let (
                .chatBskyEmbedJoinLinkView(lhsValue),
                .chatBskyEmbedJoinLinkView(rhsValue)
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedRecordView(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#view")

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
            case let .chatBskyEmbedJoinLinkView(value):
                map = map.adding(key: "$type", value: "chat.bsky.embed.joinLink#view")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public enum SystemMessageViewDataUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsSystemMessageDataAddMember(ChatBskyConvoDefs.SystemMessageDataAddMember)
        case chatBskyConvoDefsSystemMessageDataRemoveMember(ChatBskyConvoDefs.SystemMessageDataRemoveMember)
        case chatBskyConvoDefsSystemMessageDataMemberJoin(ChatBskyConvoDefs.SystemMessageDataMemberJoin)
        case chatBskyConvoDefsSystemMessageDataMemberLeave(ChatBskyConvoDefs.SystemMessageDataMemberLeave)
        case chatBskyConvoDefsSystemMessageDataLockConvo(ChatBskyConvoDefs.SystemMessageDataLockConvo)
        case chatBskyConvoDefsSystemMessageDataUnlockConvo(ChatBskyConvoDefs.SystemMessageDataUnlockConvo)
        case chatBskyConvoDefsSystemMessageDataLockConvoPermanently(ChatBskyConvoDefs.SystemMessageDataLockConvoPermanently)
        case chatBskyConvoDefsSystemMessageDataEditGroup(ChatBskyConvoDefs.SystemMessageDataEditGroup)
        case chatBskyConvoDefsSystemMessageDataCreateJoinLink(ChatBskyConvoDefs.SystemMessageDataCreateJoinLink)
        case chatBskyConvoDefsSystemMessageDataEditJoinLink(ChatBskyConvoDefs.SystemMessageDataEditJoinLink)
        case chatBskyConvoDefsSystemMessageDataEnableJoinLink(ChatBskyConvoDefs.SystemMessageDataEnableJoinLink)
        case chatBskyConvoDefsSystemMessageDataDisableJoinLink(ChatBskyConvoDefs.SystemMessageDataDisableJoinLink)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.SystemMessageDataAddMember) {
            self = .chatBskyConvoDefsSystemMessageDataAddMember(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataRemoveMember) {
            self = .chatBskyConvoDefsSystemMessageDataRemoveMember(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataMemberJoin) {
            self = .chatBskyConvoDefsSystemMessageDataMemberJoin(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataMemberLeave) {
            self = .chatBskyConvoDefsSystemMessageDataMemberLeave(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataLockConvo) {
            self = .chatBskyConvoDefsSystemMessageDataLockConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataUnlockConvo) {
            self = .chatBskyConvoDefsSystemMessageDataUnlockConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataLockConvoPermanently) {
            self = .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataEditGroup) {
            self = .chatBskyConvoDefsSystemMessageDataEditGroup(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataCreateJoinLink) {
            self = .chatBskyConvoDefsSystemMessageDataCreateJoinLink(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataEditJoinLink) {
            self = .chatBskyConvoDefsSystemMessageDataEditJoinLink(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataEnableJoinLink) {
            self = .chatBskyConvoDefsSystemMessageDataEnableJoinLink(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageDataDisableJoinLink) {
            self = .chatBskyConvoDefsSystemMessageDataDisableJoinLink(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#systemMessageDataAddMember":
                let value = try ChatBskyConvoDefs.SystemMessageDataAddMember(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataAddMember(value)
            case "chat.bsky.convo.defs#systemMessageDataRemoveMember":
                let value = try ChatBskyConvoDefs.SystemMessageDataRemoveMember(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataRemoveMember(value)
            case "chat.bsky.convo.defs#systemMessageDataMemberJoin":
                let value = try ChatBskyConvoDefs.SystemMessageDataMemberJoin(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataMemberJoin(value)
            case "chat.bsky.convo.defs#systemMessageDataMemberLeave":
                let value = try ChatBskyConvoDefs.SystemMessageDataMemberLeave(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataMemberLeave(value)
            case "chat.bsky.convo.defs#systemMessageDataLockConvo":
                let value = try ChatBskyConvoDefs.SystemMessageDataLockConvo(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataLockConvo(value)
            case "chat.bsky.convo.defs#systemMessageDataUnlockConvo":
                let value = try ChatBskyConvoDefs.SystemMessageDataUnlockConvo(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataUnlockConvo(value)
            case "chat.bsky.convo.defs#systemMessageDataLockConvoPermanently":
                let value = try ChatBskyConvoDefs.SystemMessageDataLockConvoPermanently(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(value)
            case "chat.bsky.convo.defs#systemMessageDataEditGroup":
                let value = try ChatBskyConvoDefs.SystemMessageDataEditGroup(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataEditGroup(value)
            case "chat.bsky.convo.defs#systemMessageDataCreateJoinLink":
                let value = try ChatBskyConvoDefs.SystemMessageDataCreateJoinLink(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataCreateJoinLink(value)
            case "chat.bsky.convo.defs#systemMessageDataEditJoinLink":
                let value = try ChatBskyConvoDefs.SystemMessageDataEditJoinLink(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataEditJoinLink(value)
            case "chat.bsky.convo.defs#systemMessageDataEnableJoinLink":
                let value = try ChatBskyConvoDefs.SystemMessageDataEnableJoinLink(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataEnableJoinLink(value)
            case "chat.bsky.convo.defs#systemMessageDataDisableJoinLink":
                let value = try ChatBskyConvoDefs.SystemMessageDataDisableJoinLink(from: decoder)
                self = .chatBskyConvoDefsSystemMessageDataDisableJoinLink(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsSystemMessageDataAddMember(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataAddMember", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataRemoveMember(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataRemoveMember", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataMemberJoin(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataMemberJoin", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataMemberLeave(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataMemberLeave", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataLockConvo(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataLockConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataUnlockConvo(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataUnlockConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataLockConvoPermanently", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataEditGroup(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataEditGroup", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataCreateJoinLink(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataCreateJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataEditJoinLink(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataEditJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataEnableJoinLink(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataEnableJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsSystemMessageDataDisableJoinLink(value):
                try container.encode("chat.bsky.convo.defs#systemMessageDataDisableJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsSystemMessageDataAddMember(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataAddMember")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataRemoveMember(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataRemoveMember")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataMemberJoin(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataMemberJoin")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataMemberLeave(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataMemberLeave")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataLockConvo(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataLockConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataUnlockConvo(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataUnlockConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataLockConvoPermanently")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataEditGroup(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataEditGroup")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataCreateJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataCreateJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataEditJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataEditJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataEnableJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataEnableJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsSystemMessageDataDisableJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageDataDisableJoinLink")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: SystemMessageViewDataUnion, rhs: SystemMessageViewDataUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsSystemMessageDataAddMember(lhsValue),
                .chatBskyConvoDefsSystemMessageDataAddMember(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataRemoveMember(lhsValue),
                .chatBskyConvoDefsSystemMessageDataRemoveMember(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataMemberJoin(lhsValue),
                .chatBskyConvoDefsSystemMessageDataMemberJoin(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataMemberLeave(lhsValue),
                .chatBskyConvoDefsSystemMessageDataMemberLeave(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataLockConvo(lhsValue),
                .chatBskyConvoDefsSystemMessageDataLockConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataUnlockConvo(lhsValue),
                .chatBskyConvoDefsSystemMessageDataUnlockConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(lhsValue),
                .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataEditGroup(lhsValue),
                .chatBskyConvoDefsSystemMessageDataEditGroup(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataCreateJoinLink(lhsValue),
                .chatBskyConvoDefsSystemMessageDataCreateJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataEditJoinLink(lhsValue),
                .chatBskyConvoDefsSystemMessageDataEditJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataEnableJoinLink(lhsValue),
                .chatBskyConvoDefsSystemMessageDataEnableJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsSystemMessageDataDisableJoinLink(lhsValue),
                .chatBskyConvoDefsSystemMessageDataDisableJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? SystemMessageViewDataUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsSystemMessageDataAddMember(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataAddMember")

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
            case let .chatBskyConvoDefsSystemMessageDataRemoveMember(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataRemoveMember")

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
            case let .chatBskyConvoDefsSystemMessageDataMemberJoin(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataMemberJoin")

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
            case let .chatBskyConvoDefsSystemMessageDataMemberLeave(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataMemberLeave")

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
            case let .chatBskyConvoDefsSystemMessageDataLockConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataLockConvo")

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
            case let .chatBskyConvoDefsSystemMessageDataUnlockConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataUnlockConvo")

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
            case let .chatBskyConvoDefsSystemMessageDataLockConvoPermanently(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataLockConvoPermanently")

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
            case let .chatBskyConvoDefsSystemMessageDataEditGroup(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataEditGroup")

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
            case let .chatBskyConvoDefsSystemMessageDataCreateJoinLink(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataCreateJoinLink")

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
            case let .chatBskyConvoDefsSystemMessageDataEditJoinLink(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataEditJoinLink")

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
            case let .chatBskyConvoDefsSystemMessageDataEnableJoinLink(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataEnableJoinLink")

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
            case let .chatBskyConvoDefsSystemMessageDataDisableJoinLink(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageDataDisableJoinLink")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ConvoViewLastMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
        case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
        case chatBskyConvoDefsSystemMessageView(ChatBskyConvoDefs.SystemMessageView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.MessageView) {
            self = .chatBskyConvoDefsMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.DeletedMessageView) {
            self = .chatBskyConvoDefsDeletedMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageView) {
            self = .chatBskyConvoDefsSystemMessageView(value)
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
            case "chat.bsky.convo.defs#systemMessageView":
                let value = try ChatBskyConvoDefs.SystemMessageView(from: decoder)
                self = .chatBskyConvoDefsSystemMessageView(value)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                try container.encode("chat.bsky.convo.defs#systemMessageView", forKey: .type)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageView")
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
            case let (
                .chatBskyConvoDefsSystemMessageView(lhsValue),
                .chatBskyConvoDefsSystemMessageView(rhsValue)
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .chatBskyConvoDefsSystemMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ConvoViewLastReactionUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageAndReactionView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageAndReactionView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public enum ConvoViewKindUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsDirectConvo(ChatBskyConvoDefs.DirectConvo)
        case chatBskyConvoDefsGroupConvo(ChatBskyConvoDefs.GroupConvo)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.DirectConvo) {
            self = .chatBskyConvoDefsDirectConvo(value)
        }

        public init(_ value: ChatBskyConvoDefs.GroupConvo) {
            self = .chatBskyConvoDefsGroupConvo(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#directConvo":
                let value = try ChatBskyConvoDefs.DirectConvo(from: decoder)
                self = .chatBskyConvoDefsDirectConvo(value)
            case "chat.bsky.convo.defs#groupConvo":
                let value = try ChatBskyConvoDefs.GroupConvo(from: decoder)
                self = .chatBskyConvoDefsGroupConvo(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsDirectConvo(value):
                try container.encode("chat.bsky.convo.defs#directConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsGroupConvo(value):
                try container.encode("chat.bsky.convo.defs#groupConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsDirectConvo(value):
                hasher.combine("chat.bsky.convo.defs#directConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsGroupConvo(value):
                hasher.combine("chat.bsky.convo.defs#groupConvo")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ConvoViewKindUnion, rhs: ConvoViewKindUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsDirectConvo(lhsValue),
                .chatBskyConvoDefsDirectConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsGroupConvo(lhsValue),
                .chatBskyConvoDefsGroupConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ConvoViewKindUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsDirectConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#directConvo")

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
            case let .chatBskyConvoDefsGroupConvo(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#groupConvo")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogCreateMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogDeleteMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogReadMessageMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
        case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
        case chatBskyConvoDefsSystemMessageView(ChatBskyConvoDefs.SystemMessageView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.MessageView) {
            self = .chatBskyConvoDefsMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.DeletedMessageView) {
            self = .chatBskyConvoDefsDeletedMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageView) {
            self = .chatBskyConvoDefsSystemMessageView(value)
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
            case "chat.bsky.convo.defs#systemMessageView":
                let value = try ChatBskyConvoDefs.SystemMessageView(from: decoder)
                self = .chatBskyConvoDefsSystemMessageView(value)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                try container.encode("chat.bsky.convo.defs#systemMessageView", forKey: .type)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageView")
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
            case let (
                .chatBskyConvoDefsSystemMessageView(lhsValue),
                .chatBskyConvoDefsSystemMessageView(rhsValue)
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .chatBskyConvoDefsSystemMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogAddReactionMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogRemoveReactionMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum LogReadConvoMessageUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsMessageView(ChatBskyConvoDefs.MessageView)
        case chatBskyConvoDefsDeletedMessageView(ChatBskyConvoDefs.DeletedMessageView)
        case chatBskyConvoDefsSystemMessageView(ChatBskyConvoDefs.SystemMessageView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.MessageView) {
            self = .chatBskyConvoDefsMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.DeletedMessageView) {
            self = .chatBskyConvoDefsDeletedMessageView(value)
        }

        public init(_ value: ChatBskyConvoDefs.SystemMessageView) {
            self = .chatBskyConvoDefsSystemMessageView(value)
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
            case "chat.bsky.convo.defs#systemMessageView":
                let value = try ChatBskyConvoDefs.SystemMessageView(from: decoder)
                self = .chatBskyConvoDefsSystemMessageView(value)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                try container.encode("chat.bsky.convo.defs#systemMessageView", forKey: .type)
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
            case let .chatBskyConvoDefsSystemMessageView(value):
                hasher.combine("chat.bsky.convo.defs#systemMessageView")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: LogReadConvoMessageUnion, rhs: LogReadConvoMessageUnion) -> Bool {
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
            case let (
                .chatBskyConvoDefsSystemMessageView(lhsValue),
                .chatBskyConvoDefsSystemMessageView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? LogReadConvoMessageUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#messageView")

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
            case let .chatBskyConvoDefsDeletedMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#deletedMessageView")

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
            case let .chatBskyConvoDefsSystemMessageView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#systemMessageView")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}
