import Foundation
internal import ZippyJSON

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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case applied
            case ref
        }
    }

    public struct AccountView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.admin.defs#accountView"
        public let did: String
        public let handle: String
        public let email: String?
        public let relatedRecords: [ATProtocolValueContainer]?
        public let indexedAt: ATProtocolDate
        public let invitedBy: ComAtprotoServerDefs.InviteCode?
        public let invites: [ComAtprotoServerDefs.InviteCode]?
        public let invitesDisabled: Bool?
        public let emailConfirmedAt: ATProtocolDate?
        public let inviteNote: String?
        public let deactivatedAt: ATProtocolDate?

        // Standard initializer
        public init(
            did: String, handle: String, email: String?, relatedRecords: [ATProtocolValueContainer]?, indexedAt: ATProtocolDate, invitedBy: ComAtprotoServerDefs.InviteCode?, invites: [ComAtprotoServerDefs.InviteCode]?, invitesDisabled: Bool?, emailConfirmedAt: ATProtocolDate?, inviteNote: String?, deactivatedAt: ATProtocolDate?
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
                handle = try container.decode(String.self, forKey: .handle)

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
                try container.encode(value, forKey: .relatedRecords)
            }

            try container.encode(indexedAt, forKey: .indexedAt)

            if let value = invitedBy {
                try container.encode(value, forKey: .invitedBy)
            }

            if let value = invites {
                try container.encode(value, forKey: .invites)
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

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        }
    }

    public struct RepoRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.admin.defs#repoRef"
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

    public struct RepoBlobRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.admin.defs#repoBlobRef"
        public let did: String
        public let cid: String
        public let recordUri: ATProtocolURI?

        // Standard initializer
        public init(
            did: String, cid: String, recordUri: ATProtocolURI?
        ) {
            self.did = did
            self.cid = cid
            self.recordUri = recordUri
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
                cid = try container.decode(String.self, forKey: .cid)

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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case cid
            case recordUri
        }
    }
}
