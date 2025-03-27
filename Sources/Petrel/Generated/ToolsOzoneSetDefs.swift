import Foundation

// lexicon: 1, id: tools.ozone.set.defs

public enum ToolsOzoneSetDefs {
    public static let typeIdentifier = "tools.ozone.set.defs"

    public struct Set: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.set.defs#set"
        public let name: String
        public let description: String?

        // Standard initializer
        public init(
            name: String, description: String?
        ) {
            self.name = name
            self.description = description
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for property 'name': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(name, forKey: .name)

            if let value = description {
                try container.encode(value, forKey: .description)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case description
        }
    }

    public struct SetView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.set.defs#setView"
        public let name: String
        public let description: String?
        public let setSize: Int
        public let createdAt: ATProtocolDate
        public let updatedAt: ATProtocolDate

        // Standard initializer
        public init(
            name: String, description: String?, setSize: Int, createdAt: ATProtocolDate, updatedAt: ATProtocolDate
        ) {
            self.name = name
            self.description = description
            self.setSize = setSize
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for property 'name': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                setSize = try container.decode(Int.self, forKey: .setSize)

            } catch {
                LogManager.logError("Decoding error for property 'setSize': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(name, forKey: .name)

            if let value = description {
                try container.encode(value, forKey: .description)
            }

            try container.encode(setSize, forKey: .setSize)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(updatedAt, forKey: .updatedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(setSize)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if name != other.name {
                return false
            }

            if description != other.description {
                return false
            }

            if setSize != other.setSize {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case description
            case setSize
            case createdAt
            case updatedAt
        }
    }
}
