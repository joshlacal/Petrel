import Foundation

// lexicon: 1, id: com.atproto.admin.defs

public enum ComAtprotoAdminDefs {
    public static let typeIdentifier = "com.atproto.admin.defs"

    public struct StatusAttr: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.admin.defs#statusAttr"
        public let applied: Bool
        public let ref: String?

        // Standard initializer
        public init(
            applied: Bool, ref: String?
        ) {
            self.applied = applied
            self.ref = ref
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                applied = try container.decode(Bool.self, forKey: .applied)

            } catch {
                LogManager.logError("Decoding error for property 'applied': \(error)")
                throw error
            }
            do {
                ref = try container.decodeIfPresent(String.self, forKey: .ref)

            } catch {
                LogManager.logError("Decoding error for property 'ref': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(applied, forKey: .applied)

            if let value = ref {
                try container.encode(value, forKey: .ref)
            }
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let appliedValue = try (applied as? DAGCBOREncodable)?.toCBORValue() ?? applied
            map = map.adding(key: "applied", value: appliedValue)

            if let value = ref {
                let refValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
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

        // Standard initializer
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
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)

            } catch {
                LogManager.logError("Decoding error for property 'email': \(error)")
                throw error
            }
            do {
                relatedRecords = try container.decodeIfPresent([ATProtocolValueContainer].self, forKey: .relatedRecords)

            } catch {
                LogManager.logError("Decoding error for property 'relatedRecords': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                invitedBy = try container.decodeIfPresent(ComAtprotoServerDefs.InviteCode.self, forKey: .invitedBy)

            } catch {
                LogManager.logError("Decoding error for property 'invitedBy': \(error)")
                throw error
            }
            do {
                invites = try container.decodeIfPresent([ComAtprotoServerDefs.InviteCode].self, forKey: .invites)

            } catch {
                LogManager.logError("Decoding error for property 'invites': \(error)")
                throw error
            }
            do {
                invitesDisabled = try container.decodeIfPresent(Bool.self, forKey: .invitesDisabled)

            } catch {
                LogManager.logError("Decoding error for property 'invitesDisabled': \(error)")
                throw error
            }
            do {
                emailConfirmedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .emailConfirmedAt)

            } catch {
                LogManager.logError("Decoding error for property 'emailConfirmedAt': \(error)")
                throw error
            }
            do {
                inviteNote = try container.decodeIfPresent(String.self, forKey: .inviteNote)

            } catch {
                LogManager.logError("Decoding error for property 'inviteNote': \(error)")
                throw error
            }
            do {
                deactivatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deactivatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'deactivatedAt': \(error)")
                throw error
            }
            do {
                threatSignatures = try container.decodeIfPresent([ThreatSignature].self, forKey: .threatSignatures)

            } catch {
                LogManager.logError("Decoding error for property 'threatSignatures': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(handle, forKey: .handle)

            if let value = email {
                try container.encode(value, forKey: .email)
            }

            if let value = relatedRecords {
                if !value.isEmpty {
                    try container.encode(value, forKey: .relatedRecords)
                }
            }

            try container.encode(indexedAt, forKey: .indexedAt)

            if let value = invitedBy {
                try container.encode(value, forKey: .invitedBy)
            }

            if let value = invites {
                if !value.isEmpty {
                    try container.encode(value, forKey: .invites)
                }
            }

            if let value = invitesDisabled {
                try container.encode(value, forKey: .invitesDisabled)
            }

            if let value = emailConfirmedAt {
                try container.encode(value, forKey: .emailConfirmedAt)
            }

            if let value = inviteNote {
                try container.encode(value, forKey: .inviteNote)
            }

            if let value = deactivatedAt {
                try container.encode(value, forKey: .deactivatedAt)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    try container.encode(value, forKey: .threatSignatures)
                }
            }
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            if let value = email {
                let emailValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "email", value: emailValue)
            }

            if let value = relatedRecords {
                if !value.isEmpty {
                    let relatedRecordsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "relatedRecords", value: relatedRecordsValue)
                }
            }

            let indexedAtValue = try (indexedAt as? DAGCBOREncodable)?.toCBORValue() ?? indexedAt
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            if let value = invitedBy {
                let invitedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitedBy", value: invitedByValue)
            }

            if let value = invites {
                if !value.isEmpty {
                    let invitesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "invites", value: invitesValue)
                }
            }

            if let value = invitesDisabled {
                let invitesDisabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "invitesDisabled", value: invitesDisabledValue)
            }

            if let value = emailConfirmedAt {
                let emailConfirmedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "emailConfirmedAt", value: emailConfirmedAtValue)
            }

            if let value = inviteNote {
                let inviteNoteValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "inviteNote", value: inviteNoteValue)
            }

            if let value = deactivatedAt {
                let deactivatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deactivatedAt", value: deactivatedAtValue)
            }

            if let value = threatSignatures {
                if !value.isEmpty {
                    let threatSignaturesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "threatSignatures", value: threatSignaturesValue)
                }
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
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

        // Standard initializer
        public init(
            did: DID, cid: CID, recordUri: ATProtocolURI?
        ) {
            self.did = did
            self.cid = cid
            self.recordUri = recordUri
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
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                recordUri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .recordUri)

            } catch {
                LogManager.logError("Decoding error for property 'recordUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(cid, forKey: .cid)

            if let value = recordUri {
                try container.encode(value, forKey: .recordUri)
            }
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            if let value = recordUri {
                let recordUriValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
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

        // Standard initializer
        public init(
            property: String, value: String
        ) {
            self.property = property
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                property = try container.decode(String.self, forKey: .property)

            } catch {
                LogManager.logError("Decoding error for property 'property': \(error)")
                throw error
            }
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let propertyValue = try (property as? DAGCBOREncodable)?.toCBORValue() ?? property
            map = map.adding(key: "property", value: propertyValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
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
