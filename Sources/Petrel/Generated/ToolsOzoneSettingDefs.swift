import Foundation

// lexicon: 1, id: tools.ozone.setting.defs

public enum ToolsOzoneSettingDefs {
    public static let typeIdentifier = "tools.ozone.setting.defs"

    public struct Option: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.setting.defs#option"
        public let key: NSID
        public let did: DID
        public let value: ATProtocolValueContainer
        public let description: String?
        public let createdAt: ATProtocolDate?
        public let updatedAt: ATProtocolDate?
        public let managerRole: String?
        public let scope: String
        public let createdBy: DID
        public let lastUpdatedBy: DID

        // Standard initializer
        public init(
            key: NSID, did: DID, value: ATProtocolValueContainer, description: String?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?, managerRole: String?, scope: String, createdBy: DID, lastUpdatedBy: DID
        ) {
            self.key = key
            self.did = did
            self.value = value
            self.description = description
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.managerRole = managerRole
            self.scope = scope
            self.createdBy = createdBy
            self.lastUpdatedBy = lastUpdatedBy
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                key = try container.decode(NSID.self, forKey: .key)

            } catch {
                LogManager.logError("Decoding error for property 'key': \(error)")
                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
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
                managerRole = try container.decodeIfPresent(String.self, forKey: .managerRole)

            } catch {
                LogManager.logError("Decoding error for property 'managerRole': \(error)")
                throw error
            }
            do {
                scope = try container.decode(String.self, forKey: .scope)

            } catch {
                LogManager.logError("Decoding error for property 'scope': \(error)")
                throw error
            }
            do {
                createdBy = try container.decode(DID.self, forKey: .createdBy)

            } catch {
                LogManager.logError("Decoding error for property 'createdBy': \(error)")
                throw error
            }
            do {
                lastUpdatedBy = try container.decode(DID.self, forKey: .lastUpdatedBy)

            } catch {
                LogManager.logError("Decoding error for property 'lastUpdatedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(key, forKey: .key)

            try container.encode(did, forKey: .did)

            try container.encode(value, forKey: .value)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(managerRole, forKey: .managerRole)

            try container.encode(scope, forKey: .scope)

            try container.encode(createdBy, forKey: .createdBy)

            try container.encode(lastUpdatedBy, forKey: .lastUpdatedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(did)
            hasher.combine(value)
            if let value = description {
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
            if let value = managerRole {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(scope)
            hasher.combine(createdBy)
            hasher.combine(lastUpdatedBy)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if key != other.key {
                return false
            }

            if did != other.did {
                return false
            }

            if value != other.value {
                return false
            }

            if description != other.description {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if managerRole != other.managerRole {
                return false
            }

            if scope != other.scope {
                return false
            }

            if createdBy != other.createdBy {
                return false
            }

            if lastUpdatedBy != other.lastUpdatedBy {
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

            let keyValue = try (key as? DAGCBOREncodable)?.toCBORValue() ?? key
            map = map.adding(key: "key", value: keyValue)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            if let value = description {
                // Encode optional property even if it's an empty array for CBOR

                let descriptionValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "description", value: descriptionValue)
            }

            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR

                let createdAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "createdAt", value: createdAtValue)
            }

            if let value = updatedAt {
                // Encode optional property even if it's an empty array for CBOR

                let updatedAtValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }

            if let value = managerRole {
                // Encode optional property even if it's an empty array for CBOR

                let managerRoleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "managerRole", value: managerRoleValue)
            }

            let scopeValue = try (scope as? DAGCBOREncodable)?.toCBORValue() ?? scope
            map = map.adding(key: "scope", value: scopeValue)

            let createdByValue = try (createdBy as? DAGCBOREncodable)?.toCBORValue() ?? createdBy
            map = map.adding(key: "createdBy", value: createdByValue)

            let lastUpdatedByValue = try (lastUpdatedBy as? DAGCBOREncodable)?.toCBORValue() ?? lastUpdatedBy
            map = map.adding(key: "lastUpdatedBy", value: lastUpdatedByValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case key
            case did
            case value
            case description
            case createdAt
            case updatedAt
            case managerRole
            case scope
            case createdBy
            case lastUpdatedBy
        }
    }
}
