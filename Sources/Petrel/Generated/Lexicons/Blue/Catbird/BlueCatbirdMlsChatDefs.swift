import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.defs

public enum BlueCatbirdMlsChatDefs {
    public static let typeIdentifier = "blue.catbird.mlsChat.defs"

    public struct ConvoView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.defs#convoView"
        public let conversationId: String
        public let groupId: String
        public let creator: DID
        public let members: [MemberView]
        public let epoch: Int
        public let cipherSuite: String
        public let createdAt: ATProtocolDate
        public let lastMessageAt: ATProtocolDate?
        public let confirmationTag: Bytes?
        public let resetGeneration: Int?

        public init(
            conversationId: String, groupId: String, creator: DID, members: [MemberView], epoch: Int, cipherSuite: String, createdAt: ATProtocolDate, lastMessageAt: ATProtocolDate?, confirmationTag: Bytes?, resetGeneration: Int?
        ) {
            self.conversationId = conversationId
            self.groupId = groupId
            self.creator = creator
            self.members = members
            self.epoch = epoch
            self.cipherSuite = cipherSuite
            self.createdAt = createdAt
            self.lastMessageAt = lastMessageAt
            self.confirmationTag = confirmationTag
            self.resetGeneration = resetGeneration
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                conversationId = try container.decode(String.self, forKey: .conversationId)
            } catch {
                LogManager.logError("Decoding error for required property 'conversationId': \(error)")
                throw error
            }
            do {
                groupId = try container.decode(String.self, forKey: .groupId)
            } catch {
                LogManager.logError("Decoding error for required property 'groupId': \(error)")
                throw error
            }
            do {
                creator = try container.decode(DID.self, forKey: .creator)
            } catch {
                LogManager.logError("Decoding error for required property 'creator': \(error)")
                throw error
            }
            do {
                members = try container.decode([MemberView].self, forKey: .members)
            } catch {
                LogManager.logError("Decoding error for required property 'members': \(error)")
                throw error
            }
            do {
                epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
            do {
                cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                lastMessageAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastMessageAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'lastMessageAt': \(error)")
                throw error
            }
            do {
                confirmationTag = try container.decodeIfPresent(Bytes.self, forKey: .confirmationTag)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'confirmationTag': \(error)")
                throw error
            }
            do {
                resetGeneration = try container.decodeIfPresent(Int.self, forKey: .resetGeneration)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'resetGeneration': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(conversationId, forKey: .conversationId)
            try container.encode(groupId, forKey: .groupId)
            try container.encode(creator, forKey: .creator)
            try container.encode(members, forKey: .members)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
            try container.encodeIfPresent(resetGeneration, forKey: .resetGeneration)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(conversationId)
            hasher.combine(groupId)
            hasher.combine(creator)
            hasher.combine(members)
            hasher.combine(epoch)
            hasher.combine(cipherSuite)
            hasher.combine(createdAt)
            if let value = lastMessageAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = confirmationTag {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = resetGeneration {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if conversationId != other.conversationId {
                return false
            }
            if groupId != other.groupId {
                return false
            }
            if creator != other.creator {
                return false
            }
            if members != other.members {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if cipherSuite != other.cipherSuite {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if lastMessageAt != other.lastMessageAt {
                return false
            }
            if confirmationTag != other.confirmationTag {
                return false
            }
            if resetGeneration != other.resetGeneration {
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
            let conversationIdValue = try conversationId.toCBORValue()
            map = map.adding(key: "conversationId", value: conversationIdValue)
            let groupIdValue = try groupId.toCBORValue()
            map = map.adding(key: "groupId", value: groupIdValue)
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            let membersValue = try members.toCBORValue()
            map = map.adding(key: "members", value: membersValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = lastMessageAt {
                let lastMessageAtValue = try value.toCBORValue()
                map = map.adding(key: "lastMessageAt", value: lastMessageAtValue)
            }
            if let value = confirmationTag {
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }
            if let value = resetGeneration {
                let resetGenerationValue = try value.toCBORValue()
                map = map.adding(key: "resetGeneration", value: resetGenerationValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case conversationId
            case groupId
            case creator
            case members
            case epoch
            case cipherSuite
            case createdAt
            case lastMessageAt
            case confirmationTag
            case resetGeneration
        }
    }

    public struct MemberView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.defs#memberView"
        public let did: DID
        public let userDid: DID
        public let deviceId: String?
        public let deviceName: String?
        public let joinedAt: ATProtocolDate
        public let isAdmin: Bool
        public let isModerator: Bool?
        public let promotedAt: ATProtocolDate?
        public let promotedBy: DID?
        public let leafIndex: Int?
        public let credential: Bytes?

        public init(
            did: DID, userDid: DID, deviceId: String?, deviceName: String?, joinedAt: ATProtocolDate, isAdmin: Bool, isModerator: Bool?, promotedAt: ATProtocolDate?, promotedBy: DID?, leafIndex: Int?, credential: Bytes?
        ) {
            self.did = did
            self.userDid = userDid
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.joinedAt = joinedAt
            self.isAdmin = isAdmin
            self.isModerator = isModerator
            self.promotedAt = promotedAt
            self.promotedBy = promotedBy
            self.leafIndex = leafIndex
            self.credential = credential
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
                userDid = try container.decode(DID.self, forKey: .userDid)
            } catch {
                LogManager.logError("Decoding error for required property 'userDid': \(error)")
                throw error
            }
            do {
                deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceId': \(error)")
                throw error
            }
            do {
                deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceName': \(error)")
                throw error
            }
            do {
                joinedAt = try container.decode(ATProtocolDate.self, forKey: .joinedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'joinedAt': \(error)")
                throw error
            }
            do {
                isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
            } catch {
                LogManager.logError("Decoding error for required property 'isAdmin': \(error)")
                throw error
            }
            do {
                isModerator = try container.decodeIfPresent(Bool.self, forKey: .isModerator)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'isModerator': \(error)")
                throw error
            }
            do {
                promotedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .promotedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'promotedAt': \(error)")
                throw error
            }
            do {
                promotedBy = try container.decodeIfPresent(DID.self, forKey: .promotedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'promotedBy': \(error)")
                throw error
            }
            do {
                leafIndex = try container.decodeIfPresent(Int.self, forKey: .leafIndex)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'leafIndex': \(error)")
                throw error
            }
            do {
                credential = try container.decodeIfPresent(Bytes.self, forKey: .credential)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'credential': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(userDid, forKey: .userDid)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(joinedAt, forKey: .joinedAt)
            try container.encode(isAdmin, forKey: .isAdmin)
            try container.encodeIfPresent(isModerator, forKey: .isModerator)
            try container.encodeIfPresent(promotedAt, forKey: .promotedAt)
            try container.encodeIfPresent(promotedBy, forKey: .promotedBy)
            try container.encodeIfPresent(leafIndex, forKey: .leafIndex)
            try container.encodeIfPresent(credential, forKey: .credential)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(userDid)
            if let value = deviceId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(joinedAt)
            hasher.combine(isAdmin)
            if let value = isModerator {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = promotedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = promotedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = leafIndex {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = credential {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
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
            if joinedAt != other.joinedAt {
                return false
            }
            if isAdmin != other.isAdmin {
                return false
            }
            if isModerator != other.isModerator {
                return false
            }
            if promotedAt != other.promotedAt {
                return false
            }
            if promotedBy != other.promotedBy {
                return false
            }
            if leafIndex != other.leafIndex {
                return false
            }
            if credential != other.credential {
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
            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            if let value = deviceName {
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }
            let joinedAtValue = try joinedAt.toCBORValue()
            map = map.adding(key: "joinedAt", value: joinedAtValue)
            let isAdminValue = try isAdmin.toCBORValue()
            map = map.adding(key: "isAdmin", value: isAdminValue)
            if let value = isModerator {
                let isModeratorValue = try value.toCBORValue()
                map = map.adding(key: "isModerator", value: isModeratorValue)
            }
            if let value = promotedAt {
                let promotedAtValue = try value.toCBORValue()
                map = map.adding(key: "promotedAt", value: promotedAtValue)
            }
            if let value = promotedBy {
                let promotedByValue = try value.toCBORValue()
                map = map.adding(key: "promotedBy", value: promotedByValue)
            }
            if let value = leafIndex {
                let leafIndexValue = try value.toCBORValue()
                map = map.adding(key: "leafIndex", value: leafIndexValue)
            }
            if let value = credential {
                let credentialValue = try value.toCBORValue()
                map = map.adding(key: "credential", value: credentialValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case userDid
            case deviceId
            case deviceName
            case joinedAt
            case isAdmin
            case isModerator
            case promotedAt
            case promotedBy
            case leafIndex
            case credential
        }
    }

    public struct MessageView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.defs#messageView"
        public let id: String
        public let convoId: String
        public let ciphertext: Bytes
        public let epoch: Int
        public let seq: Int
        public let createdAt: ATProtocolDate
        public let messageType: String?

        public init(
            id: String, convoId: String, ciphertext: Bytes, epoch: Int, seq: Int, createdAt: ATProtocolDate, messageType: String?
        ) {
            self.id = id
            self.convoId = convoId
            self.ciphertext = ciphertext
            self.epoch = epoch
            self.seq = seq
            self.createdAt = createdAt
            self.messageType = messageType
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
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
            } catch {
                LogManager.logError("Decoding error for required property 'ciphertext': \(error)")
                throw error
            }
            do {
                epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
            do {
                seq = try container.decode(Int.self, forKey: .seq)
            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'messageType': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(seq, forKey: .seq)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(messageType, forKey: .messageType)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(convoId)
            hasher.combine(ciphertext)
            hasher.combine(epoch)
            hasher.combine(seq)
            hasher.combine(createdAt)
            if let value = messageType {
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
            if convoId != other.convoId {
                return false
            }
            if ciphertext != other.ciphertext {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if seq != other.seq {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if messageType != other.messageType {
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
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = messageType {
                let messageTypeValue = try value.toCBORValue()
                map = map.adding(key: "messageType", value: messageTypeValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case convoId
            case ciphertext
            case epoch
            case seq
            case createdAt
            case messageType
        }
    }

    public struct KeyPackageRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.defs#keyPackageRef"
        public let did: DID
        public let keyPackage: Bytes
        public let keyPackageHash: String?
        public let cipherSuite: String

        public init(
            did: DID, keyPackage: Bytes, keyPackageHash: String?, cipherSuite: String
        ) {
            self.did = did
            self.keyPackage = keyPackage
            self.keyPackageHash = keyPackageHash
            self.cipherSuite = cipherSuite
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
                keyPackage = try container.decode(Bytes.self, forKey: .keyPackage)
            } catch {
                LogManager.logError("Decoding error for required property 'keyPackage': \(error)")
                throw error
            }
            do {
                keyPackageHash = try container.decodeIfPresent(String.self, forKey: .keyPackageHash)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'keyPackageHash': \(error)")
                throw error
            }
            do {
                cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(keyPackage, forKey: .keyPackage)
            try container.encodeIfPresent(keyPackageHash, forKey: .keyPackageHash)
            try container.encode(cipherSuite, forKey: .cipherSuite)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(keyPackage)
            if let value = keyPackageHash {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(cipherSuite)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if keyPackage != other.keyPackage {
                return false
            }
            if keyPackageHash != other.keyPackageHash {
                return false
            }
            if cipherSuite != other.cipherSuite {
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
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            if let value = keyPackageHash {
                let keyPackageHashValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            }
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case keyPackage
            case keyPackageHash
            case cipherSuite
        }
    }

    public struct WelcomeReissueRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.defs#welcomeReissueRequest"
        public let convoId: String
        public let recipientDeviceDid: DID
        public let requestedAt: ATProtocolDate
        public let requestId: String

        public init(
            convoId: String, recipientDeviceDid: DID, requestedAt: ATProtocolDate, requestId: String
        ) {
            self.convoId = convoId
            self.recipientDeviceDid = recipientDeviceDid
            self.requestedAt = requestedAt
            self.requestId = requestId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                recipientDeviceDid = try container.decode(DID.self, forKey: .recipientDeviceDid)
            } catch {
                LogManager.logError("Decoding error for required property 'recipientDeviceDid': \(error)")
                throw error
            }
            do {
                requestedAt = try container.decode(ATProtocolDate.self, forKey: .requestedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedAt': \(error)")
                throw error
            }
            do {
                requestId = try container.decode(String.self, forKey: .requestId)
            } catch {
                LogManager.logError("Decoding error for required property 'requestId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(recipientDeviceDid, forKey: .recipientDeviceDid)
            try container.encode(requestedAt, forKey: .requestedAt)
            try container.encode(requestId, forKey: .requestId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(recipientDeviceDid)
            hasher.combine(requestedAt)
            hasher.combine(requestId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if recipientDeviceDid != other.recipientDeviceDid {
                return false
            }
            if requestedAt != other.requestedAt {
                return false
            }
            if requestId != other.requestId {
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
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let recipientDeviceDidValue = try recipientDeviceDid.toCBORValue()
            map = map.adding(key: "recipientDeviceDid", value: recipientDeviceDidValue)
            let requestedAtValue = try requestedAt.toCBORValue()
            map = map.adding(key: "requestedAt", value: requestedAtValue)
            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case recipientDeviceDid
            case requestedAt
            case requestId
        }
    }
}
