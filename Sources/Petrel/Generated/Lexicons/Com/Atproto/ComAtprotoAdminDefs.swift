import Foundation



// lexicon: 1, id: com.atproto.admin.defs


public struct ComAtprotoAdminDefs { 

    public static let typeIdentifier = "com.atproto.admin.defs"
        
public struct StatusAttr: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.admin.defs#statusAttr"
            public let applied: Bool
            public let ref: String?

        public init(
            applied: Bool, ref: String?
        ) {
            self.applied = applied
            self.ref = ref
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.applied = try container.decode(Bool.self, forKey: .applied)
            } catch {
                LogManager.logError("Decoding error for required property 'applied': \(error)")
                throw error
            }
            do {
                self.ref = try container.decodeIfPresent(String.self, forKey: .ref)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'ref': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(applied, forKey: .applied)
            try container.encodeIfPresent(ref, forKey: .ref)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(applied)
            if let value = ref {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if applied != other.applied {
                return false
            }
            if ref != other.ref {
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
            let appliedValue = try applied.toCBORValue()
            map = map.adding(key: "applied", value: appliedValue)
            if let value = ref {
                let refValue = try value.toCBORValue()
                map = map.adding(key: "ref", value: refValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case applied
            case ref
        }
    }
        
public struct AccountView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.admin.defs#accountView"
            public let did: DID
            public let handle: Handle
            public let email: String?
            public let relatedRecords: [ATProtocolValueContainer]?
            public let indexedAt: ATProtocolDate
            public let invitedBy: ComAtprotoServerDefs.InviteCode?
            public let invites: [ComAtprotoServerDefs.InviteCode]?
            public let invitesDisabled: Bool?
            public let emailConfirmedAt: ATProtocolDate?
            public let inviteNote: String?
            public let deactivatedAt: ATProtocolDate?
            public let threatSignatures: [ThreatSignature]?

        public init(
            did: DID, handle: Handle, email: String?, relatedRecords: [ATProtocolValueContainer]?, indexedAt: ATProtocolDate, invitedBy: ComAtprotoServerDefs.InviteCode?, invites: [ComAtprotoServerDefs.InviteCode]?, invitesDisabled: Bool?, emailConfirmedAt: ATProtocolDate?, inviteNote: String?, deactivatedAt: ATProtocolDate?, threatSignatures: [ThreatSignature]?
        ) {
            self.did = did
            self.handle = handle
            self.email = email
            self.relatedRecords = relatedRecords
            self.indexedAt = indexedAt
            self.invitedBy = invitedBy
            self.invites = invites
            self.invitesDisabled = invitesDisabled
            self.emailConfirmedAt = emailConfirmedAt
            self.inviteNote = inviteNote
            self.deactivatedAt = deactivatedAt
            self.threatSignatures = threatSignatures
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                self.handle = try container.decode(Handle.self, forKey: .handle)
            } catch {
                LogManager.logError("Decoding error for required property 'handle': \(error)")
                throw error
            }
            do {
                self.email = try container.decodeIfPresent(String.self, forKey: .email)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'email': \(error)")
                throw error
            }
            do {
                self.relatedRecords = try container.decodeIfPresent([ATProtocolValueContainer].self, forKey: .relatedRecords)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'relatedRecords': \(error)")
                throw error
            }
            do {
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")
                throw error
            }
            do {
                self.invitedBy = try container.decodeIfPresent(ComAtprotoServerDefs.InviteCode.self, forKey: .invitedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'invitedBy': \(error)")
                throw error
            }
            do {
                self.invites = try container.decodeIfPresent([ComAtprotoServerDefs.InviteCode].self, forKey: .invites)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'invites': \(error)")
                throw error
            }
            do {
                self.invitesDisabled = try container.decodeIfPresent(Bool.self, forKey: .invitesDisabled)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'invitesDisabled': \(error)")
                throw error
            }
            do {
                self.emailConfirmedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .emailConfirmedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'emailConfirmedAt': \(error)")
                throw error
            }
            do {
                self.inviteNote = try container.decodeIfPresent(String.self, forKey: .inviteNote)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'inviteNote': \(error)")
                throw error
            }
            do {
                self.deactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deactivatedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deactivatedAt': \(error)")
                throw error
            }
            do {
                self.threatSignatures = try container.decodeIfPresent([ThreatSignature].self, forKey: .threatSignatures)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'threatSignatures': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(handle, forKey: .handle)
            try container.encodeIfPresent(email, forKey: .email)
            try container.encodeIfPresent(relatedRecords, forKey: .relatedRecords)
            try container.encode(indexedAt, forKey: .indexedAt)
            try container.encodeIfPresent(invitedBy, forKey: .invitedBy)
            try container.encodeIfPresent(invites, forKey: .invites)
            try container.encodeIfPresent(invitesDisabled, forKey: .invitesDisabled)
            try container.encodeIfPresent(emailConfirmedAt, forKey: .emailConfirmedAt)
            try container.encodeIfPresent(inviteNote, forKey: .inviteNote)
            try container.encodeIfPresent(deactivatedAt, forKey: .deactivatedAt)
            try container.encodeIfPresent(threatSignatures, forKey: .threatSignatures)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = relatedRecords {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(indexedAt)
            if let value = invitedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invites {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invitesDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = emailConfirmedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = inviteNote {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deactivatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = threatSignatures {
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
            if handle != other.handle {
                return false
            }
            if email != other.email {
                return false
            }
            if relatedRecords != other.relatedRecords {
                return false
            }
            if indexedAt != other.indexedAt {
                return false
            }
            if invitedBy != other.invitedBy {
                return false
            }
            if invites != other.invites {
                return false
            }
            if invitesDisabled != other.invitesDisabled {
                return false
            }
            if emailConfirmedAt != other.emailConfirmedAt {
                return false
            }
            if inviteNote != other.inviteNote {
                return false
            }
            if deactivatedAt != other.deactivatedAt {
                return false
            }
            if threatSignatures != other.threatSignatures {
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
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            if let value = email {
                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }
            if let value = relatedRecords {
                let relatedRecordsValue = try value.toCBORValue()
                map = map.adding(key: "relatedRecords", value: relatedRecordsValue)
            }
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            if let value = invitedBy {
                let invitedByValue = try value.toCBORValue()
                map = map.adding(key: "invitedBy", value: invitedByValue)
            }
            if let value = invites {
                let invitesValue = try value.toCBORValue()
                map = map.adding(key: "invites", value: invitesValue)
            }
            if let value = invitesDisabled {
                let invitesDisabledValue = try value.toCBORValue()
                map = map.adding(key: "invitesDisabled", value: invitesDisabledValue)
            }
            if let value = emailConfirmedAt {
                let emailConfirmedAtValue = try value.toCBORValue()
                map = map.adding(key: "emailConfirmedAt", value: emailConfirmedAtValue)
            }
            if let value = inviteNote {
                let inviteNoteValue = try value.toCBORValue()
                map = map.adding(key: "inviteNote", value: inviteNoteValue)
            }
            if let value = deactivatedAt {
                let deactivatedAtValue = try value.toCBORValue()
                map = map.adding(key: "deactivatedAt", value: deactivatedAtValue)
            }
            if let value = threatSignatures {
                let threatSignaturesValue = try value.toCBORValue()
                map = map.adding(key: "threatSignatures", value: threatSignaturesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case email
            case relatedRecords
            case indexedAt
            case invitedBy
            case invites
            case invitesDisabled
            case emailConfirmedAt
            case inviteNote
            case deactivatedAt
            case threatSignatures
        }
    }
        
public struct RepoRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.admin.defs#repoRef"
            public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
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
        
public struct RepoBlobRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.admin.defs#repoBlobRef"
            public let did: DID
            public let cid: CID
            public let recordUri: ATProtocolURI?

        public init(
            did: DID, cid: CID, recordUri: ATProtocolURI?
        ) {
            self.did = did
            self.cid = cid
            self.recordUri = recordUri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.recordUri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .recordUri)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'recordUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(cid, forKey: .cid)
            try container.encodeIfPresent(recordUri, forKey: .recordUri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(cid)
            if let value = recordUri {
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
            if cid != other.cid {
                return false
            }
            if recordUri != other.recordUri {
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
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            if let value = recordUri {
                let recordUriValue = try value.toCBORValue()
                map = map.adding(key: "recordUri", value: recordUriValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case cid
            case recordUri
        }
    }
        
public struct ThreatSignature: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.admin.defs#threatSignature"
            public let property: String
            public let value: String

        public init(
            property: String, value: String
        ) {
            self.property = property
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.property = try container.decode(String.self, forKey: .property)
            } catch {
                LogManager.logError("Decoding error for required property 'property': \(error)")
                throw error
            }
            do {
                self.value = try container.decode(String.self, forKey: .value)
            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(property, forKey: .property)
            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(property)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if property != other.property {
                return false
            }
            if value != other.value {
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
            let propertyValue = try property.toCBORValue()
            map = map.adding(key: "property", value: propertyValue)
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case property
            case value
        }
    }



}


                           

