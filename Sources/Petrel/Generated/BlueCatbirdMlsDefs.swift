import Foundation



// lexicon: 1, id: blue.catbird.mls.defs


public struct BlueCatbirdMlsDefs { 

    public static let typeIdentifier = "blue.catbird.mls.defs"
        
public struct ConvoView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.defs#convoView"
            public let id: String
            public let groupId: String
            public let creator: DID
            public let members: [MemberView]
            public let epoch: Int
            public let cipherSuite: String
            public let createdAt: ATProtocolDate
            public let lastMessageAt: ATProtocolDate?
            public let metadata: ConvoMetadata?

        // Standard initializer
        public init(
            id: String, groupId: String, creator: DID, members: [MemberView], epoch: Int, cipherSuite: String, createdAt: ATProtocolDate, lastMessageAt: ATProtocolDate?, metadata: ConvoMetadata?
        ) {
            
            self.id = id
            self.groupId = groupId
            self.creator = creator
            self.members = members
            self.epoch = epoch
            self.cipherSuite = cipherSuite
            self.createdAt = createdAt
            self.lastMessageAt = lastMessageAt
            self.metadata = metadata
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decode(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.groupId = try container.decode(String.self, forKey: .groupId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'groupId': \(error)")
                
                throw error
            }
            do {
                
                
                self.creator = try container.decode(DID.self, forKey: .creator)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'creator': \(error)")
                
                throw error
            }
            do {
                
                
                self.members = try container.decode([MemberView].self, forKey: .members)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'members': \(error)")
                
                throw error
            }
            do {
                
                
                self.epoch = try container.decode(Int.self, forKey: .epoch)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                
                throw error
            }
            do {
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.lastMessageAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastMessageAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'lastMessageAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.metadata = try container.decodeIfPresent(ConvoMetadata.self, forKey: .metadata)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'metadata': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(id, forKey: .id)
            
            
            
            
            try container.encode(groupId, forKey: .groupId)
            
            
            
            
            try container.encode(creator, forKey: .creator)
            
            
            
            
            try container.encode(members, forKey: .members)
            
            
            
            
            try container.encode(epoch, forKey: .epoch)
            
            
            
            
            try container.encode(cipherSuite, forKey: .cipherSuite)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(metadata, forKey: .metadata)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
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
            
            
            if self.id != other.id {
                return false
            }
            
            
            
            
            if self.groupId != other.groupId {
                return false
            }
            
            
            
            
            if self.creator != other.creator {
                return false
            }
            
            
            
            
            if self.members != other.members {
                return false
            }
            
            
            
            
            if self.epoch != other.epoch {
                return false
            }
            
            
            
            
            if self.cipherSuite != other.cipherSuite {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            
            
            
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
                // Encode optional property even if it's an empty array for CBOR
                
                let lastMessageAtValue = try value.toCBORValue()
                map = map.adding(key: "lastMessageAt", value: lastMessageAtValue)
            }
            
            
            
            
            
            if let value = metadata {
                // Encode optional property even if it's an empty array for CBOR
                
                let metadataValue = try value.toCBORValue()
                map = map.adding(key: "metadata", value: metadataValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
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

        // Standard initializer
        public init(
            name: String?, description: String?
        ) {
            
            self.name = name
            self.description = description
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(name, forKey: .name)
            
            
            
            
            // Encode optional property even if it's an empty array
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = name {
                // Encode optional property even if it's an empty array for CBOR
                
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            
            
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
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
            public let joinedAt: ATProtocolDate
            public let leafIndex: Int?
            public let credential: Bytes?

        // Standard initializer
        public init(
            did: DID, joinedAt: ATProtocolDate, leafIndex: Int?, credential: Bytes?
        ) {
            
            self.did = did
            self.joinedAt = joinedAt
            self.leafIndex = leafIndex
            self.credential = credential
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedAt = try container.decode(ATProtocolDate.self, forKey: .joinedAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'joinedAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.leafIndex = try container.decodeIfPresent(Int.self, forKey: .leafIndex)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'leafIndex': \(error)")
                
                throw error
            }
            do {
                
                
                self.credential = try container.decodeIfPresent(Bytes.self, forKey: .credential)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'credential': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(joinedAt, forKey: .joinedAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(leafIndex, forKey: .leafIndex)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(credential, forKey: .credential)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(joinedAt)
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
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.joinedAt != other.joinedAt {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let joinedAtValue = try joinedAt.toCBORValue()
            map = map.adding(key: "joinedAt", value: joinedAtValue)
            
            
            
            
            
            if let value = leafIndex {
                // Encode optional property even if it's an empty array for CBOR
                
                let leafIndexValue = try value.toCBORValue()
                map = map.adding(key: "leafIndex", value: leafIndexValue)
            }
            
            
            
            
            
            if let value = credential {
                // Encode optional property even if it's an empty array for CBOR
                
                let credentialValue = try value.toCBORValue()
                map = map.adding(key: "credential", value: credentialValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case joinedAt
            case leafIndex
            case credential
        }
    }
        
public struct MessageView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.defs#messageView"
            public let id: String
            public let convoId: String
            public let sender: DID
            public let ciphertext: Bytes
            public let epoch: Int
            public let seq: Int
            public let createdAt: ATProtocolDate
            public let embedType: String?
            public let embedUri: URI?

        // Standard initializer
        public init(
            id: String, convoId: String, sender: DID, ciphertext: Bytes, epoch: Int, seq: Int, createdAt: ATProtocolDate, embedType: String?, embedUri: URI?
        ) {
            
            self.id = id
            self.convoId = convoId
            self.sender = sender
            self.ciphertext = ciphertext
            self.epoch = epoch
            self.seq = seq
            self.createdAt = createdAt
            self.embedType = embedType
            self.embedUri = embedUri
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decode(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.sender = try container.decode(DID.self, forKey: .sender)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'sender': \(error)")
                
                throw error
            }
            do {
                
                
                self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'ciphertext': \(error)")
                
                throw error
            }
            do {
                
                
                self.epoch = try container.decode(Int.self, forKey: .epoch)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                
                throw error
            }
            do {
                
                
                self.seq = try container.decode(Int.self, forKey: .seq)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'seq': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.embedType = try container.decodeIfPresent(String.self, forKey: .embedType)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'embedType': \(error)")
                
                throw error
            }
            do {
                
                
                self.embedUri = try container.decodeIfPresent(URI.self, forKey: .embedUri)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'embedUri': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(id, forKey: .id)
            
            
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(sender, forKey: .sender)
            
            
            
            
            try container.encode(ciphertext, forKey: .ciphertext)
            
            
            
            
            try container.encode(epoch, forKey: .epoch)
            
            
            
            
            try container.encode(seq, forKey: .seq)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embedType, forKey: .embedType)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embedUri, forKey: .embedUri)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(convoId)
            hasher.combine(sender)
            hasher.combine(ciphertext)
            hasher.combine(epoch)
            hasher.combine(seq)
            hasher.combine(createdAt)
            if let value = embedType {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embedUri {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.id != other.id {
                return false
            }
            
            
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.sender != other.sender {
                return false
            }
            
            
            
            
            if self.ciphertext != other.ciphertext {
                return false
            }
            
            
            
            
            if self.epoch != other.epoch {
                return false
            }
            
            
            
            
            if self.seq != other.seq {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if embedType != other.embedType {
                return false
            }
            
            
            
            
            if embedUri != other.embedUri {
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

            
            
            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let senderValue = try sender.toCBORValue()
            map = map.adding(key: "sender", value: senderValue)
            
            
            
            
            
            
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            
            
            
            
            
            
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            
            
            
            
            
            
            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)
            
            
            
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            
            
            if let value = embedType {
                // Encode optional property even if it's an empty array for CBOR
                
                let embedTypeValue = try value.toCBORValue()
                map = map.adding(key: "embedType", value: embedTypeValue)
            }
            
            
            
            
            
            if let value = embedUri {
                // Encode optional property even if it's an empty array for CBOR
                
                let embedUriValue = try value.toCBORValue()
                map = map.adding(key: "embedUri", value: embedUriValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case convoId
            case sender
            case ciphertext
            case epoch
            case seq
            case createdAt
            case embedType
            case embedUri
        }
    }
        
public struct KeyPackageRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.defs#keyPackageRef"
            public let did: DID
            public let keyPackage: String
            public let cipherSuite: String

        // Standard initializer
        public init(
            did: DID, keyPackage: String, cipherSuite: String
        ) {
            
            self.did = did
            self.keyPackage = keyPackage
            self.cipherSuite = cipherSuite
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.keyPackage = try container.decode(String.self, forKey: .keyPackage)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'keyPackage': \(error)")
                
                throw error
            }
            do {
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
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
            
            
            
            
            try container.encode(cipherSuite, forKey: .cipherSuite)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(keyPackage)
            hasher.combine(cipherSuite)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.keyPackage != other.keyPackage {
                return false
            }
            
            
            
            
            if self.cipherSuite != other.cipherSuite {
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

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            
            
            
            
            
            
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case keyPackage
            case cipherSuite
        }
    }



}


                           

