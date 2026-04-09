import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.subscribeEvents


public struct BlueCatbirdMlsChatSubscribeEvents { 

    public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents"
        
public struct MessageEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#messageEvent"
            public let cursor: String
            public let message: BlueCatbirdMlsChatDefs.MessageView

        public init(
            cursor: String, message: BlueCatbirdMlsChatDefs.MessageView
        ) {
            self.cursor = cursor
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.cursor = try container.decode(String.self, forKey: .cursor)
            } catch {
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                throw error
            }
            do {
                self.message = try container.decode(BlueCatbirdMlsChatDefs.MessageView.self, forKey: .message)
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
            if cursor != other.cursor {
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
        
public struct MemberJoined: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#memberJoined"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let deviceId: String?
            public let epoch: Int
            public let method: String?

        public init(
            cursor: String, convoId: String, did: DID, deviceId: String?, epoch: Int, method: String?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.deviceId = deviceId
            self.epoch = epoch
            self.method = method
        }

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
                self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceId': \(error)")
                throw error
            }
            do {
                self.epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
            do {
                self.method = try container.decodeIfPresent(String.self, forKey: .method)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'method': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(did, forKey: .did)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encode(epoch, forKey: .epoch)
            try container.encodeIfPresent(method, forKey: .method)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            if let value = deviceId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(epoch)
            if let value = method {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if did != other.did {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if method != other.method {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            if let value = method {
                let methodValue = try value.toCBORValue()
                map = map.adding(key: "method", value: methodValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case deviceId
            case epoch
            case method
        }
    }
        
public struct MemberLeft: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#memberLeft"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let action: String
            public let actor: DID?
            public let reason: String?
            public let epoch: Int

        public init(
            cursor: String, convoId: String, did: DID, action: String, actor: DID?, reason: String?, epoch: Int
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.action = action
            self.actor = actor
            self.reason = reason
            self.epoch = epoch
        }

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
                self.action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
            do {
                self.actor = try container.decodeIfPresent(DID.self, forKey: .actor)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'actor': \(error)")
                throw error
            }
            do {
                self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")
                throw error
            }
            do {
                self.epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(did, forKey: .did)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(actor, forKey: .actor)
            try container.encodeIfPresent(reason, forKey: .reason)
            try container.encode(epoch, forKey: .epoch)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            hasher.combine(action)
            if let value = actor {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(epoch)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if did != other.did {
                return false
            }
            if action != other.action {
                return false
            }
            if actor != other.actor {
                return false
            }
            if reason != other.reason {
                return false
            }
            if epoch != other.epoch {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = actor {
                let actorValue = try value.toCBORValue()
                map = map.adding(key: "actor", value: actorValue)
            }
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case action
            case actor
            case reason
            case epoch
        }
    }
        
public struct EpochAdvanced: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#epochAdvanced"
            public let cursor: String
            public let convoId: String
            public let epoch: Int
            public let reason: String?

        public init(
            cursor: String, convoId: String, epoch: Int, reason: String?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.epoch = epoch
            self.reason = reason
        }

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
                self.epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
            do {
                self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(epoch, forKey: .epoch)
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(epoch)
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if reason != other.reason {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case epoch
            case reason
        }
    }
        
public struct ConversationUpdated: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#conversationUpdated"
            public let cursor: String
            public let convoId: String
            public let updatedFields: [String]?
            public let updatedBy: DID?

        public init(
            cursor: String, convoId: String, updatedFields: [String]?, updatedBy: DID?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.updatedFields = updatedFields
            self.updatedBy = updatedBy
        }

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
                self.updatedFields = try container.decodeIfPresent([String].self, forKey: .updatedFields)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedFields': \(error)")
                throw error
            }
            do {
                self.updatedBy = try container.decodeIfPresent(DID.self, forKey: .updatedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(updatedFields, forKey: .updatedFields)
            try container.encodeIfPresent(updatedBy, forKey: .updatedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            if let value = updatedFields {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = updatedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if updatedFields != other.updatedFields {
                return false
            }
            if updatedBy != other.updatedBy {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = updatedFields {
                let updatedFieldsValue = try value.toCBORValue()
                map = map.adding(key: "updatedFields", value: updatedFieldsValue)
            }
            if let value = updatedBy {
                let updatedByValue = try value.toCBORValue()
                map = map.adding(key: "updatedBy", value: updatedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case updatedFields
            case updatedBy
        }
    }
        
public struct ReactionEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#reactionEvent"
            public let cursor: String
            public let convoId: String
            public let messageId: String
            public let did: DID
            public let reaction: String
            public let action: String

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
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if messageId != other.messageId {
                return false
            }
            if did != other.did {
                return false
            }
            if reaction != other.reaction {
                return false
            }
            if action != other.action {
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
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#typingEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let isTyping: Bool

        public init(
            cursor: String, convoId: String, did: DID, isTyping: Bool
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.isTyping = isTyping
        }

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
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if did != other.did {
                return false
            }
            if isTyping != other.isTyping {
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
        
public struct NewDeviceEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#newDeviceEvent"
            public let cursor: String
            public let convoId: String
            public let userDid: DID
            public let deviceId: String
            public let deviceName: String?
            public let deviceCredentialDid: String
            public let pendingAdditionId: String

        public init(
            cursor: String, convoId: String, userDid: DID, deviceId: String, deviceName: String?, deviceCredentialDid: String, pendingAdditionId: String
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.userDid = userDid
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceCredentialDid = deviceCredentialDid
            self.pendingAdditionId = pendingAdditionId
        }

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
                self.userDid = try container.decode(DID.self, forKey: .userDid)
            } catch {
                LogManager.logError("Decoding error for required property 'userDid': \(error)")
                throw error
            }
            do {
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                self.deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceName': \(error)")
                throw error
            }
            do {
                self.deviceCredentialDid = try container.decode(String.self, forKey: .deviceCredentialDid)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceCredentialDid': \(error)")
                throw error
            }
            do {
                self.pendingAdditionId = try container.decode(String.self, forKey: .pendingAdditionId)
            } catch {
                LogManager.logError("Decoding error for required property 'pendingAdditionId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(userDid, forKey: .userDid)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(deviceCredentialDid, forKey: .deviceCredentialDid)
            try container.encode(pendingAdditionId, forKey: .pendingAdditionId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(userDid)
            hasher.combine(deviceId)
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(deviceCredentialDid)
            hasher.combine(pendingAdditionId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if userDid != other.userDid {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if deviceName != other.deviceName {
                return false
            }
            if deviceCredentialDid != other.deviceCredentialDid {
                return false
            }
            if pendingAdditionId != other.pendingAdditionId {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            if let value = deviceName {
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }
            let deviceCredentialDidValue = try deviceCredentialDid.toCBORValue()
            map = map.adding(key: "deviceCredentialDid", value: deviceCredentialDidValue)
            let pendingAdditionIdValue = try pendingAdditionId.toCBORValue()
            map = map.adding(key: "pendingAdditionId", value: pendingAdditionIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case userDid
            case deviceId
            case deviceName
            case deviceCredentialDid
            case pendingAdditionId
        }
    }
        
public struct TreeChanged: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#treeChanged"
            public let cursor: String
            public let convoId: String
            public let confirmationTag: Bytes
            public let epoch: Int

        public init(
            cursor: String, convoId: String, confirmationTag: Bytes, epoch: Int
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.confirmationTag = confirmationTag
            self.epoch = epoch
        }

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
                self.confirmationTag = try container.decode(Bytes.self, forKey: .confirmationTag)
            } catch {
                LogManager.logError("Decoding error for required property 'confirmationTag': \(error)")
                throw error
            }
            do {
                self.epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(confirmationTag, forKey: .confirmationTag)
            try container.encode(epoch, forKey: .epoch)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(confirmationTag)
            hasher.combine(epoch)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if confirmationTag != other.confirmationTag {
                return false
            }
            if epoch != other.epoch {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let confirmationTagValue = try confirmationTag.toCBORValue()
            map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case confirmationTag
            case epoch
        }
    }
        
public struct InfoEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#infoEvent"
            public let cursor: String
            public let info: String
            public let infoType: String?
            public let convoId: String?
            public let requestedBy: DID?

        public init(
            cursor: String, info: String, infoType: String?, convoId: String?, requestedBy: DID?
        ) {
            self.cursor = cursor
            self.info = info
            self.infoType = infoType
            self.convoId = convoId
            self.requestedBy = requestedBy
        }

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
            do {
                self.infoType = try container.decodeIfPresent(String.self, forKey: .infoType)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'infoType': \(error)")
                throw error
            }
            do {
                self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'convoId': \(error)")
                throw error
            }
            do {
                self.requestedBy = try container.decodeIfPresent(DID.self, forKey: .requestedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requestedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(info, forKey: .info)
            try container.encodeIfPresent(infoType, forKey: .infoType)
            try container.encodeIfPresent(convoId, forKey: .convoId)
            try container.encodeIfPresent(requestedBy, forKey: .requestedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(info)
            if let value = infoType {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = convoId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = requestedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if info != other.info {
                return false
            }
            if infoType != other.infoType {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if requestedBy != other.requestedBy {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let infoValue = try info.toCBORValue()
            map = map.adding(key: "info", value: infoValue)
            if let value = infoType {
                let infoTypeValue = try value.toCBORValue()
                map = map.adding(key: "infoType", value: infoTypeValue)
            }
            if let value = convoId {
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            if let value = requestedBy {
                let requestedByValue = try value.toCBORValue()
                map = map.adding(key: "requestedBy", value: requestedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case info
            case infoType
            case convoId
            case requestedBy
        }
    }
        
public struct GroupResetEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#groupResetEvent"
            public let cursor: String
            public let convoId: String
            public let newGroupId: String
            public let resetGeneration: Int
            public let resetBy: DID?
            public let reason: String?

        public init(
            cursor: String, convoId: String, newGroupId: String, resetGeneration: Int, resetBy: DID?, reason: String?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.newGroupId = newGroupId
            self.resetGeneration = resetGeneration
            self.resetBy = resetBy
            self.reason = reason
        }

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
                self.newGroupId = try container.decode(String.self, forKey: .newGroupId)
            } catch {
                LogManager.logError("Decoding error for required property 'newGroupId': \(error)")
                throw error
            }
            do {
                self.resetGeneration = try container.decode(Int.self, forKey: .resetGeneration)
            } catch {
                LogManager.logError("Decoding error for required property 'resetGeneration': \(error)")
                throw error
            }
            do {
                self.resetBy = try container.decodeIfPresent(DID.self, forKey: .resetBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'resetBy': \(error)")
                throw error
            }
            do {
                self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(newGroupId, forKey: .newGroupId)
            try container.encode(resetGeneration, forKey: .resetGeneration)
            try container.encodeIfPresent(resetBy, forKey: .resetBy)
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(newGroupId)
            hasher.combine(resetGeneration)
            if let value = resetBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if newGroupId != other.newGroupId {
                return false
            }
            if resetGeneration != other.resetGeneration {
                return false
            }
            if resetBy != other.resetBy {
                return false
            }
            if reason != other.reason {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let newGroupIdValue = try newGroupId.toCBORValue()
            map = map.adding(key: "newGroupId", value: newGroupIdValue)
            let resetGenerationValue = try resetGeneration.toCBORValue()
            map = map.adding(key: "resetGeneration", value: resetGenerationValue)
            if let value = resetBy {
                let resetByValue = try value.toCBORValue()
                map = map.adding(key: "resetBy", value: resetByValue)
            }
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case newGroupId
            case resetGeneration
            case resetBy
            case reason
        }
    }
        
public struct MembershipChangeEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let action: String

        public init(
            cursor: String, convoId: String, did: DID, action: String
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.action = action
        }

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
            try container.encode(did, forKey: .did)
            try container.encode(action, forKey: .action)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            hasher.combine(action)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if did != other.did {
                return false
            }
            if action != other.action {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case action
        }
    }
        
public struct ReadEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#readEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID?
            public let messageId: String?

        public init(
            cursor: String, convoId: String, did: DID?, messageId: String?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.messageId = messageId
        }

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
                self.did = try container.decodeIfPresent(DID.self, forKey: .did)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'did': \(error)")
                throw error
            }
            do {
                self.messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'messageId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(did, forKey: .did)
            try container.encodeIfPresent(messageId, forKey: .messageId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            if let value = did {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = messageId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if did != other.did {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = did {
                let didValue = try value.toCBORValue()
                map = map.adding(key: "did", value: didValue)
            }
            if let value = messageId {
                let messageIdValue = try value.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case messageId
        }
    }
        
public struct GroupInfoRefreshRequestedEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent"
            public let cursor: String
            public let convoId: String
            public let requestedBy: DID?

        public init(
            cursor: String, convoId: String, requestedBy: DID?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.requestedBy = requestedBy
        }

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
                self.requestedBy = try container.decodeIfPresent(DID.self, forKey: .requestedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requestedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(requestedBy, forKey: .requestedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            if let value = requestedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if requestedBy != other.requestedBy {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = requestedBy {
                let requestedByValue = try value.toCBORValue()
                map = map.adding(key: "requestedBy", value: requestedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case requestedBy
        }
    }
        
public struct ReadditionRequestedEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent"
            public let cursor: String
            public let convoId: String
            public let requestedBy: DID?

        public init(
            cursor: String, convoId: String, requestedBy: DID?
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.requestedBy = requestedBy
        }

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
                self.requestedBy = try container.decodeIfPresent(DID.self, forKey: .requestedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requestedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(requestedBy, forKey: .requestedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            if let value = requestedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cursor != other.cursor {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if requestedBy != other.requestedBy {
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
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = requestedBy {
                let requestedByValue = try value.toCBORValue()
                map = map.adding(key: "requestedBy", value: requestedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case requestedBy
        }
    }    
public struct Parameters: Parametrizable {
        public let ticket: String?
        public let cursor: String?
        
        public init(
            ticket: String? = nil, 
            cursor: String? = nil
            ) {
            self.ticket = ticket
            self.cursor = cursor
            
        }
    }
public enum Message: Codable, Sendable {

    case messageEvent(MessageEvent)

    case memberJoined(MemberJoined)

    case memberLeft(MemberLeft)

    case epochAdvanced(EpochAdvanced)

    case conversationUpdated(ConversationUpdated)

    case reactionEvent(ReactionEvent)

    case typingEvent(TypingEvent)

    case newDeviceEvent(NewDeviceEvent)

    case infoEvent(InfoEvent)

    case treeChanged(TreeChanged)

    case groupResetEvent(GroupResetEvent)

    case membershipChangeEvent(MembershipChangeEvent)

    case readEvent(ReadEvent)

    case groupInfoRefreshRequestedEvent(GroupInfoRefreshRequestedEvent)

    case readditionRequestedEvent(ReadditionRequestedEvent)


    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {

        case "blue.catbird.mlsChat.subscribeEvents#messageEvent":
            let value = try MessageEvent(from: decoder)
            self = .messageEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#memberJoined":
            let value = try MemberJoined(from: decoder)
            self = .memberJoined(value)

        case "blue.catbird.mlsChat.subscribeEvents#memberLeft":
            let value = try MemberLeft(from: decoder)
            self = .memberLeft(value)

        case "blue.catbird.mlsChat.subscribeEvents#epochAdvanced":
            let value = try EpochAdvanced(from: decoder)
            self = .epochAdvanced(value)

        case "blue.catbird.mlsChat.subscribeEvents#conversationUpdated":
            let value = try ConversationUpdated(from: decoder)
            self = .conversationUpdated(value)

        case "blue.catbird.mlsChat.subscribeEvents#reactionEvent":
            let value = try ReactionEvent(from: decoder)
            self = .reactionEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#typingEvent":
            let value = try TypingEvent(from: decoder)
            self = .typingEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#newDeviceEvent":
            let value = try NewDeviceEvent(from: decoder)
            self = .newDeviceEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#infoEvent":
            let value = try InfoEvent(from: decoder)
            self = .infoEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#treeChanged":
            let value = try TreeChanged(from: decoder)
            self = .treeChanged(value)

        case "blue.catbird.mlsChat.subscribeEvents#groupResetEvent":
            let value = try GroupResetEvent(from: decoder)
            self = .groupResetEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent":
            let value = try MembershipChangeEvent(from: decoder)
            self = .membershipChangeEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#readEvent":
            let value = try ReadEvent(from: decoder)
            self = .readEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent":
            let value = try GroupInfoRefreshRequestedEvent(from: decoder)
            self = .groupInfoRefreshRequestedEvent(value)

        case "blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent":
            let value = try ReadditionRequestedEvent(from: decoder)
            self = .readditionRequestedEvent(value)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {

        case .messageEvent(let value):
            try value.encode(to: encoder)

        case .memberJoined(let value):
            try value.encode(to: encoder)

        case .memberLeft(let value):
            try value.encode(to: encoder)

        case .epochAdvanced(let value):
            try value.encode(to: encoder)

        case .conversationUpdated(let value):
            try value.encode(to: encoder)

        case .reactionEvent(let value):
            try value.encode(to: encoder)

        case .typingEvent(let value):
            try value.encode(to: encoder)

        case .newDeviceEvent(let value):
            try value.encode(to: encoder)

        case .infoEvent(let value):
            try value.encode(to: encoder)

        case .treeChanged(let value):
            try value.encode(to: encoder)

        case .groupResetEvent(let value):
            try value.encode(to: encoder)

        case .membershipChangeEvent(let value):
            try value.encode(to: encoder)

        case .readEvent(let value):
            try value.encode(to: encoder)

        case .groupInfoRefreshRequestedEvent(let value):
            try value.encode(to: encoder)

        case .readditionRequestedEvent(let value):
            try value.encode(to: encoder)

        }
    }
}



}


                           

/// Subscribe to live conversation events via WebSocket (consolidates subscribeConvoEvents with streamlined event types) Subscribe to live events (messages, membership changes, epoch advances, conversation updates) via firehose-style DAG-CBOR framing. Requires a valid ticket from getSubscriptionTicket.

extension ATProtoClient.Blue.Catbird.MlsChat {
    
    public func subscribeEvents(
        ticket: String? = nil, cursor: String? = nil
    ) async throws -> AsyncThrowingStream<BlueCatbirdMlsChatSubscribeEvents.Message, Error> {
        let params = BlueCatbirdMlsChatSubscribeEvents.Parameters(ticket: ticket, cursor: cursor)
        return try await self.networkService.subscribe(
            endpoint: "blue.catbird.mlsChat.subscribeEvents",
            parameters: params
        )
    }

    /// Alternative signature accepting input struct
    public func subscribeEvents(input: BlueCatbirdMlsChatSubscribeEvents.Parameters) async throws -> AsyncThrowingStream<BlueCatbirdMlsChatSubscribeEvents.Message, Error> {
        return try await self.networkService.subscribe(
            endpoint: "blue.catbird.mlsChat.subscribeEvents",
            parameters: input
        )
    }
    
}
