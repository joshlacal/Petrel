import Foundation

// lexicon: 1, id: tools.ozone.setting.defs

public enum ToolsOzoneSettingDefs {
    public static let typeIdentifier = "tools.ozone.setting.defs"

    public struct Option: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.setting.defs#option"
        public let key: String
        public let did: String
        public let value: ATProtocolValueContainer
        public let description: String?
        public let createdAt: ATProtocolDate?
        public let updatedAt: ATProtocolDate?
        public let managerRole: String?
        public let scope: String
        public let createdBy: String
        public let lastUpdatedBy: String

        // Standard initializer
        public init(
            key: String, did: String, value: ATProtocolValueContainer, description: String?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?, managerRole: String?, scope: String, createdBy: String, lastUpdatedBy: String
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
                key = try container.decode(String.self, forKey: .key)

            } catch {
                LogManager.logError("Decoding error for property 'key': \(error)")
                throw error
            }
            do {
                did = try container.decode(String.self, forKey: .did)

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
                createdBy = try container.decode(String.self, forKey: .createdBy)

            } catch {
                LogManager.logError("Decoding error for property 'createdBy': \(error)")
                throw error
            }
            do {
                lastUpdatedBy = try container.decode(String.self, forKey: .lastUpdatedBy)

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

            if let value = description {
                try container.encode(value, forKey: .description)
            }

            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }

            if let value = updatedAt {
                try container.encode(value, forKey: .updatedAt)
            }

            if let value = managerRole {
                try container.encode(value, forKey: .managerRole)
            }

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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = key as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = did as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = description, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = createdAt, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = updatedAt, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = managerRole, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = scope as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = createdBy as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = lastUpdatedBy as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = key as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    key = updatedValue
                }
            }

            if let loadable = did as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    did = updatedValue
                }
            }

            if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ATProtocolValueContainer {
                    value = updatedValue
                }
            }

            if let value = description, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? String {
                    description = updatedValue
                }
            }

            if let value = createdAt, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? ATProtocolDate {
                    createdAt = updatedValue
                }
            }

            if let value = updatedAt, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? ATProtocolDate {
                    updatedAt = updatedValue
                }
            }

            if let value = managerRole, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? String {
                    managerRole = updatedValue
                }
            }

            if let loadable = scope as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    scope = updatedValue
                }
            }

            if let loadable = createdBy as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    createdBy = updatedValue
                }
            }

            if let loadable = lastUpdatedBy as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    lastUpdatedBy = updatedValue
                }
            }
        }
    }
}
