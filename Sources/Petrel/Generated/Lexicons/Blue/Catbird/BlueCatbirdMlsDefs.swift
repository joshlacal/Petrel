import Foundation

// lexicon: 1, id: blue.catbird.mls.defs

public enum BlueCatbirdMlsDefs {
    public static let typeIdentifier = "blue.catbird.mls.defs"

    public struct ConvoView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.defs#convoView"
        public let groupId: String
        public let creator: DID
        public let members: [MemberView]
        public let epoch: Int
        public let cipherSuite: String
        public let createdAt: ATProtocolDate
        public let lastMessageAt: ATProtocolDate?
        public let metadata: ConvoMetadata?

        public init(
            groupId: String, creator: DID, members: [MemberView], epoch: Int, cipherSuite: String, createdAt: ATProtocolDate, lastMessageAt: ATProtocolDate?, metadata: ConvoMetadata?
        ) {
            self.groupId = groupId
            self.creator = creator
            self.members = members
            self.epoch = epoch
            self.cipherSuite = cipherSuite
            self.createdAt = createdAt
            self.lastMessageAt = lastMessageAt
            self.metadata = metadata
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
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
                metadata = try container.decodeIfPresent(ConvoMetadata.self, forKey: .metadata)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'metadata': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(groupId, forKey: .groupId)
            try container.encode(creator, forKey: .creator)
            try container.encode(members, forKey: .members)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        }

        public func hash(into hasher: inout Hasher) {
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
            if let value = metadata {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
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
            if metadata != other.metadata {
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
            if let value = metadata {
                let metadataValue = try value.toCBORValue()
                map = map.adding(key: "metadata", value: metadataValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case groupId
            case creator
            case members
            case epoch
            case cipherSuite
            case createdAt
            case lastMessageAt
            case metadata
        }
    }

    public struct ConvoMetadata: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.defs#convoMetadata"
        public let name: String?
        public let description: String?

        public init(
            name: String?, description: String?
        ) {
            self.name = name
            self.description = description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decodeIfPresent(String.self, forKey: .name)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = name {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if name != other.name {
                return false
            }
            if description != other.description {
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
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case description
        }
    }

    public struct MemberView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.defs#memberView"
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
        public static let typeIdentifier = "blue.catbird.mls.defs#messageView"
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
        public static let typeIdentifier = "blue.catbird.mls.defs#keyPackageRef"
        public let did: DID
        public let keyPackage: String
        public let keyPackageHash: String?
        public let cipherSuite: String

        public init(
            did: DID, keyPackage: String, keyPackageHash: String?, cipherSuite: String
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
                keyPackage = try container.decode(String.self, forKey: .keyPackage)
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
}
