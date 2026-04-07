import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.subscribeConvoEvents


public struct BlueCatbirdMlsChatSubscribeConvoEvents { 

    public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents"
        
public struct EventWrapper: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#eventWrapper"
            public let event: EventWrapperEventUnion

        public init(
            event: EventWrapperEventUnion
        ) {
            self.event = event
        }

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
            if event != other.event {
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
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#messageEvent"
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
        
public struct ReactionEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent"
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
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#typingEvent"
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
        
public struct InfoEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#infoEvent"
            public let cursor: String
            public let info: String

        public init(
            cursor: String, info: String
        ) {
            self.cursor = cursor
            self.info = info
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
            if cursor != other.cursor {
                return false
            }
            if info != other.info {
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
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case info
        }
    }
        
public struct NewDeviceEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent"
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
        
public struct GroupInfoRefreshRequestedEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent"
            public let cursor: String
            public let convoId: String
            public let requestedBy: DID
            public let requestedAt: ATProtocolDate

        public init(
            cursor: String, convoId: String, requestedBy: DID, requestedAt: ATProtocolDate
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.requestedBy = requestedBy
            self.requestedAt = requestedAt
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
                self.requestedBy = try container.decode(DID.self, forKey: .requestedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedBy': \(error)")
                throw error
            }
            do {
                self.requestedAt = try container.decode(ATProtocolDate.self, forKey: .requestedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(requestedBy, forKey: .requestedBy)
            try container.encode(requestedAt, forKey: .requestedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(requestedBy)
            hasher.combine(requestedAt)
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
            if requestedAt != other.requestedAt {
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
            let requestedByValue = try requestedBy.toCBORValue()
            map = map.adding(key: "requestedBy", value: requestedByValue)
            let requestedAtValue = try requestedAt.toCBORValue()
            map = map.adding(key: "requestedAt", value: requestedAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case requestedBy
            case requestedAt
        }
    }
        
public struct ReadditionRequestedEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent"
            public let cursor: String
            public let convoId: String
            public let userDid: DID
            public let requestedAt: ATProtocolDate

        public init(
            cursor: String, convoId: String, userDid: DID, requestedAt: ATProtocolDate
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.userDid = userDid
            self.requestedAt = requestedAt
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
                self.requestedAt = try container.decode(ATProtocolDate.self, forKey: .requestedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(userDid, forKey: .userDid)
            try container.encode(requestedAt, forKey: .requestedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(userDid)
            hasher.combine(requestedAt)
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
            if requestedAt != other.requestedAt {
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
            let requestedAtValue = try requestedAt.toCBORValue()
            map = map.adding(key: "requestedAt", value: requestedAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case userDid
            case requestedAt
        }
    }
        
public struct MembershipChangeEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent"
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
        
public struct ReadEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.subscribeConvoEvents#readEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let messageId: String?
            public let readAt: ATProtocolDate

        public init(
            cursor: String, convoId: String, did: DID, messageId: String?, readAt: ATProtocolDate
        ) {
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.messageId = messageId
            self.readAt = readAt
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
                self.messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'messageId': \(error)")
                throw error
            }
            do {
                self.readAt = try container.decode(ATProtocolDate.self, forKey: .readAt)
            } catch {
                LogManager.logError("Decoding error for required property 'readAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cursor, forKey: .cursor)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(did, forKey: .did)
            try container.encodeIfPresent(messageId, forKey: .messageId)
            try container.encode(readAt, forKey: .readAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            if let value = messageId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(readAt)
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
            if readAt != other.readAt {
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
            if let value = messageId {
                let messageIdValue = try value.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
            }
            let readAtValue = try readAt.toCBORValue()
            map = map.adding(key: "readAt", value: readAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case messageId
            case readAt
        }
    }    
public struct Parameters: Parametrizable {
        public let cursor: String?
        public let convoId: String?
        public let ticket: String?
        
        public init(
            cursor: String? = nil, 
            convoId: String? = nil, 
            ticket: String? = nil
            ) {
            self.cursor = cursor
            self.convoId = convoId
            self.ticket = ticket
            
        }
    }
public enum Message: Codable, Sendable {

    case messageEvent(MessageEvent)

    case reactionEvent(ReactionEvent)

    case typingEvent(TypingEvent)

    case infoEvent(InfoEvent)

    case newDeviceEvent(NewDeviceEvent)

    case groupInfoRefreshRequestedEvent(GroupInfoRefreshRequestedEvent)

    case readditionRequestedEvent(ReadditionRequestedEvent)

    case membershipChangeEvent(MembershipChangeEvent)

    case readEvent(ReadEvent)


    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {

        case "blue.catbird.mlsChat.subscribeConvoEvents#messageEvent":
            let value = try MessageEvent(from: decoder)
            self = .messageEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent":
            let value = try ReactionEvent(from: decoder)
            self = .reactionEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#typingEvent":
            let value = try TypingEvent(from: decoder)
            self = .typingEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#infoEvent":
            let value = try InfoEvent(from: decoder)
            self = .infoEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent":
            let value = try NewDeviceEvent(from: decoder)
            self = .newDeviceEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent":
            let value = try GroupInfoRefreshRequestedEvent(from: decoder)
            self = .groupInfoRefreshRequestedEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent":
            let value = try ReadditionRequestedEvent(from: decoder)
            self = .readditionRequestedEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent":
            let value = try MembershipChangeEvent(from: decoder)
            self = .membershipChangeEvent(value)

        case "blue.catbird.mlsChat.subscribeConvoEvents#readEvent":
            let value = try ReadEvent(from: decoder)
            self = .readEvent(value)

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

        case .reactionEvent(let value):
            try value.encode(to: encoder)

        case .typingEvent(let value):
            try value.encode(to: encoder)

        case .infoEvent(let value):
            try value.encode(to: encoder)

        case .newDeviceEvent(let value):
            try value.encode(to: encoder)

        case .groupInfoRefreshRequestedEvent(let value):
            try value.encode(to: encoder)

        case .readditionRequestedEvent(let value):
            try value.encode(to: encoder)

        case .membershipChangeEvent(let value):
            try value.encode(to: encoder)

        case .readEvent(let value):
            try value.encode(to: encoder)

        }
    }
}





public enum EventWrapperEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(BlueCatbirdMlsChatSubscribeConvoEvents.MessageEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(BlueCatbirdMlsChatSubscribeConvoEvents.ReactionEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(BlueCatbirdMlsChatSubscribeConvoEvents.TypingEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(BlueCatbirdMlsChatSubscribeConvoEvents.InfoEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(BlueCatbirdMlsChatSubscribeConvoEvents.NewDeviceEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(BlueCatbirdMlsChatSubscribeConvoEvents.GroupInfoRefreshRequestedEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(BlueCatbirdMlsChatSubscribeConvoEvents.ReadditionRequestedEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(BlueCatbirdMlsChatSubscribeConvoEvents.MembershipChangeEvent)
    case blueCatbirdMlsChatSubscribeConvoEventsReadEvent(BlueCatbirdMlsChatSubscribeConvoEvents.ReadEvent)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.MessageEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.ReactionEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.TypingEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.InfoEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.NewDeviceEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.GroupInfoRefreshRequestedEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.ReadditionRequestedEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.MembershipChangeEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(value)
    }
    public init(_ value: BlueCatbirdMlsChatSubscribeConvoEvents.ReadEvent) {
        self = .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "blue.catbird.mlsChat.subscribeConvoEvents#messageEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.MessageEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.ReactionEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#typingEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.TypingEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#infoEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.InfoEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.NewDeviceEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.GroupInfoRefreshRequestedEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.ReadditionRequestedEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.MembershipChangeEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(value)
        case "blue.catbird.mlsChat.subscribeConvoEvents#readEvent":
            let value = try BlueCatbirdMlsChatSubscribeConvoEvents.ReadEvent(from: decoder)
            self = .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#messageEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#typingEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#infoEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent", forKey: .type)
            try value.encode(to: encoder)
        case .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(let value):
            try container.encode("blue.catbird.mlsChat.subscribeConvoEvents#readEvent", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#messageEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#typingEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#infoEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent")
            hasher.combine(value)
        case .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(let value):
            hasher.combine("blue.catbird.mlsChat.subscribeConvoEvents#readEvent")
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
        case (.blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.blueCatbirdMlsChatSubscribeConvoEventsReadEvent(let lhsValue),
              .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(let rhsValue)):
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
        case .blueCatbirdMlsChatSubscribeConvoEventsMessageEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#messageEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsReactionEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#reactionEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsTypingEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#typingEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsInfoEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#infoEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#newDeviceEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#groupInfoRefreshRequestedEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#readditionRequestedEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#membershipChangeEvent")
            
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
        case .blueCatbirdMlsChatSubscribeConvoEventsReadEvent(let value):
            map = map.adding(key: "$type", value: "blue.catbird.mlsChat.subscribeConvoEvents#readEvent")
            
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


                           

/// Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user

extension ATProtoClient.Blue.Catbird.MlsChat {
    
    public func subscribeConvoEvents(
        cursor: String? = nil, convoId: String? = nil, ticket: String? = nil
    ) async throws -> AsyncThrowingStream<BlueCatbirdMlsChatSubscribeConvoEvents.Message, Error> {
        let params = BlueCatbirdMlsChatSubscribeConvoEvents.Parameters(cursor: cursor, convoId: convoId, ticket: ticket)
        return try await self.networkService.subscribe(
            endpoint: "blue.catbird.mlsChat.subscribeConvoEvents",
            parameters: params
        )
    }

    /// Alternative signature accepting input struct
    public func subscribeConvoEvents(input: BlueCatbirdMlsChatSubscribeConvoEvents.Parameters) async throws -> AsyncThrowingStream<BlueCatbirdMlsChatSubscribeConvoEvents.Message, Error> {
        return try await self.networkService.subscribe(
            endpoint: "blue.catbird.mlsChat.subscribeConvoEvents",
            parameters: input
        )
    }
    
}
