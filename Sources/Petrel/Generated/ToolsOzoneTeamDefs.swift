import Foundation

// lexicon: 1, id: tools.ozone.team.defs

public enum ToolsOzoneTeamDefs {
    public static let typeIdentifier = "tools.ozone.team.defs"

    public struct Member: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.team.defs#member"
        public let did: DID
        public let disabled: Bool?
        public let profile: AppBskyActorDefs.ProfileViewDetailed?
        public let createdAt: ATProtocolDate?
        public let updatedAt: ATProtocolDate?
        public let lastUpdatedBy: String?
        public let role: String

        // Standard initializer
        public init(
            did: DID, disabled: Bool?, profile: AppBskyActorDefs.ProfileViewDetailed?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?, lastUpdatedBy: String?, role: String
        ) {
            self.did = did
            self.disabled = disabled
            self.profile = profile
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastUpdatedBy = lastUpdatedBy
            self.role = role
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
                disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)

            } catch {
                LogManager.logError("Decoding error for property 'disabled': \(error)")
                throw error
            }
            do {
                profile = try container.decodeIfPresent(AppBskyActorDefs.ProfileViewDetailed.self, forKey: .profile)

            } catch {
                LogManager.logError("Decoding error for property 'profile': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
            do {
                lastUpdatedBy = try container.decodeIfPresent(String.self, forKey: .lastUpdatedBy)

            } catch {
                LogManager.logError("Decoding error for property 'lastUpdatedBy': \(error)")
                throw error
            }
            do {
                role = try container.decode(String.self, forKey: .role)

            } catch {
                LogManager.logError("Decoding error for property 'role': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            if let value = disabled {
                try container.encode(value, forKey: .disabled)
            }

            if let value = profile {
                try container.encode(value, forKey: .profile)
            }

            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }

            if let value = updatedAt {
                try container.encode(value, forKey: .updatedAt)
            }

            if let value = lastUpdatedBy {
                try container.encode(value, forKey: .lastUpdatedBy)
            }

            try container.encode(role, forKey: .role)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            if let value = disabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = profile {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastUpdatedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(role)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
                return false
            }

            if disabled != other.disabled {
                return false
            }

            if profile != other.profile {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if lastUpdatedBy != other.lastUpdatedBy {
                return false
            }

            if role != other.role {
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

            if let value = disabled {
                let disabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "disabled", value: disabledValue)
            }

            if let value = profile {
                let profileValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "profile", value: profileValue)
            }

            if let value = createdAt {
                let createdAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "createdAt", value: createdAtValue)
            }

            if let value = updatedAt {
                let updatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }

            if let value = lastUpdatedBy {
                let lastUpdatedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lastUpdatedBy", value: lastUpdatedByValue)
            }

            let roleValue = try (role as? DAGCBOREncodable)?.toCBORValue() ?? role
            map = map.adding(key: "role", value: roleValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case disabled
            case profile
            case createdAt
            case updatedAt
            case lastUpdatedBy
            case role
        }
    }
}
